"""Tests for Gemini Stock Predictor, Predictive AI Strategy, and Prediction API endpoints."""

from fastapi.testclient import TestClient
from app.main import app
from app.analysis.gemini_predictor import gemini_stock_predictor
from app.strategies.predictive_ai_confluence import GeminiPredictiveAIStrategy
from app.providers.mock_provider import MockMarketDataProvider

client = TestClient(app)


def test_gemini_predictor_deterministic():
    provider = MockMarketDataProvider()
    df = provider.get_historical_ohlcv("RELIANCE")

    pred = gemini_stock_predictor.predict_stock(
        symbol="RELIANCE",
        company_name="Reliance Industries Ltd",
        exchange="NSE",
        df=df,
        time_horizon="1-DAY",
        force_deterministic=True,
    )

    assert pred["symbol"] == "RELIANCE"
    assert pred["predicted_direction"] in ("BULLISH", "BEARISH", "NEUTRAL")
    assert pred["predicted_action"] in ("STRONG BUY", "BUY", "HOLD", "SELL", "STRONG SELL")
    assert pred["target_price"] > 0
    assert pred["confidence_score"] >= 0.0
    assert "working_algorithm" in pred
    assert "algorithm_metrics" in pred
    assert "rsi_14" in pred["algorithm_metrics"]


def test_gemini_predictive_strategy_evaluate():
    provider = MockMarketDataProvider()
    df = provider.get_historical_ohlcv("TCS")

    strategy = GeminiPredictiveAIStrategy()
    signal = strategy.evaluate(df, "TCS", "NSE", skip_ai=True)

    assert signal.symbol == "TCS"
    assert signal.strategy_name == "GeminiPredictiveAI"
    assert signal.signal_type in ("BUY", "BUY WATCH", "SELL", "SELL/EXIT WATCH", "HOLD", "NO TRADE")
    assert signal.price > 0
    assert signal.target is not None


def test_prediction_api_endpoints():
    # Test on-demand prediction endpoint
    res = client.post(
        "/api/v1/stocks/TCS/predict",
        json={"symbol": "TCS", "exchange": "NSE", "time_horizon": "1-DAY"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["symbol"] == "TCS"
    assert "predicted_direction" in data
    assert "target_price" in data
    assert "confidence_score" in data
    assert "working_algorithm" in data

    # Test get prediction
    get_res = client.get("/api/v1/stocks/TCS/prediction?exchange=NSE")
    assert get_res.status_code == 200
    assert get_res.json()["symbol"] == "TCS"

    # Test top predictions
    top_res = client.get("/api/v1/stocks/predictions/top?limit=5")
    assert top_res.status_code == 200
    assert isinstance(top_res.json(), list)
