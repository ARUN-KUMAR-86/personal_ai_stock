"""Unit tests for Technical Indicators."""

import numpy as np
import pandas as pd
import pytest
from app.analysis.indicators import TechnicalIndicators


def create_sample_ohlcv(bars: int = 60) -> pd.DataFrame:
    """Generates synthetic price bars for indicator testing."""
    dates = pd.date_range("2024-01-01", periods=bars, freq="D")
    base = 100.0
    trend = np.linspace(0, 20, bars)
    close = base + trend + np.sin(np.linspace(0, 10, bars)) * 2
    high = close + 1.5
    low = close - 1.5
    open_p = close - 0.2
    volume = np.random.uniform(100000, 500000, bars)

    return pd.DataFrame(
        {
            "timestamp": dates,
            "open": open_p,
            "high": high,
            "low": low,
            "close": close,
            "volume": volume,
        }
    )


def test_technical_indicators_calculation():
    df = create_sample_ohlcv(60)
    enriched = TechnicalIndicators.calculate_all(df)

    # Verify calculated indicator columns
    assert "sma_20" in enriched.columns
    assert "ema_21" in enriched.columns
    assert "rsi_14" in enriched.columns
    assert "macd_line" in enriched.columns
    assert "macd_signal" in enriched.columns
    assert "macd_hist" in enriched.columns
    assert "atr_14" in enriched.columns
    assert "rvol" in enriched.columns
    assert "pivot" in enriched.columns
    assert "r1" in enriched.columns
    assert "s1" in enriched.columns

    # Verify RSI values stay in standard 0-100 range
    rsi_vals = enriched["rsi_14"].dropna()
    assert (rsi_vals >= 0).all() and (rsi_vals <= 100).all()

    # Verify ATR is positive
    atr_vals = enriched["atr_14"].dropna()
    assert (atr_vals > 0).all()


def test_get_latest_metrics():
    df = create_sample_ohlcv(50)
    enriched = TechnicalIndicators.calculate_all(df)
    metrics = TechnicalIndicators.get_latest_metrics(enriched)

    assert "close" in metrics
    assert "rsi_14" in metrics
    assert "atr_14" in metrics
    assert "rvol" in metrics
    assert "pivot" in metrics
    assert isinstance(metrics["close"], float)
