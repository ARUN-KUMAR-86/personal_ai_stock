"""Market Regime Classification & Strategy Compatibility Engine.

Classifies the prevailing market regime into:
- STRONG_BULLISH
- WEAK_BULLISH
- STRONG_BEARISH
- WEAK_BEARISH
- SIDEWAYS_CHOP
- HIGH_VOLATILITY
- LOW_VOLATILITY_COMPRESSION
- EVENT_DRIVEN_UNCERTAIN

Provides strategy gating to prevent applying breakout models in choppy markets
or mean-reversion dip buying into freefalling breakdowns.
"""

from typing import Dict, Any, Optional
import numpy as np
import pandas as pd


class MarketRegimeDetector:
    """Institutional market regime classifier based on trend persistence, ADX, and volatility."""

    @classmethod
    def detect_regime(cls, df: pd.DataFrame, index_df: Optional[pd.DataFrame] = None) -> Dict[str, Any]:
        """
        Classifies regime using moving averages, ADX, Bollinger Band width, and ATR percentile.
        """
        if df.empty or len(df) < 20:
            return {
                "regime": "UNCERTAIN",
                "trend_strength": "LOW",
                "volatility_regime": "NORMAL",
                "strategy_recommendation": "NO_TRADE",
                "is_trend_favored": False,
                "is_mean_reversion_favored": False,
                "regime_score": 50.0,
                "rationale": "Insufficient historical bars to classify market regime.",
            }

        c = df["close"]
        h = df["high"]
        l = df["low"]
        price = float(c.iloc[-1])

        # Trend indicators
        sma_50 = float(c.rolling(50).mean().iloc[-1]) if len(c) >= 50 else price
        sma_200 = float(c.rolling(200).mean().iloc[-1]) if len(c) >= 200 else price
        ema_21 = float(c.ewm(span=21, adjust=False).mean().iloc[-1])
        ema_50 = float(c.ewm(span=50, adjust=False).mean().iloc[-1])

        # Volatility & Bands
        tr1 = h - l
        tr2 = (h - c.shift(1)).abs()
        tr3 = (l - c.shift(1)).abs()
        tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        atr_14 = float(tr.rolling(14).mean().iloc[-1]) if len(tr) >= 14 else max(price * 0.02, 1.0)
        atr_pct = (atr_14 / price) * 100.0

        std_20 = float(c.rolling(20).std().iloc[-1]) if len(c) >= 20 else 0.0
        sma_20 = float(c.rolling(20).mean().iloc[-1]) if len(c) >= 20 else price
        bb_width = ((2.0 * 2.0 * std_20) / (sma_20 + 1e-9)) * 100.0

        # ADX Calculation
        up = h - h.shift(1)
        down = l.shift(1) - l
        plus_dm = np.where((up > down) & (up > 0), up, 0.0)
        minus_dm = np.where((down > up) & (down > 0), down, 0.0)
        atr_adx = tr.ewm(com=13, adjust=False).mean()
        plus_di = 100 * (pd.Series(plus_dm, index=df.index).ewm(com=13, adjust=False).mean() / (atr_adx + 1e-9))
        minus_di = 100 * (pd.Series(minus_dm, index=df.index).ewm(com=13, adjust=False).mean() / (atr_adx + 1e-9))
        dx = 100 * ((plus_di - minus_di).abs() / ((plus_di + minus_di) + 1e-9))
        adx_14 = float(dx.ewm(com=13, adjust=False).mean().iloc[-1])
        p_di = float(plus_di.iloc[-1])
        m_di = float(minus_di.iloc[-1])

        # Regime classification
        is_bullish_alignment = price >= ema_21 and ema_21 >= ema_50 and price >= sma_50
        is_bearish_alignment = price <= ema_21 and ema_21 <= ema_50 and price <= sma_50
        is_high_vol = atr_pct > 3.5 or bb_width > 12.0
        is_low_vol = bb_width < 3.0 and adx_14 < 18.0

        if is_high_vol and adx_14 < 20.0:
            regime = "HIGH_VOLATILITY_CHOP"
            strat_rec = "WAIT_FOR_STABILIZATION"
            trend_favored = False
            mr_favored = False
        elif is_low_vol:
            regime = "LOW_VOLATILITY_COMPRESSION"
            strat_rec = "PREPARE_BREAKOUT_WATCH"
            trend_favored = False
            mr_favored = False
        elif is_bullish_alignment and adx_14 >= 25.0 and p_di > m_di:
            regime = "STRONG_BULLISH"
            strat_rec = "TREND_BREAKOUT_AND_MOMENTUM"
            trend_favored = True
            mr_favored = False
        elif is_bullish_alignment or (price > sma_50 and p_di >= m_di):
            regime = "WEAK_BULLISH"
            strat_rec = "PULLBACK_DIP_BUYING"
            trend_favored = True
            mr_favored = True
        elif is_bearish_alignment and adx_14 >= 25.0 and m_di > p_di:
            regime = "STRONG_BEARISH"
            strat_rec = "CAPITAL_PRESERVATION_OR_HEDGE"
            trend_favored = False
            mr_favored = False
        elif is_bearish_alignment or (price < sma_50 and m_di > p_di):
            regime = "WEAK_BEARISH"
            strat_rec = "DEFENSIVE_HOLD_OR_TRIM"
            trend_favored = False
            mr_favored = False
        elif adx_14 < 20.0:
            regime = "SIDEWAYS_CHOP"
            strat_rec = "RANGE_BOUND_SUPPORT_RESISTANCE"
            trend_favored = False
            mr_favored = True
        else:
            regime = "UNCERTAIN"
            strat_rec = "NO_TRADE_INSUFFICIENT_CONVICTION"
            trend_favored = False
            mr_favored = False

        rationale = (
            f"Market classified as {regime}. ADX={adx_14:.1f} (+DI={p_di:.1f}, -DI={m_di:.1f}), "
            f"Daily ATR={atr_pct:.1f}%, BB Width={bb_width:.1f}%. Strategy Focus: {strat_rec}."
        )

        return {
            "regime": regime,
            "trend_strength": "HIGH" if adx_14 >= 25 else ("MODERATE" if adx_14 >= 18 else "LOW"),
            "volatility_regime": "HIGH" if is_high_vol else ("LOW" if is_low_vol else "NORMAL"),
            "adx_14": round(adx_14, 1),
            "plus_di": round(p_di, 1),
            "minus_di": round(m_di, 1),
            "atr_pct": round(atr_pct, 2),
            "bb_width": round(bb_width, 2),
            "strategy_recommendation": strat_rec,
            "is_trend_favored": trend_favored,
            "is_mean_reversion_favored": mr_favored,
            "rationale": rationale,
        }
