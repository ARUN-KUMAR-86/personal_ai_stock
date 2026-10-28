"""Stock prediction model storing quantitative algorithm and Gemini AI forecast outcomes."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, JSON
from app.database.base import Base


class StockPrediction(Base):
    __tablename__ = "stock_predictions"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    company_name = Column(String(100), nullable=True)
    price_at_prediction = Column(Float, nullable=False)
    predicted_direction = Column(String(20), nullable=False, default="BULLISH", index=True)
    predicted_action = Column(String(30), nullable=False, default="BUY")
    target_price = Column(Float, nullable=False)
    expected_gain_pct = Column(Float, nullable=False)
    stop_loss = Column(Float, nullable=True)
    confidence_score = Column(Float, nullable=False, default=75.0)
    time_horizon = Column(String(50), nullable=False, default="1-DAY (Swing)")
    algorithm_name = Column(String(100), nullable=False, default="Gemini Predictive AI Confluence")
    working_algorithm = Column(Text, nullable=True)
    algorithm_metrics = Column(JSON, nullable=True)
    ai_prediction_summary = Column(Text, nullable=True)
    key_catalysts = Column(JSON, nullable=True)
    risk_assessment = Column(JSON, nullable=True)
    invalidation_trigger = Column(Text, nullable=True)
    model_used = Column(String(50), nullable=True, default="Gemini 3.5 Flash")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
