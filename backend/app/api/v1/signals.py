"""Stock signal and analysis endpoints."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.signal import StockSignal
from app.schemas.signal import SignalRead

router = APIRouter(prefix="/signals", tags=["Signals & Analysis"])


@router.get("/latest", response_model=List[SignalRead])
def get_latest_signals(
    signal_type: Optional[str] = None,
    exchange: str = "NSE",
    limit: int = 20,
    db: Session = Depends(get_db),
):
    """Retrieves the latest generated signals."""
    query = db.query(StockSignal).filter(StockSignal.exchange == exchange)
    if signal_type:
        query = query.filter(StockSignal.signal_type == signal_type)
    return query.order_by(StockSignal.created_at.desc()).limit(limit).all()


@router.get("/{symbol}", response_model=List[SignalRead])
def get_signals_for_symbol(
    symbol: str,
    exchange: str = "NSE",
    limit: int = 10,
    db: Session = Depends(get_db),
):
    """Retrieves historical signals and analysis rationale for a given symbol."""
    signals = (
        db.query(StockSignal)
        .filter(StockSignal.symbol == symbol.upper(), StockSignal.exchange == exchange.upper())
        .order_by(StockSignal.created_at.desc())
        .limit(limit)
        .all()
    )
    if not signals:
        raise HTTPException(status_code=404, detail=f"No signals found for {symbol}")
    return signals
