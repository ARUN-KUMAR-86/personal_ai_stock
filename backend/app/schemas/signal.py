"""Signal schemas."""

from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict


class SignalRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    timestamp: datetime
    signal_type: str
    strategy_name: str
    price: float
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    risk_reward: Optional[float] = None
    strength: float
    entry_condition: Optional[str] = None
    invalidation_condition: Optional[str] = None
    indicator_summary: Optional[Dict[str, Any]] = None
    explanation: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
