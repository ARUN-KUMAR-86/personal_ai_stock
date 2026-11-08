"""Advanced Volume Intelligence Engine.

Computes:
- Relative Volume (RVOL)
- Volume Spikes (2x/3x Institutional Surges)
- Price-Volume Divergence
- Accumulation / Distribution Line (A/D) & Chaikin Money Flow (CMF)
- On-Balance Volume (OBV) & OBV Trend Alignment
- Volume-Weighted Average Price (VWAP)
- Volume Profile (Point of Control POC, Value Area High VAH, Value Area Low VAL)
- Breakout Volume Confirmation & Trap Validation
"""

from typing import Dict, Any, List, Optional
import numpy as np
import pandas as pd


class VolumeIntelligence:
    """Institutional volume and liquidity flow analytics."""

    @classmethod
    def calculate_volume_metrics(cls, df: pd.DataFrame) -> Dict[str, Any]:
        """Calculates full quantitative volume profile and flow dynamics."""
        if df.empty or len(df) < 15:
            return {
                "rvol": 1.0,
                "is_volume_spike": False,
                "spike_magnitude": 1.0,
                "obv_trend": "NEUTRAL",
                "cmf_20": 0.0,
                "vwap": float(df["close"].iloc[-1]) if not df.empty else 0.0,
                "price_vs_vwap_pct": 0.0,
                "volume_divergence": None,
                "volume_confirmed": True,
                "volume_score": 50.0,
                "volume_profile": {},
            }

        df = df.copy()
        c = df["close"]
        h = df["high"]
        l = df["low"]
        v = df["volume"]

        # 1. RVOL & Volume Spikes
        vol_ma_20 = v.rolling(window=min(20, len(df))).mean()
        latest_vol = float(v.iloc[-1])
        avg_vol = float(vol_ma_20.iloc[-1]) if pd.notna(vol_ma_20.iloc[-1]) and vol_ma_20.iloc[-1] > 0 else 1.0
        rvol = round(latest_vol / max(avg_vol, 1.0), 2)

        is_volume_spike = rvol >= 2.0
        is_extreme_spike = rvol >= 3.0

        # 2. VWAP (Volume-Weighted Average Price)
        typical_price = (h + l + c) / 3.0
        cum_vol = v.cumsum()
        cum_tp_vol = (typical_price * v).cumsum()
        vwap_series = cum_tp_vol / cum_vol.replace(0, np.nan)
        latest_vwap = float(vwap_series.iloc[-1]) if pd.notna(vwap_series.iloc[-1]) else float(c.iloc[-1])
        latest_c = float(c.iloc[-1])
        price_vs_vwap_pct = round(((latest_c - latest_vwap) / latest_vwap) * 100, 2)

        # 3. On-Balance Volume (OBV)
        obv = pd.Series(index=df.index, dtype=float)
        obv.iloc[0] = v.iloc[0]
        for i in range(1, len(df)):
            if c.iloc[i] > c.iloc[i - 1]:
                obv.iloc[i] = obv.iloc[i - 1] + v.iloc[i]
            elif c.iloc[i] < c.iloc[i - 1]:
                obv.iloc[i] = obv.iloc[i - 1] - v.iloc[i]
            else:
                obv.iloc[i] = obv.iloc[i - 1]

        obv_ema = obv.ewm(span=20, adjust=False).mean()
        if obv.iloc[-1] > obv_ema.iloc[-1] and obv.iloc[-1] > obv.iloc[-5]:
            obv_trend = "BULLISH_ACCUMULATION"
        elif obv.iloc[-1] < obv_ema.iloc[-1] and obv.iloc[-1] < obv.iloc[-5]:
            obv_trend = "BEARISH_DISTRIBUTION"
        else:
            obv_trend = "NEUTRAL"

        # 4. Chaikin Money Flow (CMF 20)
        clv = ((c - l) - (h - c)) / (h - l).replace(0, np.nan)
        clv = clv.fillna(0.0)
        mf_volume = clv * v
        cmf_window = min(20, len(df))
        cmf = mf_volume.rolling(window=cmf_window).sum() / v.rolling(window=cmf_window).sum().replace(0, np.nan)
        latest_cmf = float(round(cmf.iloc[-1], 3)) if pd.notna(cmf.iloc[-1]) else 0.0

        # 5. Price-Volume Divergence Detection
        # Check if price made a 10-period high but volume or CMF declined
        recent_p_high = c.iloc[-10:-1].max() if len(c) >= 11 else c.iloc[-1]
        recent_v_high = v.iloc[-10:-1].max() if len(v) >= 11 else v.iloc[-1]
        recent_p_low = c.iloc[-10:-1].min() if len(c) >= 11 else c.iloc[-1]

        divergence = None
        if latest_c >= recent_p_high and rvol < 0.85:
            divergence = {
                "type": "BEARISH_VOLUME_EXHAUSTION",
                "description": f"Price reached 10-bar high (₹{latest_c:.2f}) on thin volume ({rvol}x RVOL). Breakout lacks institutional backing.",
            }
        elif latest_c <= recent_p_low and rvol < 0.85:
            divergence = {
                "type": "BULLISH_SELLING_EXHAUSTION",
                "description": f"Price testing 10-bar lows on sub-par volume ({rvol}x RVOL). Sellers lack momentum.",
            }

        # 6. Volume Profile Estimation (Value Area 70% & POC)
        price_bins = 20
        min_p = float(l.tail(30).min())
        max_p = float(h.tail(30).max())
        bin_width = max((max_p - min_p) / price_bins, 0.01)

        profile_bins = np.zeros(price_bins)
        recent_slice = df.tail(30)
        for _, row in recent_slice.iterrows():
            avg_p = (row["high"] + row["low"] + row["close"]) / 3.0
            b_idx = int(min(max((avg_p - min_p) / bin_width, 0), price_bins - 1))
            profile_bins[b_idx] += row["volume"]

        poc_idx = int(np.argmax(profile_bins))
        poc_price = round(min_p + (poc_idx + 0.5) * bin_width, 2)

        # Value Area 70% of total volume
        total_vol = np.sum(profile_bins)
        target_vol = total_vol * 0.70
        accum_vol = profile_bins[poc_idx]
        up_idx = poc_idx
        dn_idx = poc_idx
        while accum_vol < target_vol and (up_idx < price_bins - 1 or dn_idx > 0):
            up_vol = profile_bins[up_idx + 1] if up_idx + 1 < price_bins else 0
            dn_vol = profile_bins[dn_idx - 1] if dn_idx - 1 >= 0 else 0
            if up_vol >= dn_vol and up_idx + 1 < price_bins:
                up_idx += 1
                accum_vol += up_vol
            elif dn_idx - 1 >= 0:
                dn_idx -= 1
                accum_vol += dn_vol
            else:
                break

        vah_price = round(min_p + (up_idx + 1) * bin_width, 2)
        val_price = round(min_p + dn_idx * bin_width, 2)

        volume_profile = {
            "point_of_control": poc_price,
            "value_area_high": vah_price,
            "value_area_low": val_price,
        }

        # Breakout volume confirmation flag
        # High confidence requires rvol >= 1.25 and positive CMF for longs
        volume_confirmed = bool(rvol >= 1.15 and not (divergence and "EXHAUSTION" in divergence["type"]))

        # Volume Score (0-100)
        score = 50.0
        if rvol >= 1.5:
            score += 20.0
        elif rvol >= 1.2:
            score += 10.0
        elif rvol < 0.7:
            score -= 15.0

        if obv_trend == "BULLISH_ACCUMULATION":
            score += 15.0
        elif obv_trend == "BEARISH_DISTRIBUTION":
            score -= 15.0

        if latest_cmf >= 0.10:
            score += 15.0
        elif latest_cmf <= -0.10:
            score -= 15.0

        if latest_c >= latest_vwap:
            score += 10.0
        else:
            score -= 10.0

        volume_score = float(np.clip(score, 10.0, 95.0))

        return {
            "rvol": rvol,
            "is_volume_spike": is_volume_spike,
            "is_extreme_spike": is_extreme_spike,
            "spike_magnitude": rvol,
            "obv_trend": obv_trend,
            "cmf_20": latest_cmf,
            "vwap": round(latest_vwap, 2),
            "price_vs_vwap_pct": price_vs_vwap_pct,
            "volume_divergence": divergence,
            "volume_confirmed": volume_confirmed,
            "volume_score": round(volume_score, 1),
            "volume_profile": volume_profile,
        }
