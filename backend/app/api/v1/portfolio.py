"""Portfolio positions and paper trading endpoints."""

from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.portfolio import Position, PaperTrade
from app.schemas.portfolio import (
    PositionRead,
    PaperTradeRead,
    PaperTradeCreate,
    PortfolioSummary,
)
from app.portfolio.manager import PortfolioManager

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
        )
        return trade
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
