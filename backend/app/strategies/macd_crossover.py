"""MACD Crossover with Trend Confirmation Strategy."""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.indicators import TechnicalIndicators
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class MacdCrossStrategy(BaseStrategy):
    """
    Identifies momentum inflection points where:
    - MACD Line crosses above Signal Line.
    - MACD Histogram shifts positive.
    - Price is above EMA 50 to avoid counter-trend fakeouts.
    """

    def __init__(self):
        super().__init__(
            name="MacdCross",
            description="MACD bullish momentum crossover confirmed by medium-term trend filter.",
        )

    def evaluate(
        self,
        df: pd.DataFrame,
        symbol: str,
        exchange: str = "NSE",
        is_live: bool = False,
        is_delayed: bool = False,
    ) -> StockSignal:
        if len(df) < 35:
            return StockSignal(
                symbol=symbol,
                exchange=exchange,
                timestamp=datetime.now(timezone.utc),
                signal_type="NO TRADE",
                strategy_name=self.name,
                price=float(df.iloc[-1]["close"]) if not df.empty else 0.0,
                strength=0.0,
                explanation="Need at least 35 bars to compute MACD (12, 26, 9).",
            )

        enriched_df = TechnicalIndicators.calculate_all(df)
        metrics = TechnicalIndicators.get_latest_metrics(enriched_df)
        price = metrics["close"]
        atr = metrics["atr_14"] or (price * 0.02)
        macd_line = metrics["macd_line"]
        macd_signal = metrics["macd_signal"]
        macd_hist = metrics["macd_hist"]
        ema_50 = metrics["ema_50"] or price

        timestamp = (
            enriched_df.iloc[-1]["timestamp"].to_pydatetime()
            if hasattr(enriched_df.iloc[-1]["timestamp"], "to_pydatetime")
            else datetime.now(timezone.utc)
        )

        # Bullish conditions
        is_bullish_cross = macd_line > macd_signal and macd_hist > 0
        is_above_trend = price > ema_50
        is_fresh_cross = len(enriched_df) > 1 and enriched_df.iloc[-2].get("macd_hist", 0) <= 0.05

        score = 0.0
        if is_bullish_cross:
            score += 40.0
        if is_above_trend:
            score += 30.0
        if is_fresh_cross:
            score += 30.0

        if score >= 70.0:
            signal_type = "BUY WATCH"
            stop_loss = round(price - (1.5 * atr), 2)
            target = round(price + (3.0 * atr), 2)
            rr_ratio = 2.0
            entry_cond = f"Enter on bullish MACD histogram expansion above ₹{round(price, 2)}"
            invalidation = f"MACD line drops below signal line or price breaks below ₹{stop_loss}"
            explanation = (
                f"Bullish MACD crossover confirmed on {symbol}. "
                f"MACD Line ({macd_line}) > Signal Line ({macd_signal}), Histogram={macd_hist}. "
                f"Price ₹{price} is trending above EMA 50 (₹{round(ema_50, 2)})."
            )
        elif macd_line < macd_signal and macd_hist < 0 and price < ema_50:
            signal_type = "SELL/EXIT WATCH"
            stop_loss = round(price + (1.5 * atr), 2)
            target = round(price - (2.5 * atr), 2)
            rr_ratio = 1.6
            entry_cond = "Bearish momentum cross. Protect profits or stand aside."
            invalidation = "MACD recaptures signal line"
            explanation = f"Bearish MACD crossover in progress (Hist={macd_hist})."
        else:
            signal_type = "NO TRADE"
            stop_loss = None
            target = None
            rr_ratio = None
            entry_cond = "Wait for clear MACD crossover."
            invalidation = "N/A"
            explanation = f"MACD is neutral or histogram not in decisive expansion (Score: {score}/100)."

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
