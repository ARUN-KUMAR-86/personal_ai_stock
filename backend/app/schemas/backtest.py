"""Backtesting schemas."""

from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel


class BacktestRequest(BaseModel):
    symbols: List[str]
    exchange: str = "NSE"
    strategy_name: str = "MomentumBreakout"
    timeframe: str = "1d"
    start_date: str = "2023-01-01"
    end_date: Optional[str] = None
    initial_capital: float = 100000.0  # 1 Lakh INR
    slippage_pct: float = 0.05  # 0.05%
    brokerage_per_order: float = 20.0  # ₹20 flat or 0.03%
    benchmark_symbol: Optional[str] = "^NSEI"  # NIFTY 50


class BacktestTradeLog(BaseModel):
    symbol: str
    entry_date: datetime
    exit_date: datetime
    entry_price: float
    exit_price: float
    quantity: int
    pnl: float
    pnl_pct: float
    fees: float
    entry_reason: str
    exit_reason: str


class BacktestResult(BaseModel):
    strategy_name: str
    symbols: List[str]
    timeframe: str
    start_date: str
    end_date: str
    initial_capital: float
    final_capital: float
    total_net_pnl: float
    total_return_pct: float
    benchmark_return_pct: Optional[float] = None
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate_pct: float
    profit_factor: float
    max_drawdown_pct: float
    sharpe_ratio: float
    trades: List[BacktestTradeLog]
