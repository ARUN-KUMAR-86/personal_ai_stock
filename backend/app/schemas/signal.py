"""Signal schemas."""

from datetime import datetime
from typing import Optional, Dict, Any, List
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
    company_name: Optional[str] = None
    entry_range_low: Optional[float] = None
    entry_range_high: Optional[float] = None
    holding_period_hours: Optional[int] = 48
    data_source: Optional[str] = "Verified Market Data"
    data_freshness: Optional[str] = "Live"
    entry_condition: Optional[str] = None
    invalidation_condition: Optional[str] = None
    indicator_summary: Optional[Dict[str, Any]] = None
    liquidity_summary: Optional[str] = None
    financial_news: Optional[List[Dict[str, Any]]] = None
    risk_factors: Optional[List[str]] = None
    score_breakdown: Optional[Dict[str, Any]] = None
    explanation: str
    ai_thesis: Optional[Dict[str, Any]] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
