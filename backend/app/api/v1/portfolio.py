import time
from datetime import datetime, timezone
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
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
)
from app.portfolio.manager import PortfolioManager
from app.portfolio.monitor import PositionMonitor

router = APIRouter(prefix="/portfolio", tags=["Portfolio & Paper Trading"])


@router.get("/summary", response_model=PortfolioSummary)
def get_portfolio_summary(db: Session = Depends(get_db)):
    """Retrieves full portfolio summary with live mark-to-market calculations."""
    return PortfolioManager.get_portfolio_summary(db)


@router.get("/positions", response_model=List[PositionRead])
def get_open_positions(db: Session = Depends(get_db)):
    """Retrieves all open portfolio positions."""
    return db.query(Position).filter(Position.is_open == True).all()


@router.get("/paper-trades", response_model=List[PaperTradeRead])
def get_paper_trades(limit: int = 50, db: Session = Depends(get_db)):
    """Retrieves history of simulated paper trades."""
    return db.query(PaperTrade).order_by(PaperTrade.timestamp.desc()).limit(limit).all()


@router.post("/paper-trades", response_model=PaperTradeRead)
def execute_paper_trade(request: PaperTradeCreate, db: Session = Depends(get_db)):
    """Executes a simulated paper trade with stop-loss and target parameters."""
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
    """Synchronizes locally created paper trades from client to server so trades are never lost."""
    synced_count = 0
    for item in request.trades:
        # Check if already present
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
            trade = PortfolioManager.execute_paper_trade(
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
    """Manually triggers an immediate position monitor pass to auto-sell positions reaching target or SL."""
    result = PositionMonitor.check_and_update_positions(db=db, force_market_open=True)
    return result


@router.get("/ultra-sync", response_model=UltraSyncResponse)
def ultra_sync(run_auto_sell: bool = True, db: Session = Depends(get_db)):
    """
    Ultra-low-latency real-time synchronization endpoint.
    Consolidates portfolio, live mark-to-market prices, open positions, funds,
    recent trades, and immediate auto-sell pass into a single sub-50ms roundtrip.
    """
    start_time = time.perf_counter()
    auto_sell_actions = []
    if run_auto_sell:
        try:
            res = PositionMonitor.check_and_update_positions(db=db, force_market_open=True)
            auto_sell_actions = res.get("actions_taken", [])
        except Exception as e:
            logger.warning(f"UltraSync auto-sell check error: {e}")

    summary = PortfolioManager.get_portfolio_summary(db)

    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    avail = account.available_funds if account else 1000.0
    bal = account.account_balance if account else 1000.0
    budget = account.trading_budget if account else 300.0
    withdrawable = account.withdrawable_funds if account else 1000.0
    is_active = account.is_trading_active if account else True
    t_mode = account.trading_mode if account else "Option B: Hybrid Guard (Auto Stop-Loss)"
    algo = account.active_algorithm if account and account.active_algorithm else "Breakout Momentum"
    auto_tp = getattr(account, "auto_take_profit", True) if account else True

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
        "auto_sell_actions": auto_sell_actions,
    }


@router.post("/ultra-trade", response_model=UltraTradeResponse)
def execute_ultra_trade(request: PaperTradeCreate, db: Session = Depends(get_db)):
    """
    Ultra-low-latency direct trade execution.
    Executes the trade, updates positions, verifies auto-sell triggers,
    and returns full updated state immediately.
    """
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
    # Immediately trigger position monitor check
    PositionMonitor.check_and_update_positions(db=db, force_market_open=True)
    summary = PortfolioManager.get_portfolio_summary(db)
    return {
        "trade": trade,
        "portfolio": summary,
        "status": "EXECUTED",
    }

