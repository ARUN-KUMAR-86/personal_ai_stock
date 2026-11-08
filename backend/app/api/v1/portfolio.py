import time
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.logging import logger
from app.database.session import get_db
from app.models.portfolio import Position, PaperTrade
from app.models.broker import BrokerAccount
from app.providers.factory import get_market_data_provider
from app.schemas.portfolio import (
    PositionRead,
    PaperTradeRead,
    PaperTradeCreate,
    PortfolioSummary,
    PaperTradeSyncRequest,
    UltraSyncResponse,
    UltraTradeResponse,
    ManualPurchaseRequest,
    ManualSaleRequest,
)
from app.portfolio.manager import PortfolioManager
from app.portfolio.monitor import PositionMonitor, DEFAULT_PROFIT_THRESHOLDS, DEFAULT_LOSS_THRESHOLDS

router = APIRouter(prefix="/portfolio", tags=["Portfolio & Position Monitoring"])


@router.get("/summary", response_model=PortfolioSummary)
def get_portfolio_summary(db: Session = Depends(get_db)):
    """Retrieves full portfolio summary with live mark-to-market calculations and priority rankings."""
    return PortfolioManager.get_portfolio_summary(db)


@router.get("/positions", response_model=List[PositionRead])
def get_open_positions(
    sort_by: Optional[str] = Query(None, description="priority, profit, loss, percent, symbol, date"),
    db: Session = Depends(get_db),
):
    """Retrieves all open portfolio positions, optionally sorted."""
    positions = db.query(Position).filter(Position.is_open == True).all()

    # Calculate live metrics if not present
    priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3, "P4": 4}
    if sort_by == "priority":
        positions.sort(key=lambda p: priority_order.get(p.priority or "P2", 9))
    elif sort_by == "profit":
        positions.sort(key=lambda p: p.unrealized_pnl or 0.0, reverse=True)
    elif sort_by == "loss":
        positions.sort(key=lambda p: p.unrealized_pnl or 0.0)
    elif sort_by == "percent":
        positions.sort(
            key=lambda p: (
                ((p.current_price - p.avg_entry_price) / p.avg_entry_price)
                if p.avg_entry_price > 0
                else 0.0
            ),
            reverse=True,
        )
    elif sort_by == "symbol":
        positions.sort(key=lambda p: p.symbol)
    elif sort_by == "date":
        positions.sort(
            key=lambda p: p.purchase_date or p.opened_at or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
    else:
        # Default sort: P0 first, then P1, P2, P3, P4
        positions.sort(key=lambda p: priority_order.get(p.priority or "P2", 9))

    return positions


@router.get("/positions/closed", response_model=List[PositionRead])
def get_closed_positions(limit: int = 50, db: Session = Depends(get_db)):
    """Retrieves closed positions with historical realized profit/loss."""
    return (
        db.query(Position)
        .filter(Position.is_open == False)
        .order_by(Position.closed_at.desc())
        .limit(limit)
        .all()
    )


@router.post("/manual-purchase")
def record_manual_purchase(
    request: ManualPurchaseRequest,
    db: Session = Depends(get_db),
):
    """
    I BOUGHT THIS STOCK — Workflow.
    Manually records a purchase executed through Groww:
    - Auto-calculates weighted average price on multiple purchases.
    - Adds to portfolio and activates continuous profit & loss monitoring.
    - Immediately refreshes live price and triggers threshold check.
    """
    try:
        res = PortfolioManager.record_manual_purchase(
            db=db,
            symbol=request.symbol,
            exchange=request.exchange,
            actual_price=request.actual_price,
            quantity=request.quantity,
            purchase_date=request.purchase_date,
            purchase_time=request.purchase_time,
            charges=request.charges,
            custom_target=request.custom_target,
            custom_stop_loss=request.custom_stop_loss,
            custom_thresholds=request.custom_thresholds,
            company_name=request.company_name,
        )

        # Run an immediate monitoring pass
        PositionMonitor.check_and_update_positions(db=db)
        return res
    except Exception as e:
        logger.error(f"Manual purchase recording failed: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/manual-sell")
def record_manual_sale(
    request: ManualSaleRequest,
    db: Session = Depends(get_db),
):
    """
    I SOLD THIS STOCK — Workflow.
    Manually records a sale executed through Groww:
    - Updates remaining position quantity and calculates realized profit/loss.
    - If fully sold, marks position CLOSED and ceases active monitoring.
    - Preserves complete transaction audit history.
    """
    try:
        res = PortfolioManager.record_manual_sale(
            db=db,
            symbol=request.symbol,
            exchange=request.exchange,
            selling_price=request.selling_price,
            quantity_sold=request.quantity_sold,
            selling_date=request.selling_date,
            selling_time=request.selling_time,
            charges=request.charges,
            notes=request.notes,
        )
        return res
    except Exception as e:
        logger.error(f"Manual sale recording failed: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/monitor-check")
def trigger_position_monitor_check(
    price_overrides: Optional[Dict[str, float]] = None,
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Manually triggers an immediate position monitor pass over all open positions."""
    return PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides=price_overrides,
    )


@router.get("/thresholds")
def get_threshold_configurations():
    """Returns standard institutional profit & loss notification threshold settings."""
    return {
        "profit_thresholds": DEFAULT_PROFIT_THRESHOLDS,
        "loss_thresholds": DEFAULT_LOSS_THRESHOLDS,
        "description": "Configurable rupee and percentage thresholds evaluated independently.",
    }


@router.post("/positions/{position_id}/thresholds")
def update_position_custom_thresholds(
    position_id: int,
    custom_thresholds: Dict[str, Any],
    db: Session = Depends(get_db),
):
    """Sets custom profit and loss notification thresholds for a specific position."""
    pos = db.query(Position).filter(Position.id == position_id).first()
    if not pos:
        raise HTTPException(status_code=404, detail="Position not found.")
    pos.custom_thresholds = custom_thresholds
    db.commit()
    return {"status": "SUCCESS", "position_id": position_id, "custom_thresholds": pos.custom_thresholds}


@router.get("/paper-trades", response_model=List[PaperTradeRead])
def get_paper_trades(limit: int = 50, db: Session = Depends(get_db)):
    """Retrieves transaction history of all purchases and sales."""
    return db.query(PaperTrade).order_by(PaperTrade.timestamp.desc()).limit(limit).all()


@router.post("/paper-trades", response_model=PaperTradeRead)
def execute_paper_trade(request: PaperTradeCreate, db: Session = Depends(get_db)):
    """Executes a simulated paper trade."""
    try:
        trade = PortfolioManager.execute_paper_trade(
            db=db,
            symbol=request.symbol,
            exchange=request.exchange,
            action=request.action,
            quantity=request.quantity,
            price=request.price,
            reason=request.reason,
            stop_loss=request.stop_loss,
            target=request.target,
            holding_period_hours=request.holding_period_hours,
            auto_sell_enabled=request.auto_sell_enabled,
        )
        return trade
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/sync-paper-trades")
def sync_paper_trades(request: PaperTradeSyncRequest, db: Session = Depends(get_db)):
    """Synchronizes locally created trades."""
    synced_count = 0
    for item in request.trades:
        existing = (
            db.query(PaperTrade)
            .filter(
                PaperTrade.symbol == item.symbol.upper(),
                PaperTrade.action == item.action.upper(),
                PaperTrade.quantity == item.quantity,
            )
            .first()
        )
        if not existing:
            PortfolioManager.execute_paper_trade(
                db=db,
                symbol=item.symbol,
                exchange=item.exchange,
                action=item.action,
                quantity=item.quantity,
                price=item.price,
                reason=item.reason or "Client Offline Sync",
                stop_loss=item.stop_loss,
                target=item.target,
                holding_period_hours=48,
                auto_sell_enabled=item.auto_sell_enabled,
            )
            synced_count += 1
    return {"status": "SUCCESS", "synced_count": synced_count}


@router.post("/auto-sell-check")
def trigger_auto_sell_check(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """Compatibility alias for monitor-check."""
    return PositionMonitor.check_and_update_positions(db=db, force_market_open=True)


@router.get("/ultra-sync", response_model=UltraSyncResponse)
def ultra_sync(run_auto_sell: bool = True, db: Session = Depends(get_db)):
    """Ultra-low-latency real-time synchronization endpoint."""
    start_time = time.perf_counter()
    if run_auto_sell:
        try:
            PositionMonitor.check_and_update_positions(db=db, force_market_open=True)
        except Exception as e:
            logger.warning(f"UltraSync monitor check error: {e}")

    summary = PortfolioManager.get_portfolio_summary(db)
    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    avail = account.available_funds if account else 1000.0
    bal = account.account_balance if account else 1000.0
    budget = account.trading_budget if account else 300.0
    withdrawable = account.withdrawable_funds if account else 1000.0
    is_active = account.is_trading_active if account else True
    t_mode = account.trading_mode if account else "Manual Groww Monitoring"
    algo = account.active_algorithm if account and account.active_algorithm else "Highest Gain Maximizer"
    auto_tp = getattr(account, "auto_take_profit", False) if account else False

    provider = get_market_data_provider()
    m_stat = provider.get_market_status(exchange="NSE")
    m_open = m_stat.get("is_open", False)

    recent_trades = db.query(PaperTrade).order_by(PaperTrade.timestamp.desc()).limit(15).all()
    elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "latency_benchmark_ms": elapsed_ms,
        "market_open": m_open,
        "portfolio": summary,
        "available_funds": avail,
        "account_balance": bal,
        "trading_budget": budget,
        "withdrawable_funds": withdrawable,
        "is_trading_active": is_active,
        "trading_mode": t_mode,
        "active_algorithm": algo,
        "auto_take_profit": auto_tp,
        "recent_trades": recent_trades,
    }


@router.post("/ultra-trade", response_model=UltraTradeResponse)
def ultra_trade(request: PaperTradeCreate, db: Session = Depends(get_db)):
    """Fast trade execution endpoint."""
    t0 = time.perf_counter()
    trade = PortfolioManager.execute_paper_trade(
        db=db,
        symbol=request.symbol,
        exchange=request.exchange,
        action=request.action,
        quantity=request.quantity,
        price=request.price,
        reason=request.reason,
        stop_loss=request.stop_loss,
        target=request.target,
        holding_period_hours=request.holding_period_hours,
        auto_sell_enabled=request.auto_sell_enabled,
    )
    summary = PortfolioManager.get_portfolio_summary(db)
    elapsed_ms = round((time.perf_counter() - t0) * 1000, 2)
    return {
        "status": "EXECUTED",
        "latency_ms": elapsed_ms,
        "trade": trade,
        "portfolio": summary,
    }
