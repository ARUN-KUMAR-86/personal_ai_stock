"""Portfolio positions and paper trading models."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text
from app.database.base import Base


class Position(Base):
    __tablename__ = "portfolio_positions"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    quantity = Column(Integer, nullable=False, default=0)
    avg_entry_price = Column(Float, nullable=False)
    current_price = Column(Float, nullable=False)
    stop_loss = Column(Float, nullable=True)
    target = Column(Float, nullable=True)
    unrealized_pnl = Column(Float, default=0.0)
    realized_pnl = Column(Float, default=0.0)
    fees = Column(Float, default=0.0)
    is_open = Column(Boolean, default=True, index=True)
    holding_period_hours = Column(Integer, default=48)
    exit_deadline = Column(DateTime, nullable=True)
    auto_sell_enabled = Column(Boolean, default=False)
    exit_strategy = Column(String(50), default="TARGET_OR_STOPLOSS_OR_EXPIRY")
    exit_triggered = Column(Boolean, default=False)
    exit_reason = Column(String(100), nullable=True)
    monitored_at = Column(DateTime, nullable=True)
    mode = Column(String(20), default="PAPER")
    order_id = Column(String(64), nullable=True)
    opened_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    closed_at = Column(DateTime, nullable=True)


class PaperTrade(Base):
    __tablename__ = "paper_trades"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    action = Column(String(10), nullable=False)  # BUY, SELL
    quantity = Column(Integer, nullable=False)
    price = Column(Float, nullable=False)
    fees = Column(Float, default=0.0)
    total_amount = Column(Float, nullable=False)
    pnl = Column(Float, default=0.0)
    reason = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
