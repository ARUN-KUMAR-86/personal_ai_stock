"""Broker account synchronization state model."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text
from app.database.base import Base


class BrokerAccount(Base):
    __tablename__ = "broker_accounts"

    id = Column(Integer, primary_key=True, index=True)
    broker_name = Column(String(50), nullable=False, default="GROWW", index=True)
    account_id = Column(String(100), nullable=True, default="GROWW-ARUN-PRIMARY", index=True)
    account_holder_name = Column(String(100), nullable=True, default="Arun Kumar")
    is_connected = Column(Boolean, default=False)
    auth_status = Column(String(30), default="CONNECTED")  # CONNECTED, EXPIRED, DISCONNECTED, UNCONFIGURED
    token_expiry = Column(DateTime, nullable=True)
    account_balance = Column(Float, default=1000.0)
    available_funds = Column(Float, default=1000.0)
    unsettled_funds = Column(Float, default=0.0)
    withdrawable_funds = Column(Float, default=1000.0)
    currency = Column(String(10), default="INR")
    
    # Dedicated Trading Control Settings
    trading_budget = Column(Float, default=300.0)
    max_amount_per_trade = Column(Float, default=100.0)
    daily_loss_limit = Column(Float, default=50.0)
    auto_withdraw_profits = Column(Boolean, default=False)
    auto_withdraw_threshold = Column(Float, default=100.0)
    is_trading_active = Column(Boolean, default=True)
    trading_mode = Column(String(50), default="Notification + Approval")
    
    last_synced_at = Column(DateTime, nullable=True)
    error_message = Column(Text, nullable=True)


class FundTransaction(Base):
    """Tracks deposits, withdrawals, and auto-withdraw payouts."""
    __tablename__ = "fund_transactions"

    id = Column(Integer, primary_key=True, index=True)
    transaction_type = Column(String(20), nullable=False, index=True)  # DEPOSIT, WITHDRAWAL, AUTO_WITHDRAW
    amount = Column(Float, nullable=False)
    status = Column(String(20), default="CONFIRMED", index=True)  # CONFIRMED, PENDING, REJECTED
    note = Column(String(255), nullable=True)
    broker_ref_id = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
