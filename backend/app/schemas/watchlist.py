"""Watchlist schemas."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.schemas.stock import StockSummary


class WatchlistItemCreate(BaseModel):
    symbol: str
    exchange: Optional[str] = "NSE"
    notes: Optional[str] = None


class WatchlistItemRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    notes: Optional[str] = None
    created_at: datetime
    stock: Optional[StockSummary] = None

    model_config = ConfigDict(from_attributes=True)
