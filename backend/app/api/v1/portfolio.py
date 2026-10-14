"""Portfolio positions and paper trading endpoints."""

from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.portfolio import Position, PaperTrade
from app.schemas.portfolio import (
    PositionRead,
    PaperTradeRead,
    PaperTradeCreate,
    PortfolioSummary,
    PaperTradeSyncRequest,
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
