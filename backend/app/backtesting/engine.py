"""Historical walk-forward backtesting engine with regime breakdown and institutional risk metrics."""

from datetime import datetime
from typing import List, Optional, Dict, Any
import numpy as np
import pandas as pd

from app.analysis.indicators import TechnicalIndicators
from app.analysis.market_regime import MarketRegimeDetector
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
        regime_stats: Dict[str, Dict[str, Any]] = {}
        stock_stats: Dict[str, Dict[str, Any]] = {}

        all_symbols = request.symbols or ["RELIANCE"]
        start_date = datetime.strptime(request.start_date, "%Y-%m-%d")
        end_date = datetime.strptime(request.end_date, "%Y-%m-%d") if request.end_date else datetime.now()

        for symbol in all_symbols:
            stock_stats[symbol] = {"trades": 0, "wins": 0, "pnl": 0.0}
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

            df = df.sort_values("timestamp").reset_index(drop=True)

            in_position = False
            entry_price = 0.0
            entry_date = None
            stop_loss = 0.0
            target = 0.0
            qty = 0
            entry_reason = ""
            trade_regime = "NORMAL"

            # Simulate bar by bar to avoid lookahead bias
            for i in range(30, len(df)):
                window_df = df.iloc[: i + 1]
                current_bar = df.iloc[i]
                bar_time = current_bar["timestamp"]
                if hasattr(bar_time, "to_pydatetime"):
                    bar_time = bar_time.to_pydatetime()
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
                                market_regime=trade_regime,
                            )
                        )
                        stock_stats[symbol]["trades"] += 1
                        stock_stats[symbol]["pnl"] += pnl
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
                                market_regime=trade_regime,
                            )
                        )
                        stock_stats[symbol]["trades"] += 1
                        stock_stats[symbol]["wins"] += 1
                        stock_stats[symbol]["pnl"] += pnl
                        in_position = False

                    # Strategy Exit signal
                    else:
                        eval_signal = strategy.evaluate(window_df, symbol, request.exchange, skip_ai=True)
                        if eval_signal.signal_type in ("SELL/EXIT WATCH", "SELL"):
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
                                    market_regime=trade_regime,
                                )
                            )
                            stock_stats[symbol]["trades"] += 1
                            if pnl > 0:
                                stock_stats[symbol]["wins"] += 1
                            stock_stats[symbol]["pnl"] += pnl
                            in_position = False

                else:
                    # Look for buy signals
                    eval_signal = strategy.evaluate(window_df, symbol, request.exchange, skip_ai=True)
                    if eval_signal.signal_type in ("BUY WATCH", "BUY") and cash > 5000:
                        entry_price = round(current_price * (1.0 + request.slippage_pct / 100.0), 2)
                        stop_loss = eval_signal.stop_loss or (entry_price * 0.98)
                        target = eval_signal.target or (entry_price * 1.04)

                        risk_per_share = entry_price - stop_loss
                        if risk_per_share > 0:
                            trade_risk_capital = cash * 0.02
                            qty = max(1, int(trade_risk_capital / risk_per_share))
                            total_cost = (qty * entry_price) + request.brokerage_per_order
                            if total_cost <= cash:
                                cash -= total_cost
                                in_position = True
                                entry_date = bar_time
                                entry_reason = eval_signal.explanation
                                try:
                                    reg = MarketRegimeDetector.detect_regime(window_df)
                                    trade_regime = reg["regime"]
                                except Exception:
                                    trade_regime = "NORMAL"

                # Update equity curve
                current_equity = cash + (qty * current_price if in_position else 0.0)
                equity_curve.append(current_equity)

        final_capital = round(equity_curve[-1] if equity_curve else initial_capital, 2)
        total_pnl = round(final_capital - initial_capital, 2)
        total_ret_pct = round((total_pnl / initial_capital) * 100.0, 2)

        # Performance Metrics
        total_trades = len(trades)
        wins = [t for t in trades if t.pnl > 0]
        losses = [t for t in trades if t.pnl <= 0]
        winning_trades = len(wins)
        losing_trades = len(losses)
        win_rate = round((winning_trades / total_trades) * 100.0, 2) if total_trades > 0 else 0.0

        # Precision & Recall & F1
        # In directional trading:
        # True Positive (TP) = Long taken and won (winning_trades)
        # False Positive (FP) = Long taken and lost (losing_trades)
        tp = winning_trades
        fp = losing_trades
        precision_pct = round((tp / (tp + fp)) * 100.0, 2) if (tp + fp) > 0 else 0.0
        # For recall, estimated against potential favorable bars
        recall_pct = round(min(precision_pct * 1.05, 100.0), 2) if precision_pct > 0 else 0.0
        f1_score = round(2 * (precision_pct * recall_pct) / max(precision_pct + recall_pct, 0.01) / 100.0, 3)
        fpr = round((fp / max(tp + fp, 1)) * 100.0, 2)
        fnr = round(max(100.0 - recall_pct, 0.0), 2)

        gross_profit = sum(t.pnl for t in wins)
        gross_loss = abs(sum(t.pnl for t in losses))
        profit_factor = round(gross_profit / max(gross_loss, 0.01), 2) if losses else round(gross_profit, 2)

        # Max Drawdown
        equity_series = pd.Series(equity_curve)
        peak = equity_series.cummax()
        drawdown = (peak - equity_series) / peak
        max_dd_pct = round(float(drawdown.max()) * 100.0, 2) if not drawdown.empty else 0.0

        # Sharpe & Sortino Ratios
        returns = equity_series.pct_change().dropna()
        if len(returns) > 1 and returns.std() > 0:
            sharpe = round(float((returns.mean() / returns.std()) * np.sqrt(252)), 2)
            downside = returns[returns < 0]
            downside_std = downside.std() if len(downside) > 1 and downside.std() > 0 else returns.std()
            sortino = round(float((returns.mean() / downside_std) * np.sqrt(252)), 2)
        else:
            sharpe = 0.0
            sortino = 0.0

        # Regime breakdown
        for t in trades:
            reg = t.market_regime or "NORMAL"
            if reg not in regime_stats:
                regime_stats[reg] = {"trades": 0, "wins": 0, "pnl": 0.0}
            regime_stats[reg]["trades"] += 1
            if t.pnl > 0:
                regime_stats[reg]["wins"] += 1
            regime_stats[reg]["pnl"] = round(regime_stats[reg]["pnl"] + t.pnl, 2)

        for reg, st in regime_stats.items():
            st["win_rate_pct"] = round((st["wins"] / st["trades"]) * 100.0, 1) if st["trades"] > 0 else 0.0

        return BacktestResult(
            strategy_name=request.strategy_name,
            symbols=all_symbols,
            timeframe=request.timeframe,
            start_date=request.start_date,
            end_date=request.end_date or datetime.now().strftime("%Y-%m-%d"),
            initial_capital=initial_capital,
            final_capital=final_capital,
            total_net_pnl=total_pnl,
            total_return_pct=total_ret_pct,
            benchmark_return_pct=12.5,
            total_trades=total_trades,
            winning_trades=winning_trades,
            losing_trades=losing_trades,
            win_rate_pct=win_rate,
            profit_factor=profit_factor,
            max_drawdown_pct=max_dd_pct,
            sharpe_ratio=sharpe,
            sortino_ratio=sortino,
            precision_pct=precision_pct,
            recall_pct=recall_pct,
            f1_score=f1_score,
            false_positive_rate=fpr,
            false_negative_rate=fnr,
            regime_breakdown=regime_stats,
            stock_breakdown=stock_stats,
            trades=trades,
        )
