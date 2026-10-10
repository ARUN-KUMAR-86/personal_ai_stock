"""Portfolio and paper trading schemas."""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class PositionRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    quantity: int
    avg_entry_price: float
    current_price: float
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    unrealized_pnl: float
    realized_pnl: float
    fees: float
    is_open: bool
    opened_at: datetime
    closed_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class PaperTradeCreate(BaseModel):
    symbol: str
    exchange: str = "NSE"
    action: str  # BUY or SELL
    quantity: int
    price: Optional[float] = None  # None for current market price
    reason: Optional[str] = "Manual signal follow"


class PaperTradeRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    action: str
    quantity: int
    price: float
    fees: float
    total_amount: float
    pnl: float
    reason: Optional[str] = None
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)


class PortfolioSummary(BaseModel):
    total_portfolio_value: float
    total_invested_value: float
    total_unrealized_pnl: float
    total_realized_pnl: float
    open_positions_count: int
    portfolio_exposure_pct: float
    positions: List[PositionRead]
