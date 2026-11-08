"""Stock schemas."""

from datetime import datetime
from typing import Optional, List, Dict, Any
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
    sector: Optional[str] = None
    latest_price: Optional[float] = None
    latest_timestamp: Optional[datetime] = None
    is_live: bool = False
    latest_signal: Optional[str] = None
    signal_strength: Optional[float] = None
    change: Optional[float] = 0.0
    percent_change: Optional[float] = 0.0
    day_high: Optional[float] = None
    day_low: Optional[float] = None
    volume: Optional[float] = None
    predicted_direction: Optional[str] = None
    predicted_target: Optional[float] = None
    predicted_confidence: Optional[float] = None
    priority: Optional[str] = "P2"
    entry_zone: Optional[str] = None
    stop_loss: Optional[float] = None
    target_price: Optional[float] = None
    risk_reward: Optional[float] = None
    supporting_indicators: Optional[Dict[str, Any]] = None
    main_reasons: Optional[str] = None
    data_freshness: Optional[str] = "Verified Tick"
    data_available: bool = True
