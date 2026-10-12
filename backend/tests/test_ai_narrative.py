"""Tests for AI Narrative and Explainable Thesis Generator."""

import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

from app.analysis.narrative import AINarrativeGenerator
from app.main import app
from app.models.signal import StockSignal
from app.database.session import SessionLocal

client = TestClient(app)


def test_deterministic_thesis_buy_watch():
    generator = AINarrativeGenerator()
    metrics = {
        "rsi_14": 62.5,
        "rvol": 1.75,
        "ema_21": 2920.0,
        "ema_50": 2850.0,
        "sma_50": 2830.0,
        "sma_200": 2600.0,
        "atr_14": 42.0,
        "swing_high_20": 2980.0,
        "swing_low_20": 2800.0,
        "pivot": 2930.0,
        "r1": 2975.0,
        "s1": 2890.0,
    }

    res = generator.generate_thesis(
        symbol="RELIANCE",
        company_name="Reliance Industries Ltd",
        exchange="NSE",
        signal_type="BUY WATCH",
        strategy_name="MomentumBreakout",
        price=2950.0,
        stop_loss=2890.0,
        target=3070.0,
        risk_reward=2.0,
        metrics=metrics,
        force_deterministic=True,
    )

    assert "headline" in res
    assert "RELIANCE" in res["headline"]
    assert "investment_thesis" in res
    assert len(res["investment_thesis"]) > 50
    assert "catalysts" in res and len(res["catalysts"]) >= 3
    assert "risk_factors" in res and len(res["risk_factors"]) >= 3
    assert "technical_summary" in res
    assert "tactical_plan" in res
    assert res["tactical_plan"]["time_horizon"] == "24 to 48 Hours"
    assert "Quantitative Confluence Engine" in res["model_used"]


def test_deterministic_thesis_sell_watch():
    generator = AINarrativeGenerator()
    metrics = {
        "rsi_14": 34.0,
        "rvol": 1.4,
        "ema_21": 1550.0,
        "ema_50": 1580.0,
        "sma_50": 1590.0,
        "atr_14": 25.0,
    }

    res = generator.generate_thesis(
        symbol="INFY",
        company_name="Infosys Ltd",
        exchange="NSE",
        signal_type="SELL/EXIT WATCH",
        strategy_name="MomentumBreakout",
        price=1510.0,
        metrics=metrics,
        force_deterministic=True,
    )

    assert "Exit Watch" in res["headline"] or "Tactical Exit" in res["headline"]
    assert "tactical_plan" in res
    assert res["tactical_plan"]["suggested_allocation_pct"] == 0.0


def test_gemini_fallback_on_error():
    generator = AINarrativeGenerator()
    metrics = {"rsi_14": 58.0, "rvol": 1.3}

    with patch.object(generator, "_generate_via_gemini", side_effect=Exception("API Rate Limit")):
        res = generator.generate_thesis(
            symbol="TCS",
            company_name="Tata Consultancy Services",
            signal_type="BUY WATCH",
            strategy_name="MomentumBreakout",
            price=4100.0,
            metrics=metrics,
            force_deterministic=False,
        )

        assert res is not None
        assert "investment_thesis" in res
        assert "Quantitative Confluence Engine" in res["model_used"]


def test_api_stock_thesis_endpoint():
    response = client.get("/api/v1/stocks/RELIANCE/thesis?exchange=NSE")
    assert response.status_code == 200
    data = response.json()
    assert "headline" in data
    assert "investment_thesis" in data
    assert "catalysts" in data
    assert "risk_factors" in data


def test_api_regenerate_thesis_endpoint():
    # Fetch recommendation to ensure signal exists
    rec_resp = client.get("/api/v1/signals/recommendation/RELIANCE?exchange=NSE")
    assert rec_resp.status_code == 200
    sig_id = rec_resp.json()["id"]

    regen_resp = client.post(f"/api/v1/signals/{sig_id}/thesis/regenerate")
    assert regen_resp.status_code == 200
    sig_data = regen_resp.json()
    assert sig_data["ai_thesis"] is not None
    assert "investment_thesis" in sig_data["ai_thesis"]
    assert sig_data["ai_thesis"]["headline"] != ""
