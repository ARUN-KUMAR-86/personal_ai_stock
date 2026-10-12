"""Auditable Order model tracking confirmations, submissions, executions, and exits."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text, JSON
from app.database.base import Base


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(String(64), unique=True, nullable=False, index=True)
    client_order_id = Column(String(64), unique=True, nullable=False, index=True)
    signal_id = Column(Integer, nullable=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    transaction_type = Column(String(10), nullable=False)  # BUY or SELL
    order_type = Column(String(20), nullable=False, default="MARKET")
    status = Column(String(30), nullable=False, default="CONFIRMED")  # CONFIRMED, SUBMITTED, FILLED, PARTIALLY_FILLED, REJECTED, CANCELLED
    requested_quantity = Column(Integer, nullable=False)
    filled_quantity = Column(Integer, nullable=False, default=0)
    requested_price = Column(Float, nullable=False)
    executed_price = Column(Float, nullable=True)
    stop_loss = Column(Float, nullable=True)
    target = Column(Float, nullable=True)
    holding_period_hours = Column(Integer, nullable=False, default=48)
    brokerage = Column(Float, default=0.0)
    stt = Column(Float, default=0.0)
    exchange_charges = Column(Float, default=0.0)
    gst = Column(Float, default=0.0)
    stamp_duty = Column(Float, default=0.0)
    total_charges = Column(Float, default=0.0)
    mode = Column(String(20), nullable=False, default="PAPER")  # PAPER or GROWW_LIVE
    user_confirmed = Column(Boolean, nullable=False, default=True)
    auto_sell_enabled = Column(Boolean, nullable=False, default=False)
    broker_order_id = Column(String(100), nullable=True)
    error_message = Column(Text, nullable=True)
    audit_trail = Column(JSON, nullable=True)
    user_confirmed_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    executed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
