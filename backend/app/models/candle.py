"""Historical and live OHLCV candlestick data model."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Index
from app.database.base import Base


class Candle(Base):
    __tablename__ = "candles"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    timeframe = Column(String(10), nullable=False, default="1d", index=True)  # "1m", "5m", "15m", "1d"
    timestamp = Column(DateTime, nullable=False, index=True)
    open = Column(Float, nullable=False)
    high = Column(Float, nullable=False)
    low = Column(Float, nullable=False)
    close = Column(Float, nullable=False)
    volume = Column(Float, nullable=False)
    is_live = Column(Boolean, default=False)
    is_delayed = Column(Boolean, default=False)
    data_source = Column(String(50), nullable=False)  # "yahoo", "groww", "TEST_SIMULATED"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        Index("idx_candle_symbol_tf_ts", "symbol", "exchange", "timeframe", "timestamp", unique=True),
    )
