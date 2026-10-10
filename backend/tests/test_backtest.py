"""Unit tests for Backtesting Engine."""

from app.backtesting.engine import BacktestEngine
from app.schemas.backtest import BacktestRequest


def test_backtest_execution():
    request = BacktestRequest(
        symbols=["RELIANCE"],
        exchange="NSE",
        strategy_name="MomentumBreakout",
        timeframe="1d",
        start_date="2023-01-01",
        initial_capital=100000.0,
    )

    result = BacktestEngine.run(request)

    assert result.strategy_name == "MomentumBreakout"
    assert result.initial_capital == 100000.0
    assert result.final_capital > 0
    assert result.win_rate_pct >= 0.0 and result.win_rate_pct <= 100.0
    assert result.max_drawdown_pct >= 0.0
    assert isinstance(result.trades, list)
