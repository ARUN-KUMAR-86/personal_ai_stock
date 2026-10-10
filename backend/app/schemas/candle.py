"""Candle schemas."""

from datetime import datetime
from pydantic import BaseModel, ConfigDict


class CandleRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    timeframe: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float
    is_live: bool
    is_delayed: bool
    data_source: str

    model_config = ConfigDict(from_attributes=True)


class QuoteRead(BaseModel):
    symbol: str
    exchange: str
    price: float
    change: float
    percent_change: float
    open: float
    high: float
    low: float
    previous_close: float
    volume: float
    timestamp: datetime
    is_live: bool
    is_delayed: bool
    data_source: str
