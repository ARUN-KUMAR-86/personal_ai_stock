"""Technical analysis indicators calculated over OHLCV data using Pandas & NumPy."""

from typing import Dict, Any, Optional
import numpy as np
import pandas as pd


class TechnicalIndicators:
    """Calculates standard technical indicators without black-box abstractions."""

    @staticmethod
    def calculate_all(df: pd.DataFrame) -> pd.DataFrame:
        """Enriches the input OHLCV DataFrame with all standard indicators."""
        if len(df) < 20:
            return df

        df = df.copy()
        close = df["close"]
        high = df["high"]
        low = df["low"]
        volume = df["volume"]

        # Simple Moving Averages
        df["sma_20"] = close.rolling(window=20).mean()
        df["sma_50"] = close.rolling(window=50).mean()
        df["sma_200"] = close.rolling(window=200).mean()

        # Exponential Moving Averages
        df["ema_9"] = close.ewm(span=9, adjust=False).mean()
        df["ema_21"] = close.ewm(span=21, adjust=False).mean()
        df["ema_50"] = close.ewm(span=50, adjust=False).mean()

        # RSI (14) - Wilder's smoothed
        delta = close.diff()
        gain = delta.clip(lower=0)
        loss = -delta.clip(upper=0)
        avg_gain = gain.ewm(com=13, adjust=False).mean()
        avg_loss = loss.ewm(com=13, adjust=False).mean()
        rs = avg_gain / (avg_loss + 1e-9)
        df["rsi_14"] = 100 - (100 / (1 + rs))

        # MACD (12, 26, 9)
        ema_12 = close.ewm(span=12, adjust=False).mean()
        ema_26 = close.ewm(span=26, adjust=False).mean()
        df["macd_line"] = ema_12 - ema_26
        df["macd_signal"] = df["macd_line"].ewm(span=9, adjust=False).mean()
        df["macd_hist"] = df["macd_line"] - df["macd_signal"]

        # ATR (14) - Average True Range
        tr1 = high - low
        tr2 = (high - close.shift(1)).abs()
        tr3 = (low - close.shift(1)).abs()
        tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        df["atr_14"] = tr.rolling(window=14).mean()

        # Relative Volume (RVOL) = Volume / 20-period Avg Volume
        avg_vol_20 = volume.rolling(window=20).mean()
        df["vol_avg_20"] = avg_vol_20
        df["rvol"] = volume / (avg_vol_20 + 1e-9)

        # Rate of Change (Momentum 10-period)
        df["roc_10"] = ((close - close.shift(10)) / (close.shift(10) + 1e-9)) * 100

        # Pivot Points (Support & Resistance Estimates based on latest candle)
        prev_h = high.shift(1)
        prev_l = low.shift(1)
        prev_c = close.shift(1)
        pivot = (prev_h + prev_l + prev_c) / 3.0
        df["pivot"] = pivot
        df["r1"] = (2 * pivot) - prev_l
        df["s1"] = (2 * pivot) - prev_h
        df["r2"] = pivot + (prev_h - prev_l)
        df["s2"] = pivot - (prev_h - prev_l)

        # 20-Day Swing High / Low for breakouts
        df["swing_high_20"] = high.rolling(window=20).max()
        df["swing_low_20"] = low.rolling(window=20).min()

        # Bollinger Bands (20, 2) - Volatility Squeeze & Expansion
        std_20 = close.rolling(window=20).std()
        df["bb_middle"] = df["sma_20"]
        df["bb_upper"] = df["bb_middle"] + (2.0 * std_20)
        df["bb_lower"] = df["bb_middle"] - (2.0 * std_20)
        df["bb_width"] = (df["bb_upper"] - df["bb_lower"]) / (df["bb_middle"] + 1e-9)
        df["bb_pct_b"] = (close - df["bb_lower"]) / (df["bb_upper"] - df["bb_lower"] + 1e-9)

        # ADX (14) - Directional Movement & Trend Strength (filters false chop)
        up_move = high - high.shift(1)
        down_move = low.shift(1) - low
        plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
        minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)
        atr_adx = tr.ewm(com=13, adjust=False).mean()
        plus_di = 100 * (pd.Series(plus_dm, index=df.index).ewm(com=13, adjust=False).mean() / (atr_adx + 1e-9))
        minus_di = 100 * (pd.Series(minus_dm, index=df.index).ewm(com=13, adjust=False).mean() / (atr_adx + 1e-9))
        dx = 100 * ((plus_di - minus_di).abs() / ((plus_di + minus_di) + 1e-9))
        df["adx_14"] = dx.ewm(com=13, adjust=False).mean()
        df["plus_di"] = plus_di
        df["minus_di"] = minus_di

        # Supertrend (10, 3.0) - Institutional Trend Filter
        st_atr = tr.rolling(window=10).mean()
        hl2 = (high + low) / 2.0
        basic_upper = hl2 + (3.0 * st_atr)
        basic_lower = hl2 - (3.0 * st_atr)
        final_upper = basic_upper.copy()
        final_lower = basic_lower.copy()
        supertrend = pd.Series(index=df.index, dtype=float)
        st_dir = pd.Series(1, index=df.index, dtype=int)

        for i in range(10, len(df)):
            c_val = close.iloc[i]
            prev_c = close.iloc[i - 1]
            prev_u = final_upper.iloc[i - 1]
            prev_l = final_lower.iloc[i - 1]

            if basic_upper.iloc[i] < prev_u or prev_c > prev_u:
                final_upper.iloc[i] = basic_upper.iloc[i]
            else:
                final_upper.iloc[i] = prev_u

            if basic_lower.iloc[i] > prev_l or prev_c < prev_l:
                final_lower.iloc[i] = basic_lower.iloc[i]
            else:
                final_lower.iloc[i] = prev_l

            if st_dir.iloc[i - 1] == 1:
                if c_val < final_lower.iloc[i]:
                    st_dir.iloc[i] = -1
                    supertrend.iloc[i] = final_upper.iloc[i]
                else:
                    st_dir.iloc[i] = 1
                    supertrend.iloc[i] = final_lower.iloc[i]
            else:
                if c_val > final_upper.iloc[i]:
                    st_dir.iloc[i] = 1
                    supertrend.iloc[i] = final_lower.iloc[i]
                else:
                    st_dir.iloc[i] = -1
                    supertrend.iloc[i] = final_upper.iloc[i]

        df["supertrend"] = supertrend
        df["supertrend_dir"] = st_dir

        # Candlestick anatomy and trap detection
        o_val = df.get("open", close)
        candle_range = (high - low).clip(lower=1e-5)
        upper_wick = high - pd.concat([close, o_val], axis=1).max(axis=1)
        df["upper_wick_ratio"] = upper_wick / candle_range

        # Trend direction flag (Confluence of Moving Averages & Supertrend)
        st_bull = (df["supertrend_dir"] == 1) if "supertrend_dir" in df else True
        df["uptrend"] = (df["ema_21"] > df["ema_50"]) & (df["close"] > df["sma_50"]) & st_bull

        return df

    @staticmethod
    def get_latest_metrics(df: pd.DataFrame) -> Dict[str, Any]:
        """Extracts the latest row indicator metrics as a clean dictionary."""
        if df.empty:
            return {}

        latest = df.iloc[-1]
        prev = df.iloc[-2] if len(df) > 1 else latest

        return {
            "close": float(latest.get("close", 0.0)),
            "sma_20": float(latest.get("sma_20", 0.0)) if pd.notna(latest.get("sma_20")) else None,
            "sma_50": float(latest.get("sma_50", 0.0)) if pd.notna(latest.get("sma_50")) else None,
            "sma_200": float(latest.get("sma_200", 0.0)) if pd.notna(latest.get("sma_200")) else None,
            "ema_9": float(latest.get("ema_9", 0.0)) if pd.notna(latest.get("ema_9")) else None,
            "ema_21": float(latest.get("ema_21", 0.0)) if pd.notna(latest.get("ema_21")) else None,
            "ema_50": float(latest.get("ema_50", 0.0)) if pd.notna(latest.get("ema_50")) else None,
            "rsi_14": float(round(latest.get("rsi_14", 50.0), 2)) if pd.notna(latest.get("rsi_14")) else 50.0,
            "macd_line": float(round(latest.get("macd_line", 0.0), 2)) if pd.notna(latest.get("macd_line")) else 0.0,
            "macd_signal": float(round(latest.get("macd_signal", 0.0), 2)) if pd.notna(latest.get("macd_signal")) else 0.0,
            "macd_hist": float(round(latest.get("macd_hist", 0.0), 2)) if pd.notna(latest.get("macd_hist")) else 0.0,
            "atr_14": float(round(latest.get("atr_14", 0.0), 2)) if pd.notna(latest.get("atr_14")) else 0.0,
            "rvol": float(round(latest.get("rvol", 1.0), 2)) if pd.notna(latest.get("rvol")) else 1.0,
            "roc_10": float(round(latest.get("roc_10", 0.0), 2)) if pd.notna(latest.get("roc_10")) else 0.0,
            "pivot": float(round(latest.get("pivot", 0.0), 2)) if pd.notna(latest.get("pivot")) else 0.0,
            "r1": float(round(latest.get("r1", 0.0), 2)) if pd.notna(latest.get("r1")) else 0.0,
            "s1": float(round(latest.get("s1", 0.0), 2)) if pd.notna(latest.get("s1")) else 0.0,
            "r2": float(round(latest.get("r2", 0.0), 2)) if pd.notna(latest.get("r2")) else 0.0,
            "s2": float(round(latest.get("s2", 0.0), 2)) if pd.notna(latest.get("s2")) else 0.0,
            "swing_high_20": float(round(latest.get("swing_high_20", 0.0), 2)) if pd.notna(latest.get("swing_high_20")) else 0.0,
            "swing_low_20": float(round(latest.get("swing_low_20", 0.0), 2)) if pd.notna(latest.get("swing_low_20")) else 0.0,
            "supertrend": float(round(latest.get("supertrend", 0.0), 2)) if pd.notna(latest.get("supertrend")) else None,
            "supertrend_dir": int(latest.get("supertrend_dir", 1)) if pd.notna(latest.get("supertrend_dir")) else 1,
            "adx_14": float(round(latest.get("adx_14", 20.0), 2)) if pd.notna(latest.get("adx_14")) else 20.0,
            "plus_di": float(round(latest.get("plus_di", 0.0), 2)) if pd.notna(latest.get("plus_di")) else 0.0,
            "minus_di": float(round(latest.get("minus_di", 0.0), 2)) if pd.notna(latest.get("minus_di")) else 0.0,
            "bb_upper": float(round(latest.get("bb_upper", 0.0), 2)) if pd.notna(latest.get("bb_upper")) else None,
            "bb_lower": float(round(latest.get("bb_lower", 0.0), 2)) if pd.notna(latest.get("bb_lower")) else None,
            "bb_width": float(round(latest.get("bb_width", 0.0), 4)) if pd.notna(latest.get("bb_width")) else None,
            "upper_wick_ratio": float(round(latest.get("upper_wick_ratio", 0.0), 3)) if pd.notna(latest.get("upper_wick_ratio")) else 0.0,
            "is_uptrend": bool(latest.get("uptrend", False)),
        }
