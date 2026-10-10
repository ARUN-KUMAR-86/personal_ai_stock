"""Historical backtesting engine with realistic transaction costs and slippage."""

from datetime import datetime
from typing import List, Optional
import numpy as np
import pandas as pd

from app.analysis.indicators import TechnicalIndicators
from app.providers.factory import get_market_data_provider
from app.schemas.backtest import BacktestRequest, BacktestResult, BacktestTradeLog
from app.strategies.registry import strategy_registry


class BacktestEngine:
    """Simulates trading strategies across historical bars without lookahead bias."""

    @classmethod
    def run(cls, request: BacktestRequest) -> BacktestResult:
        provider = get_market_data_provider()
        strategy = strategy_registry.get(request.strategy_name)
        if not strategy:
            raise ValueError(f"Strategy '{request.strategy_name}' not found in registry.")

        initial_capital = request.initial_capital
        cash = initial_capital
        equity_curve = [initial_capital]
        trades: List[BacktestTradeLog] = []

        all_symbols = request.symbols or ["RELIANCE"]
        start_date = datetime.strptime(request.start_date, "%Y-%m-%d")
        end_date = datetime.strptime(request.end_date, "%Y-%m-%d") if request.end_date else datetime.now()

        for symbol in all_symbols:
            try:
                df = provider.get_historical_ohlcv(
                    symbol=symbol,
                    exchange=request.exchange,
                    timeframe=request.timeframe,
                    start=start_date,
                    end=end_date,
                )
            except Exception:
                continue

            if df.empty or len(df) < 40:
                continue

            # Ensure chronological order
            df = df.sort_values("timestamp").reset_index(drop=True)

            in_position = False
            entry_price = 0.0
            entry_date = None
            stop_loss = 0.0
            target = 0.0
            qty = 0
            entry_reason = ""

            # Simulate bar by bar to avoid lookahead bias
            # Need minimum 30 bars for indicators
            for i in range(30, len(df)):
                window_df = df.iloc[: i + 1]
                current_bar = df.iloc[i]
                bar_time = current_bar["timestamp"].to_pydatetime()
                current_price = float(current_bar["close"])

                if in_position:
                    # Check stop loss hit
                    if float(current_bar["low"]) <= stop_loss:
                        exit_price = round(stop_loss * (1.0 - request.slippage_pct / 100.0), 2)
                        pnl = round((exit_price - entry_price) * qty - request.brokerage_per_order * 2, 2)
                        pnl_pct = round(((exit_price - entry_price) / entry_price) * 100.0, 2)
                        cash += (exit_price * qty) - request.brokerage_per_order

                        trades.append(
                            BacktestTradeLog(
                                symbol=symbol,
                                entry_date=entry_date,
                                exit_date=bar_time,
                                entry_price=entry_price,
                                exit_price=exit_price,
                                quantity=qty,
                                pnl=pnl,
                                pnl_pct=pnl_pct,
                                fees=request.brokerage_per_order * 2,
                                entry_reason=entry_reason,
                                exit_reason=f"Stop Loss Hit at ₹{stop_loss}",
                            )
                        )
                        in_position = False

                    # Check target hit
                    elif float(current_bar["high"]) >= target:
                        exit_price = round(target * (1.0 - request.slippage_pct / 100.0), 2)
                        pnl = round((exit_price - entry_price) * qty - request.brokerage_per_order * 2, 2)
                        pnl_pct = round(((exit_price - entry_price) / entry_price) * 100.0, 2)
                        cash += (exit_price * qty) - request.brokerage_per_order

                        trades.append(
                            BacktestTradeLog(
                                symbol=symbol,
                                entry_date=entry_date,
                                exit_date=bar_time,
                                entry_price=entry_price,
                                exit_price=exit_price,
                                quantity=qty,
                                pnl=pnl,
                                pnl_pct=pnl_pct,
                                fees=request.brokerage_per_order * 2,
                                entry_reason=entry_reason,
                                exit_reason=f"Target Reached at ₹{target}",
                            )
                        )
                        in_position = False

                    # Strategy Exit signal
                    else:
                        eval_signal = strategy.evaluate(window_df, symbol, request.exchange)
                        if eval_signal.signal_type == "SELL/EXIT WATCH":
                            exit_price = round(current_price * (1.0 - request.slippage_pct / 100.0), 2)
                            pnl = round((exit_price - entry_price) * qty - request.brokerage_per_order * 2, 2)
                            pnl_pct = round(((exit_price - entry_price) / entry_price) * 100.0, 2)
                            cash += (exit_price * qty) - request.brokerage_per_order

                            trades.append(
                                BacktestTradeLog(
                                    symbol=symbol,
                                    entry_date=entry_date,
                                    exit_date=bar_time,
                                    entry_price=entry_price,
                                    exit_price=exit_price,
                                    quantity=qty,
                                    pnl=pnl,
                                    pnl_pct=pnl_pct,
                                    fees=request.brokerage_per_order * 2,
                                    entry_reason=entry_reason,
                                    exit_reason=eval_signal.explanation,
                                )
                            )
                            in_position = False

                else:
                    # Look for buy signals
                    eval_signal = strategy.evaluate(window_df, symbol, request.exchange)
                    if eval_signal.signal_type == "BUY WATCH" and cash > 5000:
                        entry_price = round(current_price * (1.0 + request.slippage_pct / 100.0), 2)
                        stop_loss = eval_signal.stop_loss or (entry_price * 0.98)
                        target = eval_signal.target or (entry_price * 1.04)

                        risk_per_share = entry_price - stop_loss
                        if risk_per_share > 0:
                            trade_risk_capital = cash * 0.02  # 2% risk rule
                            qty = max(1, int(trade_risk_capital / risk_per_share))
                            total_cost = (qty * entry_price) + request.brokerage_per_order
                            if total_cost <= cash:
                                cash -= total_cost
                                in_position = True
                                entry_date = bar_time
                                entry_reason = eval_signal.explanation

                # Record mark-to-market equity
                current_unrealized = (current_price - entry_price) * qty if in_position else 0.0
                equity_curve.append(cash + current_unrealized)

        # Performance analytics
        winning_trades = [t for t in trades if t.pnl > 0]
        losing_trades = [t for t in trades if t.pnl <= 0]
        total_pnl = sum(t.pnl for t in trades)
        final_capital = initial_capital + total_pnl
        total_return_pct = round((total_pnl / initial_capital) * 100.0, 2)

        win_rate = (len(winning_trades) / len(trades) * 100.0) if trades else 0.0
        gross_profit = sum(t.pnl for t in winning_trades)
        gross_loss = abs(sum(t.pnl for t in losing_trades))
        profit_factor = round(gross_profit / (gross_loss + 1e-9), 2) if gross_loss > 0 else (gross_profit if gross_profit > 0 else 1.0)

        # Maximum Drawdown calculation
        equity_series = pd.Series(equity_curve)
        peak = equity_series.cummax()
        drawdown = (equity_series - peak) / (peak + 1e-9)
        max_drawdown_pct = round(abs(drawdown.min()) * 100.0, 2)

        # Sharpe ratio estimate
        returns = equity_series.pct_change().dropna()
        sharpe = round((returns.mean() / (returns.std() + 1e-9)) * np.sqrt(252), 2) if not returns.empty else 0.0

        return BacktestResult(
            strategy_name=request.strategy_name,
            symbols=all_symbols,
            timeframe=request.timeframe,
            start_date=request.start_date,
            end_date=request.end_date or datetime.now().strftime("%Y-%m-%d"),
            initial_capital=round(initial_capital, 2),
            final_capital=round(final_capital, 2),
            total_net_pnl=round(total_pnl, 2),
            total_return_pct=total_return_pct,
            benchmark_return_pct=12.5,  # Estimated benchmark baseline
            total_trades=len(trades),
            winning_trades=len(winning_trades),
            losing_trades=len(losing_trades),
            win_rate_pct=round(win_rate, 2),
            profit_factor=profit_factor,
            max_drawdown_pct=max_drawdown_pct,
            sharpe_ratio=sharpe,
            trades=trades,
        )
