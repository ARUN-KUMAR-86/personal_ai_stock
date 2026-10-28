"""Gemini Predictive AI Confluence Strategy.

Uses multi-factor technical indicators, volume flow, and Google Gemini AI
to generate high-conviction predictive signals, target prices, and risk stops.
"""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.indicators import TechnicalIndicators
from app.analysis.gemini_predictor import gemini_stock_predictor
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class GeminiPredictiveAIStrategy(BaseStrategy):
    """
    Gemini Predictive AI Confluence Strategy:
    Predicts stock direction and targets combining:
    - Multi-timeframe trend alignment (21 EMA / 50 EMA / 50 SMA)
    - Momentum velocity (RSI 14)
    - Institutional relative volume surge (RVOL)
    - Volatility breakout projection (ATR Multiplier)
    - Google Gemini Generative AI synthesis
    """

    def __init__(self):
        super().__init__(
            name="GeminiPredictiveAI",
            description="Deep quantitative predictive confluence paired with Google Gemini AI forecasting.",
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
        if df.empty or len(df) < 10:
            return StockSignal(
                symbol=symbol,
                exchange=exchange,
                timestamp=datetime.now(timezone.utc),
                signal_type="NO TRADE",
                strategy_name=self.name,
                price=float(df.iloc[-1]["close"]) if not df.empty else 0.0,
                strength=0.0,
                priority="LOW",
                explanation="Insufficient candle history for predictive AI evaluation.",
            )

        # Run predictor pass
        pred = gemini_stock_predictor.predict_stock(
            symbol=symbol,
            exchange=exchange,
            df=df,
            time_horizon="1-DAY",
            force_deterministic=skip_ai,
        )

        price = pred["price_at_prediction"]
        target = pred["target_price"]
        stop_loss = pred["stop_loss"]
        confidence = pred["confidence_score"]
        direction = pred["predicted_direction"]
        action = pred["predicted_action"]

        # Signal Type mapping
        if direction == "BULLISH":
            signal_type = "BUY" if confidence >= 80.0 else "BUY WATCH"
            priority = "HIGH" if confidence >= 75.0 else "MEDIUM"
        elif direction == "BEARISH":
            signal_type = "SELL" if confidence >= 80.0 else "SELL/EXIT WATCH"
            priority = "HIGH" if confidence >= 75.0 else "MEDIUM"
        else:
            signal_type = "HOLD"
            priority = "LOW"

        risk = abs(price - stop_loss) if stop_loss else max(price * 0.02, 1.0)
        reward = abs(target - price) if target else max(price * 0.05, 2.0)
        risk_reward = round(reward / risk, 2) if risk > 0 else 2.5

        explanation = (
            f"AI Prediction: {direction} ({action}) with {confidence}% confidence targeting ₹{target:.2f} "
            f"({'+' if target > price else ''}{pred['expected_gain_pct']}%). {pred['ai_prediction_summary']}"
        )

        return StockSignal(
            symbol=symbol,
            exchange=exchange,
            timestamp=datetime.now(timezone.utc),
            signal_type=signal_type,
            strategy_name=self.name,
            price=price,
            stop_loss=stop_loss,
            target=target,
            risk_reward=risk_reward,
            strength=confidence,
            priority=priority,
            company_name=pred.get("company_name", symbol),
            entry_range_low=round(price * 0.995, 2),
            entry_range_high=round(price * 1.005, 2),
            holding_period_hours=48,
            data_source="Live Market Data & Gemini AI",
            data_freshness="Real-Time Tick / Daily",
            indicator_summary=pred.get("algorithm_metrics"),
            explanation=explanation,
            ai_thesis=pred,
        )
