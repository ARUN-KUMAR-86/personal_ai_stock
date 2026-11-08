"""Market Structure & Price Action Intelligence Engine.

Performs institutional price-action analysis:
- Fractal Swing Highs and Swing Lows
- Higher Highs (HH), Higher Lows (HL), Lower Highs (LH), Lower Lows (LL)
- Break of Structure (BOS)
- Change of Character (CHOCH)
- Dynamic Support / Resistance & Order Block Supply/Demand Zones
- Liquidity Sweeps, Stop Hunts, and Breakout Retests
"""

from typing import Dict, Any, List, Optional, Tuple
import numpy as np
import pandas as pd


class MarketStructureAnalyzer:
    """Analyzes market structure and institutional price action on OHLCV series."""

    @staticmethod
    def identify_swing_points(df: pd.DataFrame, window: int = 5) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        Identifies fractal swing highs and swing lows using a symmetric rolling window.
        Avoids lookahead bias by only confirming a swing point after `window` bars have completed.
        """
        highs: List[Dict[str, Any]] = []
        lows: List[Dict[str, Any]] = []

        n = len(df)
        if n < (2 * window + 1):
            return highs, lows

        high_series = df["high"].values
        low_series = df["low"].values
        timestamps = df["timestamp"].values if "timestamp" in df else list(range(n))

        for i in range(window, n - window):
            curr_h = high_series[i]
            curr_l = low_series[i]

            # Check if index i is local maximum
            is_high = True
            for w in range(1, window + 1):
                if high_series[i - w] >= curr_h or high_series[i + w] > curr_h:
                    is_high = False
                    break
            if is_high:
                highs.append({
                    "index": i,
                    "price": float(curr_h),
                    "timestamp": str(timestamps[i]),
                })

            # Check if index i is local minimum
            is_low = True
            for w in range(1, window + 1):
                if low_series[i - w] <= curr_l or low_series[i + w] < curr_l:
                    is_low = False
                    break
            if is_low:
                lows.append({
                    "index": i,
                    "price": float(curr_l),
                    "timestamp": str(timestamps[i]),
                })

        return highs, lows

    @classmethod
    def analyze_structure(cls, df: pd.DataFrame, window: int = 5) -> Dict[str, Any]:
        """
        Comprehensive market structure analysis combining HH/HL/LH/LL sequences,
        BOS, CHOCH, Supply/Demand zones, and liquidity sweeps.
        """
        if len(df) < 25:
            last_c = float(df["close"].iloc[-1]) if len(df) > 0 else 0.0
            return {
                "structure_bias": "NEUTRAL",
                "trend_state": "CONSOLIDATION",
                "last_swing_high": last_c,
                "last_swing_low": last_c,
                "is_higher_high": False,
                "is_higher_low": False,
                "is_lower_high": False,
                "is_lower_low": False,
                "bos_detected": None,
                "choch_detected": None,
                "liquidity_sweep": None,
                "is_breakout_retest": False,
                "support_zones": [],
                "resistance_zones": [],
                "demand_zone": None,
                "supply_zone": None,
                "structure_score": 50.0,
                "details": "Insufficient candle depth for fractal market structure.",
            }

        highs, lows = cls.identify_swing_points(df, window=window)

        # Fallback if few fractals found: use 10-bar rolling extremes
        if len(highs) < 2 or len(lows) < 2:
            h_val = float(df["high"].tail(20).max())
            l_val = float(df["low"].tail(20).min())
            latest_c = float(df["close"].iloc[-1])
            bias = "BULLISH" if latest_c >= (h_val + l_val) / 2 else "BEARISH"
            return {
                "structure_bias": bias,
                "trend_state": "EMERGING_" + bias,
                "last_swing_high": round(h_val, 2),
                "last_swing_low": round(l_val, 2),
                "is_higher_high": False,
                "is_higher_low": False,
                "is_lower_high": False,
                "is_lower_low": False,
                "bos_detected": None,
                "choch_detected": None,
                "liquidity_sweep": None,
                "is_breakout_retest": False,
                "support_zones": [l_val],
                "resistance_zones": [h_val],
                "demand_zone": {"low": round(l_val * 0.99, 2), "high": round(l_val * 1.01, 2)},
                "supply_zone": {"low": round(h_val * 0.99, 2), "high": round(h_val * 1.01, 2)},
                "structure_score": 60.0 if bias == "BULLISH" else 40.0,
                "details": "Structure established via recent 20-bar volatility bounds.",
            }

        latest_price = float(df["close"].iloc[-1])
        latest_high = float(df["high"].iloc[-1])
        latest_low = float(df["low"].iloc[-1])

        last_high = highs[-1]["price"]
        prev_high = highs[-2]["price"] if len(highs) >= 2 else last_high
        last_low = lows[-1]["price"]
        prev_low = lows[-2]["price"] if len(lows) >= 2 else last_low

        is_hh = last_high > prev_high
        is_hl = last_low > prev_low
        is_lh = last_high < prev_high
        is_ll = last_low < prev_low

        # Trend state classification
        if is_hh and is_hl:
            trend_state = "BULLISH_UPTREND"
            structure_bias = "BULLISH"
            base_score = 75.0
        elif is_lh and is_ll:
            trend_state = "BEARISH_DOWNTREND"
            structure_bias = "BEARISH"
            base_score = 25.0
        elif is_hh and is_ll:
            trend_state = "BROADENING_VOLATILITY"
            structure_bias = "NEUTRAL"
            base_score = 50.0
        else:
            trend_state = "CONSOLIDATION_COMPRESSION"
            structure_bias = "NEUTRAL"
            base_score = 50.0

        # Break of Structure (BOS)
        # Bullish BOS: Price closes decisively above the last confirmed swing high
        # Bearish BOS: Price closes decisively below the last confirmed swing low
        bos = None
        if latest_price > last_high:
            bos = {
                "type": "BULLISH_BOS",
                "broken_level": round(last_high, 2),
                "strength": 85.0,
                "description": f"Decisive Break of Structure above swing high ₹{last_high:.2f}. Bullish continuation confirmed.",
            }
            structure_bias = "BULLISH"
            base_score = max(base_score, 80.0)
        elif latest_price < last_low:
            bos = {
                "type": "BEARISH_BOS",
                "broken_level": round(last_low, 2),
                "strength": 85.0,
                "description": f"Decisive Break of Structure below swing low ₹{last_low:.2f}. Bearish continuation confirmed.",
            }
            structure_bias = "BEARISH"
            base_score = min(base_score, 20.0)

        # Change of Character (CHOCH)
        # CHOCH occurs when a downtrend forms a Higher High or an uptrend breaks its Higher Low
        choch = None
        if trend_state == "BEARISH_DOWNTREND" and latest_price > prev_high:
            choch = {
                "type": "BULLISH_CHOCH",
                "level": round(prev_high, 2),
                "strength": 90.0,
                "description": f"Bullish Change of Character: Reclaimed previous swing high ₹{prev_high:.2f}, reversing prior downtrend.",
            }
            structure_bias = "BULLISH"
            base_score = 80.0
        elif trend_state == "BULLISH_UPTREND" and latest_price < prev_low:
            choch = {
                "type": "BEARISH_CHOCH",
                "level": round(prev_low, 2),
                "strength": 90.0,
                "description": f"Bearish Change of Character: Breached prior swing low ₹{prev_low:.2f}, invalidating previous uptrend.",
            }
            structure_bias = "BEARISH"
            base_score = 20.0

        # Liquidity Sweep / Stop Hunt Detection
        # Upper liquidity sweep: High pierces swing high, but close settles back underneath
        liquidity_sweep = None
        if latest_high > last_high and latest_price < last_high:
            sweep_dist = latest_high - last_high
            liquidity_sweep = {
                "type": "BEARISH_LIQUIDITY_SWEEP",
                "level": round(last_high, 2),
                "sweep_high": round(latest_high, 2),
                "rejection_magnitude": round(sweep_dist, 2),
                "description": f"Bearish Liquidity Sweep: Price spiked above ₹{last_high:.2f} to trigger buy-stops then rejected back below.",
            }
            base_score = min(base_score, 35.0)

        # Lower liquidity sweep: Low pierces swing low, but close settles back above
        if latest_low < last_low and latest_price > last_low:
            sweep_dist = last_low - latest_low
            liquidity_sweep = {
                "type": "BULLISH_LIQUIDITY_SWEEP",
                "level": round(last_low, 2),
                "sweep_low": round(latest_low, 2),
                "rejection_magnitude": round(sweep_dist, 2),
                "description": f"Bullish Liquidity Sweep: Price dipped beneath ₹{last_low:.2f} to sweep sell-stops then reclaimed above.",
            }
            base_score = max(base_score, 65.0)

        # Dynamic Support and Resistance Zones (Top 3 clusters)
        s_levels = sorted([l["price"] for l in lows])[-3:]
        r_levels = sorted([h["price"] for h in highs])[:3]

        # Order Block Supply / Demand Zones
        # Demand Zone: The consolidation / base around the most recent validated Higher Low
        demand_zone = {
            "low": round(last_low * 0.995, 2),
            "high": round(last_low * 1.01, 2),
            "significance": "Institutional Order Block / Buyer Defense Zone",
        }
        # Supply Zone: The base around the most recent validated Swing High
        supply_zone = {
            "low": round(last_high * 0.99, 2),
            "high": round(last_high * 1.005, 2),
            "significance": "Institutional Supply Distribution / Resistance Zone",
        }

        # Breakout Retest validation
        is_breakout_retest = False
        if bos and bos["type"] == "BULLISH_BOS":
            # If current price is near the broken swing high (within 1%)
            if abs(latest_price - last_high) <= (0.015 * last_high):
                is_breakout_retest = True

        return {
            "structure_bias": structure_bias,
            "trend_state": trend_state,
            "last_swing_high": round(last_high, 2),
            "last_swing_low": round(last_low, 2),
            "is_higher_high": is_hh,
            "is_higher_low": is_hl,
            "is_lower_high": is_lh,
            "is_lower_low": is_ll,
            "bos_detected": bos,
            "choch_detected": choch,
            "liquidity_sweep": liquidity_sweep,
            "is_breakout_retest": is_breakout_retest,
            "support_zones": [round(x, 2) for x in s_levels],
            "resistance_zones": [round(x, 2) for x in r_levels],
            "demand_zone": demand_zone,
            "supply_zone": supply_zone,
            "structure_score": round(base_score, 1),
            "details": f"Market Structure: {trend_state} (HH={is_hh}, HL={is_hl}, BOS={bos is not None}, CHOCH={choch is not None})",
        }
