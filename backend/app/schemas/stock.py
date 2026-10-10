"""Stock schemas."""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class StockBase(BaseModel):
    symbol: str
    exchange: str = "NSE"
    name: str
    sector: Optional[str] = None
    is_active: bool = True
    min_qty: int = 1
    tick_size: float = 0.05


class StockCreate(StockBase):
    pass


class StockRead(StockBase):
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class StockSummary(BaseModel):
    symbol: str
    exchange: str
    name: str
    sector: Optional[str]
    latest_price: Optional[float] = None
    latest_timestamp: Optional[datetime] = None
    is_live: bool = False
    latest_signal: Optional[str] = None
    signal_strength: Optional[float] = None
