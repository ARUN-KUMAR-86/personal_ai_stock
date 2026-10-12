"""Order and trade execution schemas."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field


class OrderCalculateRequest(BaseModel):
    symbol: str
    exchange: str = "NSE"
    investment_amount: float = Field(..., gt=0, description="Intended investment amount in INR")
    entry_price: Optional[float] = None
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    holding_period_hours: int = 48


class OrderCalculateResponse(BaseModel):
    is_valid: bool
    shares_quantity: int
    verified_entry_price: float
    estimated_investment: float
    total_outlay: float
    buy_charges: Dict[str, float]
    target_sell_charges: Dict[str, float]
    sl_sell_charges: Dict[str, float]
    roundtrip_target_charges: float
    roundtrip_sl_charges: float
    potential_profit_net: float
    potential_profit_pct: float
    potential_loss_net: float
    potential_loss_pct: float
    risk_reward_ratio: float
    remaining_available_funds: float
    holding_period_hours: int
    warnings: List[str]


class PrepareBuyRequest(BaseModel):
    symbol: str
    exchange: str = "NSE"
    investment_amount: float
    signal_id: Optional[int] = None
    expected_price: float
    stop_loss: float
    target: float
    holding_period_hours: int = 48


class PrepareBuyResponse(BaseModel):
    symbol: str
    exchange: str
    company_name: str
    verified_current_price: float
    price_changed: bool
    slippage_pct: float
    slippage_warning: Optional[str] = None
    shares_quantity: int
    estimated_investment: float
    total_charges: float
    total_outlay: float
    available_funds: float
    stop_loss: float
    target: float
    holding_period_hours: int
    risk_reward_ratio: float
    client_order_id: str
    mode: str  # PAPER or GROWW_LIVE


class BuyConfirmRequest(BaseModel):
    client_order_id: str
    symbol: str
    exchange: str = "NSE"
    signal_id: Optional[int] = None
    investment_amount: float
    confirmed_price: float
    quantity: int
    stop_loss: float
    target: float
    holding_period_hours: int = 48
    auto_sell_enabled: bool = False
    user_confirmed: bool = Field(True, description="Explicit user confirmation is mandatory")


class OrderRead(BaseModel):
    id: int
    order_id: str
    client_order_id: str
    symbol: str
    exchange: str
    transaction_type: str
    order_type: str
    status: str
    requested_quantity: int
    filled_quantity: int
    requested_price: float
    executed_price: Optional[float] = None
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    holding_period_hours: int
    total_charges: float
    mode: str
    user_confirmed: bool
    auto_sell_enabled: bool
    broker_order_id: Optional[str] = None
    error_message: Optional[str] = None
    user_confirmed_at: datetime
    executed_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class SafetyStatusResponse(BaseModel):
    emergency_stop_enabled: bool
    auto_sell_enabled: bool
    max_position_risk_pct: float
    max_single_stock_pct: float
    max_portfolio_exposure_pct: float
    execution_mode: str
    auto_buying_allowed: bool = False  # Always False


class UpdateSafetySettingsRequest(BaseModel):
    emergency_stop_enabled: Optional[bool] = None
    auto_sell_enabled: Optional[bool] = None
    max_position_risk_pct: Optional[float] = None
    max_single_stock_pct: Optional[float] = None
    max_portfolio_exposure_pct: Optional[float] = None


class PositionMonitoringUpdateRequest(BaseModel):
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    holding_period_hours: Optional[int] = None
    auto_sell_enabled: Optional[bool] = None
