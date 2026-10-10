"""Trend Momentum Breakout Strategy."""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.indicators import TechnicalIndicators
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class MomentumBreakoutStrategy(BaseStrategy):
    """
    Identifies high-momentum breakout opportunities where:
    - Trend is positive: EMA 21 > EMA 50 and Close > SMA 50.
    - Momentum is sustained: RSI between 52 and 70 (not overbought > 75).
    - Volume confirmation: RVOL >= 1.25x the 20-period moving average.
    - Volatility breakout: Close >= 0.995 * 20-day swing high.
    """

    def __init__(self):
        super().__init__(
            name="MomentumBreakout",
            description="High-relative-volume trend breakout with ATR-based risk control.",
        )

    def evaluate(
        self,
        df: pd.DataFrame,
        symbol: str,
        exchange: str = "NSE",
        is_live: bool = False,
        is_delayed: bool = False,
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
                explanation="Insufficient candle history to calculate breakout metrics (minimum 30 required).",
            )

        enriched_df = TechnicalIndicators.calculate_all(df)
        metrics = TechnicalIndicators.get_latest_metrics(enriched_df)
        price = metrics["close"]
        atr = metrics["atr_14"] or (price * 0.02)
        rvol = metrics["rvol"]
        rsi = metrics["rsi_14"]
        ema_21 = metrics["ema_21"] or price
        ema_50 = metrics["ema_50"] or price
        sma_50 = metrics["sma_50"] or price
        swing_high = metrics["swing_high_20"] or price

        timestamp = (
            enriched_df.iloc[-1]["timestamp"].to_pydatetime()
            if hasattr(enriched_df.iloc[-1]["timestamp"], "to_pydatetime")
            else datetime.now(timezone.utc)
        )

        # Check conditions
        is_uptrend = (ema_21 > ema_50) and (price > sma_50)
        is_volume_breakout = rvol >= 1.2
        is_rsi_healthy = 52.0 <= rsi <= 72.0
        is_near_breakout = price >= (0.99 * swing_high)

        # Score confluence (strength 0 - 100)
        score = 0.0
        if is_uptrend:
            score += 30.0
        if is_volume_breakout:
            score += 30.0
        if is_rsi_healthy:
            score += 20.0
        if is_near_breakout:
            score += 20.0

        if score >= 80.0:
            signal_type = "BUY WATCH"
            stop_loss = round(price - (1.5 * atr), 2)
            target = round(price + (3.0 * atr), 2)
            risk = price - stop_loss
            reward = target - price
            rr_ratio = round(reward / risk, 2) if risk > 0 else 2.0
            entry_cond = f"Enter on confirmation above ₹{round(price, 2)} with RVOL > 1.2x"
            invalidation = f"Close below EMA 21 (₹{round(ema_21, 2)}) or breakdown below ₹{stop_loss}"
            explanation = (
                f"Bullish momentum breakout detected on {symbol}. "
                f"EMA 21 (₹{round(ema_21, 2)}) is above EMA 50 (₹{round(ema_50, 2)}). "
                f"RSI is healthy at {rsi} with elevated relative volume of {rvol}x. "
                f"Stock is challenging 20-day high (₹{round(swing_high, 2)})."
            )
        elif is_uptrend and price > (price - 1.5 * atr):
            signal_type = "HOLD"
            stop_loss = round(price - (1.5 * atr), 2)
            target = round(price + (2.5 * atr), 2)
            risk = price - stop_loss
            reward = target - price
            rr_ratio = round(reward / risk, 2) if risk > 0 else 1.8
            entry_cond = "Hold existing position. Trailing stop active."
            invalidation = f"Exit on close below stop loss ₹{stop_loss}"
            explanation = (
                f"Trend remains constructive above SMA 50. Hold existing long positions. "
                f"RSI={rsi}, RVOL={rvol}x."
            )
        elif rsi < 40.0 or price < ema_50:
            signal_type = "SELL/EXIT WATCH"
            stop_loss = round(price * 1.02, 2)
            target = round(price - (2.0 * atr), 2)
            rr_ratio = 1.5
            entry_cond = "Exit long positions or wait for market structure reset."
            invalidation = f"Price reclaiming EMA 21 (₹{round(ema_21, 2)})"
            explanation = (
                f"Weakness detected. Price ₹{price} has fallen below key moving averages or RSI ({rsi}) is declining."
            )
        else:
            signal_type = "NO TRADE"
            stop_loss = None
            target = None
            rr_ratio = None
            entry_cond = "Wait for breakout above 20-day high with volume confirmation."
            invalidation = "N/A"
            explanation = f"Consolidating. No high-conviction breakout pattern currently active (Score: {score}/100)."

        return StockSignal(
            symbol=symbol,
            exchange=exchange,
            timestamp=timestamp,
            signal_type=signal_type,
            strategy_name=self.name,
            price=price,
            stop_loss=stop_loss,
            target=target,
            risk_reward=rr_ratio,
            strength=score,
            entry_condition=entry_cond,
            invalidation_condition=invalidation,
            indicator_summary=metrics,
            explanation=explanation,
        )
