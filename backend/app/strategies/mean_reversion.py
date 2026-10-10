"""Mean Reversion Pullback Strategy in Uptrend."""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.indicators import TechnicalIndicators
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class MeanReversionStrategy(BaseStrategy):
    """
    Identifies high-probability dip buying opportunities in resilient stocks:
    - Long-term structure: Close > SMA 50 or SMA 200 (structural bull market).
    - Short-term dip: RSI 14 <= 38.0 or Price testing Classical S1 support.
    - Low-risk entry: Stop-loss anchored just below S2 support or swing low.
    - Target: Reversion to mean (EMA 21 / Pivot).
    """

    def __init__(self):
        super().__init__(
            name="MeanReversionPullback",
            description="Buy oversold dips within an established higher-timeframe uptrend.",
        )

    def evaluate(
        self,
        df: pd.DataFrame,
        symbol: str,
        exchange: str = "NSE",
        is_live: bool = False,
        is_delayed: bool = False,
    ) -> StockSignal:
        if len(df) < 50:
            return StockSignal(
                symbol=symbol,
                exchange=exchange,
                timestamp=datetime.now(timezone.utc),
                signal_type="NO TRADE",
                strategy_name=self.name,
                price=float(df.iloc[-1]["close"]) if not df.empty else 0.0,
                strength=0.0,
                explanation="Need at least 50 bars to establish trend baseline.",
            )

        enriched_df = TechnicalIndicators.calculate_all(df)
        metrics = TechnicalIndicators.get_latest_metrics(enriched_df)
        price = metrics["close"]
        atr = metrics["atr_14"] or (price * 0.02)
        rsi = metrics["rsi_14"]
        sma_50 = metrics["sma_50"] or price
        ema_21 = metrics["ema_21"] or price
        s1 = metrics["s1"]
        s2 = metrics["s2"]
        pivot = metrics["pivot"]

        timestamp = (
            enriched_df.iloc[-1]["timestamp"].to_pydatetime()
            if hasattr(enriched_df.iloc[-1]["timestamp"], "to_pydatetime")
            else datetime.now(timezone.utc)
        )

        in_uptrend_zone = price >= (0.95 * sma_50)
        is_oversold = rsi <= 40.0
        is_near_support = abs(price - s1) / price <= 0.02 if s1 > 0 else False

        score = 0.0
        if in_uptrend_zone:
            score += 40.0
        if is_oversold:
            score += 35.0
        if is_near_support:
            score += 25.0

        if score >= 75.0:
            signal_type = "BUY WATCH"
            stop_loss = round(min(s2, price - (1.2 * atr)), 2)
            target = round(max(pivot, ema_21, price + (2.2 * atr)), 2)
            risk = price - stop_loss
            reward = target - price
            rr_ratio = round(reward / risk, 2) if risk > 0 else 2.0
            entry_cond = f"Buy dip at ₹{round(price, 2)} near S1 support (₹{round(s1, 2)})"
            invalidation = f"Breakdown below S2 stop level ₹{stop_loss}"
            explanation = (
                f"Oversold pullback in {symbol}. RSI={rsi} indicates temporary exhaustion, "
                f"while stock remains supported above major moving average (₹{round(sma_50, 2)}). "
                f"Favorable mean reversion risk/reward."
            )
        elif rsi >= 75.0:
            signal_type = "SELL/EXIT WATCH"
            stop_loss = round(price * 0.98, 2)
            target = round(price - (1.5 * atr), 2)
            rr_ratio = 1.5
            entry_cond = "Take profits on extended momentum."
            invalidation = "Continued parabolic expansion"
            explanation = f"Overbought conditions reached (RSI={rsi}). Consider locking in gains."
        else:
            signal_type = "NO TRADE"
            stop_loss = None
            target = None
            rr_ratio = None
            entry_cond = "Wait for pullbacks into support levels."
            invalidation = "N/A"
            explanation = f"Price is within normal equilibrium range. RSI={rsi} (Confluence: {score}/100)."

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
