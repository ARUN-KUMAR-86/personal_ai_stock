"""Portfolio and paper trading schemas."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict


class PositionRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    quantity: int
    avg_entry_price: float
    current_price: float
    stop_loss: Optional[float] = None
    target: Optional[float] = None
    unrealized_pnl: float
    realized_pnl: float
    fees: float
    is_open: bool
    holding_period_hours: int = 48
    exit_deadline: Optional[datetime] = None
    auto_sell_enabled: bool = False
    exit_strategy: str = "TARGET_OR_STOPLOSS_OR_EXPIRY"
    exit_triggered: bool = False
    exit_reason: Optional[str] = None
    mode: str = "PAPER"
    order_id: Optional[str] = None
    opened_at: datetime
    closed_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


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
    portfolio_exposure_pct: float
    positions: List[PositionRead]


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
