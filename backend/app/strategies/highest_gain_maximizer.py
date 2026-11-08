"""Highest Gain Maximizer Strategy - Focuses on maximum upside potential and automatic profit taking."""

from datetime import datetime, timezone
import pandas as pd
from app.analysis.indicators import TechnicalIndicators
from app.analysis.candlestick_intelligence import CandlestickIntelligence
from app.analysis.market_structure import MarketStructureAnalyzer
from app.analysis.volume_intelligence import VolumeIntelligence
from app.analysis.false_signal_detector import FalseSignalDetector
from app.analysis.market_regime import MarketRegimeDetector
from app.models.signal import StockSignal
from app.strategies.base import BaseStrategy


class HighestGainMaximizerStrategy(BaseStrategy):
    """
    Highest Gain Maximizer Strategy (Auto Take Money):
    Identifies high-momentum stocks with maximum upside return potential and strong risk:reward.
    - Large potential moves (2.5x to 3.5x ATR).
    - Tight risk management with 1.2x ATR stop loss (1:2.5+ Risk/Reward ratio).
    - Professional Price-Action, Candlestick & Market Structure gating.
    - Strict thresholding: signals require >= 80% confluence and zero false breakout traps.
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
            p_val = float(df.iloc[-1]["close"]) if not df.empty else 100.0
            return StockSignal(
                symbol=symbol,
                exchange=exchange,
                timestamp=datetime.now(timezone.utc),
                signal_type="NO TRADE",
                strategy_name="HighestProfitMaximizer",
                price=p_val,
                target=round(p_val * 1.05, 2),
                stop_loss=round(p_val * 0.98, 2),
                strength=0.0,
                priority="LOW",
                explanation="Insufficient candle history to calculate highest gain metrics (minimum 30 bars required).",
                ai_thesis={"priority": "LOW", "headline": "Insufficient History"},
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

        timestamp = (
            enriched_df.iloc[-1]["timestamp"].to_pydatetime()
            if hasattr(enriched_df.iloc[-1]["timestamp"], "to_pydatetime")
            else datetime.now(timezone.utc)
        )

        # Advanced Intelligence Passes
        candle_res = CandlestickIntelligence.detect_patterns(df)
        struct_res = MarketStructureAnalyzer.analyze_structure(df)
        vol_res = VolumeIntelligence.calculate_volume_metrics(df)
        regime_res = MarketRegimeDetector.detect_regime(df)

        # Structural & Flow Conditions
        is_ma_uptrend = (ema_21 >= ema_50) and (price >= sma_50 * 0.98)
        is_supertrend_bull = (supertrend_dir == 1) and (price >= supertrend * 0.99)
        is_struct_bullish = struct_res["structure_bias"] == "BULLISH"
        is_volume_surge = vol_res["rvol"] >= 1.25 and vol_res["volume_confirmed"]
        is_momentum_zone = 52.0 <= rsi <= 72.0
        is_adx_trending = (adx >= 22.0) and (plus_di >= minus_di)
        is_near_high = price >= (0.975 * swing_high)

        # False Signal & Trap Evaluation
        trap_result = FalseSignalDetector.evaluate_traps(
            df=df,
            proposed_action="BUY",
            candle_analysis=candle_res,
            structure_analysis=struct_res,
            volume_analysis=vol_res,
            regime_analysis=regime_res,
        )

        # Risk parameters
        upside_atr = max(3.0 * atr, price * 0.045)
        downside_atr = min(1.2 * atr, price * 0.02)
        target = round(price + upside_atr, 2)
        swing_low_ref = struct_res.get("last_swing_low", price - downside_atr)
        if swing_low_ref >= price:
            swing_low_ref = price - downside_atr
        raw_sl = max(price - downside_atr, swing_low_ref * 0.99, 0.5)
        if is_supertrend_bull and supertrend > 0 and supertrend < price:
            stop_loss = round(min(price - 0.5, max(raw_sl, supertrend * 0.995)), 2)
        else:
            stop_loss = round(min(price - 0.5, raw_sl), 2)

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
        if is_struct_bullish:
            score += 20.0
        if is_volume_surge:
            score += 15.0
        if is_momentum_zone:
            score += 15.0
        if is_adx_trending:
            score += 10.0

        if not trap_result["is_safe"]:
            score = min(score, 55.0)

        # Strict Institutional Gating
        if score >= 85.0 and trap_result["is_safe"] and potential_gain_pct >= 3.0:
            priority = "HIGH"
            signal_type = "BUY WATCH"
            explanation = (
                f"HIGH PRIORITY: Maximum Gain Opportunity on {symbol}. "
                f"Target price ₹{target} (+{potential_gain_pct}%). Structure: {struct_res['trend_state']}. "
                f"RSI={rsi:.1f}, RVOL={vol_res['rvol']:.2f}x. Risk-Reward 1:{rr_ratio}. "
                f"Auto-sell configured to take profit at target."
            )
        elif score >= 80.0 and trap_result["is_safe"]:
            priority = "MEDIUM"
            signal_type = "BUY WATCH"
            explanation = (
                f"MEDIUM PRIORITY: Validated gain setup on {symbol}. "
                f"Target ₹{target} (+{potential_gain_pct}%). Score: {score}/100. "
                f"Clean false signal filter check."
            )
        else:
            priority = "LOW"
            signal_type = "NO TRADE"
            rejection = trap_result["rejection_reason"] if not trap_result["is_safe"] else f"Score {score}/100 below 80% threshold"
            explanation = f"NO TRADE – INSUFFICIENT CONFIRMATION. {rejection}."

        ai_thesis = {
            "headline": f"{priority} PRIORITY: +{potential_gain_pct}% Max Profit Target for {symbol}",
            "investment_thesis": explanation,
            "catalysts": [
                f"Institutional volume flow: {vol_res['rvol']}x average volume",
                f"Market Structure: {struct_res['trend_state']}",
                f"Favorable Risk-to-Reward ratio (1:{rr_ratio})",
            ],
            "risk_factors": [
                f"Protective stop-loss at ₹{stop_loss}",
                f"Traps detected: {len(trap_result['traps_detected'])}",
                f"Market regime: {regime_res['regime']}",
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
                **metrics,
                "priority": priority,
                "potential_gain_pct": potential_gain_pct,
                "market_regime": regime_res["regime"],
            },
            score_breakdown={
                "ma_trend": 20.0 if is_ma_uptrend else 0.0,
                "supertrend": 20.0 if is_supertrend_bull else 0.0,
                "structure": 20.0 if is_struct_bullish else 0.0,
                "volume": 15.0 if is_volume_surge else 0.0,
                "momentum": 15.0 if is_momentum_zone else 0.0,
                "adx_strength": 10.0 if is_adx_trending else 0.0,
                "total_score": score,
                "priority": priority,
            },
            explanation=explanation,
            ai_thesis=ai_thesis,
        )
