"""Stock signal model representing strategy analysis outcomes."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, JSON
from app.database.base import Base


class StockSignal(Base):
    __tablename__ = "stock_signals"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    timestamp = Column(DateTime, nullable=False, index=True)
    signal_type = Column(String(30), nullable=False, index=True)  # BUY WATCH, HOLD, SELL/EXIT WATCH, NO TRADE
    strategy_name = Column(String(100), nullable=False, index=True)
    price = Column(Float, nullable=False)
    stop_loss = Column(Float, nullable=True)
    target = Column(Float, nullable=True)
    risk_reward = Column(Float, nullable=True)
    strength = Column(Float, nullable=False, default=50.0)  # 0 to 100 confidence
    entry_condition = Column(Text, nullable=True)
    invalidation_condition = Column(Text, nullable=True)
    indicator_summary = Column(JSON, nullable=True)  # JSON dict of indicators used
    explanation = Column(Text, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
