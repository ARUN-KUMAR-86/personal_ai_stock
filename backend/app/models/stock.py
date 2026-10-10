"""Stock universe and instrument model."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime
from app.database.base import Base


class Stock(Base):
    __tablename__ = "stocks"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    name = Column(String(150), nullable=False)
    sector = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    min_qty = Column(Integer, default=1)
    tick_size = Column(Float, default=0.05)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
