"""Stock prediction schemas."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict


class PredictionRequest(BaseModel):
    symbol: str
    exchange: str = "NSE"
    time_horizon: str = "1-DAY"  # "1-DAY" or "1-MONTH"
    force_refresh: bool = False


class PredictionRead(BaseModel):
    id: Optional[int] = None
    symbol: str
    exchange: str = "NSE"
    company_name: Optional[str] = None
    price_at_prediction: float
    predicted_direction: str  # BULLISH, BEARISH, NEUTRAL
    predicted_action: str     # STRONG BUY, BUY, HOLD, SELL
    target_price: float
    expected_gain_pct: float
    stop_loss: Optional[float] = None
    confidence_score: float
    time_horizon: str
    algorithm_name: str
    working_algorithm: Optional[str] = None
    algorithm_metrics: Optional[Dict[str, Any]] = None
    ai_prediction_summary: Optional[str] = None
    key_catalysts: Optional[List[str]] = None
    risk_assessment: Optional[List[str]] = None
    invalidation_trigger: Optional[str] = None
    model_used: Optional[str] = "Gemini 3.5 Flash"
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
