"""Gemini Predictive AI Confluence Strategy.

Uses multi-factor technical indicators, machine learning ensemble, volume flow,
candlestick intelligence, and Google Gemini AI to generate high-conviction
predictive signals, target prices, and risk stops.
"""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.gemini_predictor import gemini_stock_predictor
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class GeminiPredictiveAIStrategy(BaseStrategy):
    """
    Gemini Predictive AI Confluence Strategy:
    Predicts stock direction and targets combining:
    - Multi-timeframe trend alignment & market structure
    - Momentum velocity & candlestick confirmation
    - Institutional relative volume surge & VWAP
    - Multi-model ML ensemble probabilities
    - Google Gemini Generative AI synthesis
    """

    def __init__(self):
        super().__init__(
            name="GeminiPredictiveAI",
            description="Deep quantitative predictive confluence paired with institutional ensemble and Google Gemini AI forecasting.",
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
        approval = pred.get("approval_status", "APPROVED")

        # Gated signal mapping:
        # If action is NO TRADE or confidence < 80.0, return NO TRADE – INSUFFICIENT CONFIRMATION
        if action == "NO TRADE" or confidence < 80.0 or approval != "APPROVED_SIGNAL":
            signal_type = "NO TRADE"
            priority = "LOW"
            explanation = f"NO TRADE – INSUFFICIENT CONFIRMATION. {pred.get('verdict_reason', 'Confidence below 80% threshold')}"
        elif direction == "BULLISH":
            signal_type = "BUY" if confidence >= 90.0 else "BUY WATCH"
            priority = "HIGH" if confidence >= 85.0 else "MEDIUM"
            explanation = (
                f"AI Prediction: {direction} ({action}) with {confidence}% confidence targeting ₹{target:.2f} "
                f"({'+' if target > price else ''}{pred['expected_gain_pct']}%). {pred['ai_prediction_summary']}"
            )
        elif direction == "BEARISH":
            signal_type = "SELL" if confidence >= 90.0 else "SELL/EXIT WATCH"
            priority = "HIGH" if confidence >= 85.0 else "MEDIUM"
            explanation = (
                f"AI Prediction: {direction} ({action}) with {confidence}% confidence targeting ₹{target:.2f} "
                f"({'+' if target > price else ''}{pred['expected_gain_pct']}%). {pred['ai_prediction_summary']}"
            )
        else:
            signal_type = "HOLD"
            priority = "LOW"
            explanation = f"AI Prediction: NEUTRAL ({action}). Market in equilibrium. {pred['ai_prediction_summary']}"

        risk = abs(price - stop_loss) if stop_loss else max(price * 0.02, 1.0)
        reward = abs(target - price) if target else max(price * 0.05, 2.0)
        risk_reward = round(reward / risk, 2) if risk > 0 else 2.5

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
            ai_thesis={
                "headline": f"{priority} Priority AI Prediction: {symbol} ({direction})",
                "investment_thesis": pred["ai_prediction_summary"],
                "catalysts": pred.get("key_catalysts", []),
                "risk_factors": pred.get("risk_assessment", []),
                "invalidation_trigger": pred.get("invalidation_trigger", f"Price breach of ₹{stop_loss}"),
                "model_used": pred.get("model_used", "Institutional AI Ensemble"),
                "priority": priority,
                "probabilities": pred.get("probabilities"),
                "market_regime": pred.get("market_regime"),
                "approval_status": approval,
                "verdict_reason": pred.get("verdict_reason"),
            },
        )
