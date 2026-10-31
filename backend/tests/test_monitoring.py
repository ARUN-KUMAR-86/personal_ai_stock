"""Tests for Live Monitoring endpoints and institutional accuracy indicators."""

import pytest
import pandas as pd
import numpy as np
from fastapi.testclient import TestClient

from app.main import app
from app.analysis.indicators import TechnicalIndicators
from app.database.session import SessionLocal
from app.models.stock import Stock

client = TestClient(app)


def test_monitoring_status_endpoint():
    response = client.get("/api/v1/monitoring/status?exchange=NSE")
    assert response.status_code == 200
    data = response.json()
    assert data["app_name"] == "Zed"
    assert "is_live_monitoring_active" in data
    assert "sync_latency_ms" in data
    assert "total_monitored_stocks" in data


def test_monitoring_live_feed_endpoint():
    response = client.get("/api/v1/monitoring/live-feed?exchange=NSE")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "SUCCESS"
    assert "items" in data
    assert isinstance(data["items"], list)
    if len(data["items"]) > 0:
        first = data["items"][0]
        assert "symbol" in first
        assert "price" in first
        assert "tick_direction" in first
        assert "supertrend_direction" in first


def test_institutional_indicators_calculation():
    # Construct 30 bars of synthetic OHLCV data with an uptrend
    np.random.seed(42)
    n = 35
    close = 100.0 + np.cumsum(np.random.normal(0.5, 0.2, n))
    high = close + np.random.uniform(0.5, 1.5, n)
    low = close - np.random.uniform(0.5, 1.5, n)
    open_p = close - np.random.uniform(-0.3, 0.3, n)
    vol = np.random.uniform(10000, 50000, n)

    df = pd.DataFrame({
        "open": open_p,
        "high": high,
        "low": low,
        "close": close,
        "volume": vol,
    })

    enriched = TechnicalIndicators.calculate_all(df)
    assert "supertrend" in enriched.columns
    assert "supertrend_dir" in enriched.columns
    assert "adx_14" in enriched.columns
    assert "bb_upper" in enriched.columns
    assert "bb_lower" in enriched.columns
    assert "upper_wick_ratio" in enriched.columns

    metrics = TechnicalIndicators.get_latest_metrics(enriched)
    assert metrics["supertrend"] is not None
    assert metrics["supertrend_dir"] in (1, -1)
    assert metrics["adx_14"] >= 0.0
    assert metrics["bb_upper"] > metrics["bb_lower"]
    assert 0.0 <= metrics["upper_wick_ratio"] <= 1.0
