"""Advanced Candlestick Intelligence & Pattern Recognition Engine.

Analyzes candlestick anatomy (body, upper/lower wicks, range, volume) within
structural and trend context. Requires completed candle confirmation before
validating any formation.
"""

from typing import Dict, Any, List, Optional
import numpy as np
import pandas as pd


class CandlestickIntelligence:
    """Professional candlestick pattern recognition with multi-bar confirmation."""

    @staticmethod
    def analyze_candle_anatomy(df: pd.DataFrame, idx: int = -1) -> Dict[str, Any]:
        """Calculates precise physical dimensions and ratios of a specific candle."""
        if df.empty or len(df) < abs(idx):
            return {}

        row = df.iloc[idx]
        o = float(row.get("open", row["close"]))
        h = float(row["high"])
        l = float(row["low"])
        c = float(row["close"])
        vol = float(row.get("volume", 0.0))

        candle_range = max(h - l, 1e-6)
        body_size = abs(c - o)
        upper_wick = max(h - max(o, c), 0.0)
        lower_wick = max(min(o, c) - l, 0.0)

        body_ratio = body_size / candle_range
        upper_wick_ratio = upper_wick / candle_range
        lower_wick_ratio = lower_wick / candle_range
        is_bullish = c > o
        is_bearish = c < o
        is_neutral = abs(c - o) <= (0.05 * candle_range)

        # Average candle range over previous 14 bars
        hist_ranges = (df["high"] - df["low"]).tail(20)
        avg_range = float(hist_ranges.mean()) if not hist_ranges.empty else candle_range
        relative_size = candle_range / max(avg_range, 1e-6)

        return {
            "open": round(o, 2),
            "high": round(h, 2),
            "low": round(l, 2),
            "close": round(c, 2),
            "volume": vol,
            "range": round(candle_range, 2),
            "body_size": round(body_size, 2),
            "upper_wick": round(upper_wick, 2),
            "lower_wick": round(lower_wick, 2),
            "body_ratio": round(body_ratio, 3),
            "upper_wick_ratio": round(upper_wick_ratio, 3),
            "lower_wick_ratio": round(lower_wick_ratio, 3),
            "is_bullish": is_bullish,
            "is_bearish": is_bearish,
            "is_neutral": is_neutral,
            "relative_size": round(relative_size, 2),
        }

    @classmethod
    def detect_patterns(cls, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Detects primary single-candle and multi-candle formations.
        Evaluates the last 3-5 completed candles with structural context.
        """
        if len(df) < 5:
            return {
                "identified_patterns": [],
                "candle_bias": "NEUTRAL",
                "confirmation_status": "UNCONFIRMED",
                "pattern_score": 50.0,
                "latest_candle": {},
            }

        c0 = cls.analyze_candle_anatomy(df, idx=-1)  # latest completed bar
        c1 = cls.analyze_candle_anatomy(df, idx=-2)  # previous bar
        c2 = cls.analyze_candle_anatomy(df, idx=-3)  # 2 bars ago

        patterns: List[Dict[str, Any]] = []

        # 1. Bullish & Bearish Engulfing
        if c1["is_bearish"] and c0["is_bullish"]:
            if c0["close"] >= c1["open"] and c0["open"] <= c1["close"] and c0["body_size"] > c1["body_size"]:
                patterns.append({
                    "pattern": "Bullish Engulfing",
                    "type": "BULLISH_REVERSAL",
                    "strength": 80.0,
                    "description": "Bullish candle completely engulfs previous bearish body, signaling institutional absorption.",
                })

        if c1["is_bullish"] and c0["is_bearish"]:
            if c0["close"] <= c1["open"] and c0["open"] >= c1["close"] and c0["body_size"] > c1["body_size"]:
                patterns.append({
                    "pattern": "Bearish Engulfing",
                    "type": "BEARISH_REVERSAL",
                    "strength": 80.0,
                    "description": "Bearish candle engulfs prior bullish candle, signaling strong supply liquidation.",
                })

        # 2. Hammer & Shooting Star / Inverted Hammer
        if c0["lower_wick_ratio"] >= 0.55 and c0["upper_wick_ratio"] <= 0.15 and c0["body_ratio"] <= 0.35:
            patterns.append({
                "pattern": "Hammer / Pin Bar",
                "type": "BULLISH_REJECTION",
                "strength": 75.0,
                "description": "Long lower shadow rejects lower prices; buyers stepped in aggressively at lows.",
            })

        if c0["upper_wick_ratio"] >= 0.55 and c0["lower_wick_ratio"] <= 0.15 and c0["body_ratio"] <= 0.35:
            patterns.append({
                "pattern": "Shooting Star / Bearish Pin Bar",
                "type": "BEARISH_REJECTION",
                "strength": 75.0,
                "description": "Long upper shadow rejects overhead supply; sellers forced price down off highs.",
            })

        # 3. Morning Star & Evening Star (3-candle pattern)
        if c2["is_bearish"] and c2["body_ratio"] >= 0.45:
            if c1["body_ratio"] <= 0.30 and c1["close"] < c2["close"]:
                if c0["is_bullish"] and c0["close"] >= (c2["open"] + c2["close"]) / 2:
                    patterns.append({
                        "pattern": "Morning Star",
                        "type": "BULLISH_REVERSAL",
                        "strength": 88.0,
                        "description": "Three-bar Morning Star pattern confirms bottoming and strong bullish continuation.",
                    })

        if c2["is_bullish"] and c2["body_ratio"] >= 0.45:
            if c1["body_ratio"] <= 0.30 and c1["close"] > c2["close"]:
                if c0["is_bearish"] and c0["close"] <= (c2["open"] + c2["close"]) / 2:
                    patterns.append({
                        "pattern": "Evening Star",
                        "type": "BEARISH_REVERSAL",
                        "strength": 88.0,
                        "description": "Three-bar Evening Star pattern confirms top exhaustion and impending bearish rotation.",
                    })

        # 4. Doji Variations
        if c0["body_ratio"] <= 0.10:
            if c0["lower_wick_ratio"] >= 0.60 and c0["upper_wick_ratio"] <= 0.15:
                doji_name = "Dragonfly Doji"
                doji_bias = "BULLISH_REVERSAL"
            elif c0["upper_wick_ratio"] >= 0.60 and c0["lower_wick_ratio"] <= 0.15:
                doji_name = "Gravestone Doji"
                doji_bias = "BEARISH_REVERSAL"
            else:
                doji_name = "Long-Legged Doji"
                doji_bias = "INDECISION"

            patterns.append({
                "pattern": doji_name,
                "type": doji_bias,
                "strength": 65.0,
                "description": f"{doji_name} reflects extreme indecision / market equilibrium at test levels.",
            })

        # 5. Marubozu (Decisive Trend Dominance)
        if c0["body_ratio"] >= 0.82:
            if c0["is_bullish"]:
                patterns.append({
                    "pattern": "Bullish Marubozu",
                    "type": "BULLISH_CONTINUATION",
                    "strength": 78.0,
                    "description": "Large full-body green candle with minimal wicks, demonstrating total buyer dominance.",
                })
            elif c0["is_bearish"]:
                patterns.append({
                    "pattern": "Bearish Marubozu",
                    "type": "BEARISH_CONTINUATION",
                    "strength": 78.0,
                    "description": "Large full-body red candle with minimal wicks, demonstrating aggressive seller dominance.",
                })

        # 6. Tweezer Tops & Bottoms
        if abs(c0["low"] - c1["low"]) <= (0.001 * c0["close"]) and c1["is_bearish"] and c0["is_bullish"]:
            patterns.append({
                "pattern": "Tweezer Bottom",
                "type": "BULLISH_REVERSAL",
                "strength": 72.0,
                "description": "Twin candle lows at identical support level confirm double-rejection floor.",
            })

        if abs(c0["high"] - c1["high"]) <= (0.001 * c0["close"]) and c1["is_bullish"] and c0["is_bearish"]:
            patterns.append({
                "pattern": "Tweezer Top",
                "type": "BEARISH_REVERSAL",
                "strength": 72.0,
                "description": "Twin candle highs at identical resistance level confirm double-rejection ceiling.",
            })

        # 7. Inside Bar & Outside Bar
        if c0["high"] <= c1["high"] and c0["low"] >= c1["low"]:
            patterns.append({
                "pattern": "Inside Bar",
                "type": "CONSOLIDATION_COMPRESSION",
                "strength": 60.0,
                "description": "Price compressed completely inside prior bar range. Precedes explosive expansion.",
            })

        if c0["high"] > c1["high"] and c0["low"] < c1["low"]:
            patterns.append({
                "pattern": "Outside Bar / Engulfing Range",
                "type": "EXPANSION_VOLATILITY",
                "strength": 70.0,
                "description": "Current candle fully encompasses prior bar range, signaling liquidity hunt & volatility expansion.",
            })

        # 8. Three White Soldiers & Three Black Crows
        if len(df) >= 3:
            if c2["is_bullish"] and c1["is_bullish"] and c0["is_bullish"]:
                if c0["close"] > c1["close"] > c2["close"] and c0["body_ratio"] > 0.5 and c1["body_ratio"] > 0.5:
                    patterns.append({
                        "pattern": "Three White Soldiers",
                        "type": "BULLISH_CONTINUATION",
                        "strength": 85.0,
                        "description": "Three consecutive strong upward-closing candles indicating sustained institutional markup.",
                    })
            elif c2["is_bearish"] and c1["is_bearish"] and c0["is_bearish"]:
                if c0["close"] < c1["close"] < c2["close"] and c0["body_ratio"] > 0.5 and c1["body_ratio"] > 0.5:
                    patterns.append({
                        "pattern": "Three Black Crows",
                        "type": "BEARISH_CONTINUATION",
                        "strength": 85.0,
                        "description": "Three consecutive heavy downward-closing candles indicating aggressive institutional markdown.",
                    })

        # 9. Rejection & Failed Breakout Candles
        # If candle tested swing high with elevated upper wick > 45%
        recent_high_10 = df["high"].iloc[-11:-1].max() if len(df) >= 11 else c0["high"]
        if c0["high"] >= recent_high_10 and c0["upper_wick_ratio"] >= 0.40 and c0["close"] < recent_high_10:
            patterns.append({
                "pattern": "Failed Breakout Rejection",
                "type": "BEARISH_TRAP",
                "strength": 85.0,
                "description": "Wick pierced above 10-bar swing high but closed back underneath; bull trap confirmed.",
            })

        recent_low_10 = df["low"].iloc[-11:-1].min() if len(df) >= 11 else c0["low"]
        if c0["low"] <= recent_low_10 and c0["lower_wick_ratio"] >= 0.40 and c0["close"] > recent_low_10:
            patterns.append({
                "pattern": "Failed Breakdown Liquidity Sweep",
                "type": "BULLISH_TRAP_REVERSAL",
                "strength": 85.0,
                "description": "Wick pierced beneath 10-bar swing low but closed back inside; bear trap / liquidity sweep confirmed.",
            })

        # Determine overall candlestick directional bias & score
        bullish_weights = [p["strength"] for p in patterns if "BULLISH" in p["type"]]
        bearish_weights = [p["strength"] for p in patterns if "BEARISH" in p["type"]]

        net_bull = sum(bullish_weights)
        net_bear = sum(bearish_weights)

        if net_bull > net_bear and net_bull >= 70.0:
            candle_bias = "BULLISH"
            pattern_score = min(50.0 + (net_bull / 2.0), 95.0)
            confirmation_status = "CONFIRMED"
        elif net_bear > net_bull and net_bear >= 70.0:
            candle_bias = "BEARISH"
            pattern_score = max(50.0 - (net_bear / 2.0), 10.0)
            confirmation_status = "CONFIRMED"
        else:
            candle_bias = "NEUTRAL"
            pattern_score = 50.0
            confirmation_status = "UNCONFIRMED" if patterns else "NO_PATTERN"

        return {
            "identified_patterns": patterns,
            "candle_bias": candle_bias,
            "confirmation_status": confirmation_status,
            "pattern_score": round(pattern_score, 1),
            "latest_candle": c0,
            "previous_candle": c1,
        }
