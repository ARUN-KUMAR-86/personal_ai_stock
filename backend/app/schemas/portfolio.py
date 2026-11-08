"""Portfolio and paper trading schemas."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict


class PositionRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    company_name: Optional[str] = None
    quantity: int
    avg_entry_price: float
    current_price: float
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    unrealized_pnl: float
    realized_pnl: float
    fees: float
    charges: Optional[float] = 0.0
    is_open: bool
    status: Optional[str] = "ACTIVE"
    priority: Optional[str] = "P2"
    holding_period_hours: int = 48
    exit_deadline: Optional[datetime] = None
    auto_sell_enabled: bool = False
    exit_strategy: str = "MANUAL_GROWW_MONITOR"
    exit_triggered: bool = False
    exit_reason: Optional[str] = None
    mode: str = "GROWW_MANUAL"
    order_id: Optional[str] = None
    purchase_date: Optional[datetime] = None
    opened_at: datetime
    closed_at: Optional[datetime] = None
    triggered_thresholds: Optional[List[str]] = None
    custom_thresholds: Optional[Dict[str, Any]] = None

    model_config = ConfigDict(from_attributes=True)


class ManualPurchaseRequest(BaseModel):
    symbol: str
    exchange: str = "NSE"
    actual_price: float
    quantity: int
    purchase_date: Optional[str] = None
    purchase_time: Optional[str] = None
    charges: float = 0.0
    custom_target: Optional[float] = None
    custom_stop_loss: Optional[float] = None
    custom_thresholds: Optional[Dict[str, Any]] = None
    company_name: Optional[str] = None


class ManualSaleRequest(BaseModel):
    symbol: str
    exchange: str = "NSE"
    selling_price: float
    quantity_sold: int
    selling_date: Optional[str] = None
    selling_time: Optional[str] = None
    charges: float = 0.0
    notes: Optional[str] = None


class PaperTradeCreate(BaseModel):
    symbol: str
    exchange: str = "NSE"
    action: str  # BUY or SELL
    quantity: int
    price: Optional[float] = None  # None for current market price
    reason: Optional[str] = "Manual signal follow"
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    holding_period_hours: int = 48
    auto_sell_enabled: bool = True


class PaperTradeRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    action: str
    quantity: int
    price: float
    fees: float
    total_amount: float
    pnl: float
    reason: Optional[str] = None
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)


class PortfolioSummary(BaseModel):
    total_portfolio_value: float
    total_invested_value: float
    total_unrealized_pnl: float
    total_realized_pnl: float
    open_positions_count: int
    portfolio_exposure_pct: Optional[float] = 0.0
    closed_positions_count: Optional[int] = 0
    positions: List[PositionRead] = []
    active_holdings: Optional[List[Dict[str, Any]]] = None
    closed_holdings: Optional[List[Dict[str, Any]]] = None


class PaperTradeSyncItem(BaseModel):
    symbol: str
    exchange: str = "NSE"
    action: str
    quantity: int
    price: float
    fees: float = 0.0
    total_amount: float
    pnl: float = 0.0
    reason: Optional[str] = None
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    auto_sell_enabled: bool = True
    timestamp: Optional[datetime] = None


class PaperTradeSyncRequest(BaseModel):
    trades: List[PaperTradeSyncItem]


class UltraSyncResponse(BaseModel):
    timestamp: str
    latency_benchmark_ms: float
    market_open: bool
    portfolio: PortfolioSummary
    available_funds: float
    account_balance: float
    trading_budget: float
    withdrawable_funds: float
    is_trading_active: bool
    trading_mode: str
    active_algorithm: str
    auto_take_profit: bool
    recent_trades: List[PaperTradeRead]
    auto_sell_actions: List[Dict[str, Any]] = []


class UltraTradeResponse(BaseModel):
    trade: PaperTradeRead
    portfolio: PortfolioSummary
    status: str
