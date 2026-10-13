"""Trading Control schemas for dedicated trading control screen and operations."""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class TradingControlSummary(BaseModel):
    groww_account_status: str  # "Connected*", "Expired (Re-authenticate)*", "Disconnected"
    groww_account_id: Optional[str] = "GROWW-ARUN-PRIMARY"
    groww_account_name: Optional[str] = "Arun Kumar"
    account_balance: float = 1000.0
    available_funds: float = 1000.0
    trading_budget: float = 300.0
    amount_in_positions: float = 0.0
    todays_pnl: float = 0.0
    todays_realized_pnl: float = 0.0
    todays_unrealized_pnl: float = 0.0
    is_trading_active: bool = True
    trading_mode: str = "Notification + Approval"
    max_amount_per_trade: float = 100.0
    daily_loss_limit: float = 50.0
    auto_withdraw_profits: bool = False
    auto_withdraw_threshold: float = 100.0
    token_expiry: Optional[datetime] = None
    last_verified_at: Optional[datetime] = None
    is_broker_verified: bool = True

    model_config = ConfigDict(from_attributes=True)


class TradingControlSettingsUpdate(BaseModel):
    trading_budget: Optional[float] = None
    max_amount_per_trade: Optional[float] = None
    daily_loss_limit: Optional[float] = None
    auto_withdraw_profits: Optional[bool] = None
    auto_withdraw_threshold: Optional[float] = None
    is_trading_active: Optional[bool] = None
    trading_mode: Optional[str] = None


class FundTransactionCreate(BaseModel):
    transaction_type: str  # DEPOSIT, WITHDRAWAL
    amount: float
    note: Optional[str] = None


class FundTransactionRead(BaseModel):
    id: int
    transaction_type: str
    amount: float
    status: str
    note: Optional[str] = None
    broker_ref_id: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TradeAlertRespondRequest(BaseModel):
    action: str  # "APPROVE" or "REJECT"
    confirmed_price: Optional[float] = None
