"""Alert history and notification log model."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean, ForeignKey
from app.database.base import Base


class AlertHistory(Base):
    __tablename__ = "alert_history"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    exchange = Column(String(20), nullable=False, default="NSE", index=True)
    alert_type = Column(String(50), nullable=False, index=True)
    # Types: BUY_ENTRY, HOLD_VALID, EXIT_MET, STOP_LOSS, TARGET_REACHED, RISK_EXCEEDED, SCAN_COMPLETED, FUNDS_LOW, PROVIDER_FAILURE
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)
    signal_id = Column(Integer, ForeignKey("stock_signals.id"), nullable=True)
    price = Column(Float, nullable=True)
    is_read = Column(Boolean, default=False, index=True)
    sent_to_fcm = Column(Boolean, default=False)
    fcm_message_id = Column(String(150), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String(255), unique=True, nullable=False, index=True)
    device_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
