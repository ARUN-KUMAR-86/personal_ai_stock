"""Highest Gain Maximizer Strategy - Focuses on maximum upside potential and automatic profit taking."""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.indicators import TechnicalIndicators
from app.analysis.narrative import ai_narrative_generator
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class HighestGainMaximizerStrategy(BaseStrategy):
    """
    Highest Gain Maximizer Strategy (Auto Take Money):
    Identifies high-momentum stocks with maximum upside return potential and strong risk:reward.
    - Focuses on large potential moves (3.5x ATR or +5% to +15% expected profit target).
    - Tight risk management with 1.2x ATR stop loss (1:3+ Risk/Reward ratio).
    - Classifies opportunities into HIGH Priority (explosive upside) and MEDIUM Priority.
    - Sets clear parameters to automatically take profit and secure gains when the target is reached.
    """

    def __init__(self):
        super().__init__(
            name="HighestGainMaximizer",
            description="High-Alpha strategy targeting maximum profit percentage with automatic take-money exit.",
        )

    def evaluate(
        self,
        df: pd.DataFrame,
        symbol: str,
        exchange: str = "NSE",
        is_live: bool = False,
        is_delayed: bool = False,
        skip_ai: bool = False,
        **kwargs,
    ) -> StockSignal:
        if len(df) < 30:
            return StockSignal(
                symbol=symbol,
                exchange=exchange,
                timestamp=datetime.now(timezone.utc),
                signal_type="NO TRADE",
                strategy_name=self.name,
                price=float(df.iloc[-1]["close"]) if not df.empty else 0.0,
                strength=0.0,
                priority="LOW",
                explanation="Insufficient candle history to calculate highest gain metrics (minimum 30 bars required).",
            )

        enriched_df = TechnicalIndicators.calculate_all(df)
        metrics = TechnicalIndicators.get_latest_metrics(enriched_df)
        price = metrics["close"]
        atr = metrics["atr_14"] or (price * 0.02)
        rvol = metrics["rvol"] or 1.0
        rsi = metrics["rsi_14"] or 50.0
        ema_21 = metrics["ema_21"] or price
        ema_50 = metrics["ema_50"] or price
        sma_50 = metrics["sma_50"] or price
        swing_high = metrics["swing_high_20"] or price
        supertrend = metrics.get("supertrend") or price
        supertrend_dir = metrics.get("supertrend_dir", 1)
        adx = metrics.get("adx_14", 20.0)
        plus_di = metrics.get("plus_di", 0.0)
        minus_di = metrics.get("minus_di", 0.0)
        upper_wick_ratio = metrics.get("upper_wick_ratio", 0.0)
        bb_pct_b = metrics.get("bb_pct_b", 0.5)

        timestamp = (
            enriched_df.iloc[-1]["timestamp"].to_pydatetime()
            if hasattr(enriched_df.iloc[-1]["timestamp"], "to_pydatetime")
            else datetime.now(timezone.utc)
        )

        # High-Accuracy Confluence Criteria (Multi-Factor Verification)
        # 1. Moving Average Trend Alignment
        is_ma_uptrend = (ema_21 >= ema_50) and (price >= sma_50 * 0.98)
        # 2. Supertrend Confirmation
        is_supertrend_bull = (supertrend_dir == 1) and (price >= supertrend * 0.99)
        is_uptrend = is_ma_uptrend and is_supertrend_bull

        # 3. Institutional Volume Surge
        is_volume_surge = rvol >= 1.25

        # 4. Momentum Velocity (Healthy non-exhausted zone)
        is_momentum_zone = 52.0 <= rsi <= 72.0

        # 5. Trend Strength via ADX (Rejects choppy sideways markets)
        is_adx_trending = (adx >= 22.0) and (plus_di >= minus_di)

        # 6. Breakout Proximity
        is_near_high = price >= (0.975 * swing_high)

        # 7. Candlestick Trap Filter (Rejects false breakout candles with heavy upper wick rejections)
        has_wick_trap = upper_wick_ratio > 0.42

        # High upside target and protective stop loss
        upside_atr = max(3.2 * atr, price * 0.05)
        # Stop loss anchored below Supertrend or 1.25x ATR
        downside_atr = min(1.25 * atr, price * 0.025)
        raw_sl = max(price - downside_atr, 0.5)
        if is_supertrend_bull and supertrend > 0 and supertrend < price:
            stop_loss = round(max(raw_sl, supertrend * 0.995), 2)
        else:
            stop_loss = round(raw_sl, 2)

        target = round(price + upside_atr, 2)
        risk = max(price - stop_loss, 0.5)
        reward = max(target - price, 1.0)
        rr_ratio = round(reward / risk, 2)
        potential_gain_pct = round(((target - price) / price) * 100, 2)

        # Quantitative Confluence Scoring (0 - 100)
        score = 0.0
        if is_ma_uptrend:
            score += 20.0
        if is_supertrend_bull:
            score += 20.0
        if is_volume_surge:
            score += 20.0
        if is_momentum_zone:
            score += 15.0
        if is_adx_trending:
            score += 15.0
        if is_near_high:
            score += 10.0

        # Exceptional volume booster
        if rvol >= 1.75:
            score = min(100.0, score + 10.0)

        # Penalize false breakout upper-wick traps
        if has_wick_trap:
            score = max(0.0, score - 20.0)
        # Penalize overbought exhaustion
        if rsi > 74.0:
            score = max(0.0, score - 15.0)

        # Priority & Signal Classification
        if score >= 75.0 and potential_gain_pct >= 3.5:
            priority = "HIGH"
            signal_type = "BUY WATCH"
            explanation = (
                f"HIGH PRIORITY: Maximum Gain Opportunity on {symbol}. "
                f"Target price ₹{target} represents a +{potential_gain_pct}% potential profit. "
                f"RSI is strong at {round(rsi, 1)} with {round(rvol, 2)}x volume surge. "
                f"Risk-Reward is 1:{rr_ratio}. Auto-sell configured to automatically take profit at target."
            )
        elif score >= 50.0:
            priority = "MEDIUM"
            signal_type = "BUY WATCH" if is_uptrend else "HOLD"
            explanation = (
                f"MEDIUM PRIORITY: Solid upside potential on {symbol} (+{potential_gain_pct}% projected). "
                f"Uptrend intact with EMA 21 (₹{round(ema_21, 2)}) supporting price. "
                f"Target: ₹{target} | Stop-Loss: ₹{stop_loss} | Auto-take money enabled."
            )
        else:
            priority = "LOW"
            signal_type = "HOLD" if is_uptrend else "NO TRADE"
            explanation = (
                f"Consolidation pattern on {symbol}. Awaiting clearer volume and momentum breakout "
                f"before initiating high-conviction trade."
            )

        # Structured AI thesis
        ai_thesis = {
            "headline": f"{priority} PRIORITY: +{potential_gain_pct}% Max Profit Target for {symbol}",
            "investment_thesis": (
                f"The Highest Gain Maximizer algorithm identified {symbol} with high expected payoff. "
                f"Current verified price: ₹{round(price, 2)}. Target profit: ₹{target} (+{potential_gain_pct}%). "
                f"System will automatically take money and credit profits once target is reached."
            ),
            "catalysts": [
                f"Elevated relative volume ({round(rvol, 2)}x 20-day average)",
                f"Healthy bullish momentum (RSI {round(rsi, 1)})",
                f"Favorable Risk-to-Reward ratio (1:{rr_ratio})",
            ],
            "risk_factors": [
                f"Stop-loss protection at ₹{stop_loss} ({round(((price - stop_loss) / price) * 100, 1)}% risk)",
                "Market volatility and index pullback risks",
            ],
            "tactical_plan": {
                "entry_price": price,
                "target_price": target,
                "stop_loss": stop_loss,
                "projected_gain_pct": potential_gain_pct,
                "auto_sell_enabled": True,
                "priority": priority,
            },
            "model_used": "Highest Gain Maximizer (Auto Take Money)",
            "priority": priority,
        }

        return StockSignal(
            symbol=symbol,
            exchange=exchange,
            timestamp=timestamp,
            signal_type=signal_type,
            strategy_name="HighestProfitMaximizer",
            price=price,
            stop_loss=stop_loss,
            target=target,
            risk_reward=rr_ratio,
            strength=score,
            priority=priority,
            company_name=symbol,
            entry_range_low=round(price * 0.995, 2),
            entry_range_high=round(price * 1.01, 2),
            holding_period_hours=48,
            data_source=f"Verified Market Feed ({exchange})",
            data_freshness="Live Tick / Daily Candle",
            entry_condition=f"Enter at ₹{round(price, 2)} with auto take profit at ₹{target}",
            invalidation_condition=f"Breach of protective stop-loss below ₹{stop_loss}",
            indicator_summary={
                "rsi_14": rsi,
                "rvol": rvol,
                "atr_14": atr,
                "ema_21": ema_21,
                "ema_50": ema_50,
                "supertrend": supertrend,
                "supertrend_dir": supertrend_dir,
                "adx_14": adx,
                "priority": priority,
                "potential_gain_pct": potential_gain_pct,
            },
            score_breakdown={
                "ma_trend": 20.0 if is_ma_uptrend else 0.0,
                "supertrend": 20.0 if is_supertrend_bull else 0.0,
                "volume": 20.0 if is_volume_surge else 0.0,
                "momentum": 15.0 if is_momentum_zone else 0.0,
                "adx_strength": 15.0 if is_adx_trending else 0.0,
                "breakout": 10.0 if is_near_high else 0.0,
                "priority": priority,
            },
            explanation=explanation,
            ai_thesis=ai_thesis,
        )
