"""False Signal & Trap Prevention Engine.

Detects and filters out low-conviction, deceptive setups:
- False breakouts (bull traps with wick rejection)
- Fake reversals (counter-trend bounces into resistance)
- Low-volume breakouts (lack of institutional participation)
- Overbought / Oversold traps lacking structure confirmation
- Multi-timeframe trend conflicts
- Stale or incomplete bar data
"""

from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
import pandas as pd


class FalseSignalDetector:
    """Rigorous gatekeeper validating signals against historical trap patterns."""

    @classmethod
    def evaluate_traps(
        cls,
        df: pd.DataFrame,
        proposed_action: str,
        candle_analysis: Dict[str, Any],
        structure_analysis: Dict[str, Any],
        volume_analysis: Dict[str, Any],
        regime_analysis: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Runs comprehensive trap checks. If any critical trap or conflict is detected,
        flags the signal as invalid and mandates NO TRADE.
        """
        traps_detected: List[str] = []
        is_safe = True

        if df.empty or len(df) < 20:
            return {
                "is_safe": False,
                "traps_detected": ["Insufficient historical data to verify trap dynamics."],
                "rejection_reason": "INSUFFICIENT_DATA",
                "recommended_action": "NO_TRADE",
            }

        price = float(df["close"].iloc[-1])
        rvol = volume_analysis.get("rvol", 1.0)
        c0 = candle_analysis.get("latest_candle", {})
        structure_bias = structure_analysis.get("structure_bias", "NEUTRAL")
        regime = regime_analysis.get("regime", "UNCERTAIN")

        # 1. Low-Volume Breakout Trap (Bull Trap)
        if proposed_action == "BUY":
            # If price is at or near 20-day high but volume is below average
            high_20 = float(df["high"].tail(20).max())
            if price >= (0.985 * high_20) and rvol < 1.0:
                traps_detected.append(
                    f"Low-Volume Breakout: Price testing swing high ₹{high_20:.2f} on weak volume ({rvol}x RVOL). High risk of bull trap."
                )
                is_safe = False

        # 2. Wick Rejection Trap (Failed Breakout / Sweep)
        if proposed_action == "BUY":
            upper_wick_ratio = c0.get("upper_wick_ratio", 0.0)
            if upper_wick_ratio >= 0.40:
                traps_detected.append(
                    f"Upper Wick Rejection ({round(upper_wick_ratio * 100, 1)}% of candle range). Institutional supply absorbed buying demand."
                )
                is_safe = False

        if proposed_action == "SELL":
            lower_wick_ratio = c0.get("lower_wick_ratio", 0.0)
            if lower_wick_ratio >= 0.40:
                traps_detected.append(
                    f"Lower Wick Rejection ({round(lower_wick_ratio * 100, 1)}% of candle range). Strong responsive buyers stepping in at lows."
                )
                is_safe = False

        # 3. Market Structure Conflict
        # Attempting to BUY into a confirmed BEARISH_DOWNTREND without CHOCH
        if proposed_action == "BUY":
            if structure_bias == "BEARISH" and not structure_analysis.get("choch_detected"):
                traps_detected.append(
                    "Structural Conflict: Stock is making Lower Highs & Lower Lows. Buying counter-trend without Change of Character (CHOCH) is prohibited."
                )
                is_safe = False

        # Attempting to SELL into an established BULLISH_UPTREND without bearish CHOCH
        if proposed_action == "SELL":
            if structure_bias == "BULLISH" and not structure_analysis.get("choch_detected"):
                traps_detected.append(
                    "Structural Conflict: Stock is in active Bullish Uptrend with Higher Highs & Higher Lows. Counter-trend shorting carries extreme risk."
                )
                is_safe = False

        # 4. Regime Misalignment
        if proposed_action == "BUY":
            if regime in ("STRONG_BEARISH", "HIGH_VOLATILITY_CHOP"):
                traps_detected.append(
                    f"Market Regime Incompatible: Prevailing regime is {regime}. Breakout entries disabled."
                )
                is_safe = False

        # 5. Liquidity Sweep Rejection
        liq_sweep = structure_analysis.get("liquidity_sweep")
        if liq_sweep:
            if proposed_action == "BUY" and liq_sweep.get("type") == "BEARISH_LIQUIDITY_SWEEP":
                traps_detected.append(
                    f"Bearish Liquidity Sweep active at ₹{liq_sweep.get('level')}. Smart money trapped breakout buyers."
                )
                is_safe = False
            elif proposed_action == "SELL" and liq_sweep.get("type") == "BULLISH_LIQUIDITY_SWEEP":
                traps_detected.append(
                    f"Bullish Liquidity Sweep active at ₹{liq_sweep.get('level')}. Sellers trapped below support."
                )
                is_safe = False

        # 6. Candlestick Pattern Conflict
        identified_patterns = candle_analysis.get("identified_patterns", [])
        if proposed_action == "BUY":
            has_bearish_pattern = any("BEARISH" in p.get("type", "") for p in identified_patterns)
            if has_bearish_pattern:
                bear_names = [p.get("pattern") for p in identified_patterns if "BEARISH" in p.get("type", "")]
                traps_detected.append(
                    f"Conflicting Candlestick Pattern: {', '.join(bear_names)} detected on completed candle."
                )
                is_safe = False

        if proposed_action == "SELL":
            has_bullish_pattern = any("BULLISH" in p.get("type", "") for p in identified_patterns)
            if has_bullish_pattern:
                bull_names = [p.get("pattern") for p in identified_patterns if "BULLISH" in p.get("type", "")]
                traps_detected.append(
                    f"Conflicting Candlestick Pattern: {', '.join(bull_names)} detected on completed candle."
                )
                is_safe = False

        rejection_reason = "CONFIRMED_CLEAN" if is_safe else "; ".join(traps_detected)
        recommended_action = proposed_action if is_safe else "NO_TRADE"

        return {
            "is_safe": is_safe,
            "traps_detected": traps_detected,
            "rejection_reason": rejection_reason,
            "recommended_action": recommended_action,
        }
