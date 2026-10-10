"""Broker account synchronization state model."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text
from app.database.base import Base


class BrokerAccount(Base):
    __tablename__ = "broker_accounts"

    id = Column(Integer, primary_key=True, index=True)
    broker_name = Column(String(50), nullable=False, default="GROWW", index=True)
    is_connected = Column(Boolean, default=False)
    available_funds = Column(Float, default=0.0)
    unsettled_funds = Column(Float, default=0.0)
    withdrawable_funds = Column(Float, default=0.0)
    currency = Column(String(10), default="INR")
    last_synced_at = Column(DateTime, nullable=True)
    error_message = Column(Text, nullable=True)
