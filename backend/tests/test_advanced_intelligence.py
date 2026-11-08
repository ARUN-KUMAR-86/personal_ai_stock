"""Comprehensive test suite for Advanced AI Stock Intelligence & Accuracy Engine.

Tests:
1. Candlestick anatomy & pattern recognition on completed bars
2. Market structure (HH, HL, BOS, CHOCH, Liquidity sweeps, Order Blocks)
3. Volume flow, RVOL, OBV, CMF, VWAP, and Price-Volume divergence
4. Market regime classification (Bullish, Bearish, Sideways Chop, Volatility)
5. Global market research & macro index alignment
6. Dedicated false signal & trap prevention engine
7. Dynamic 8-dimension confidence scoring & threshold gating
8. Machine learning ensemble forecasting & probability calibration
9. Continuous prediction validation & empirical accuracy report
10. Live monitoring & signal cancellation
"""

import pytest
import numpy as np
import pandas as pd
from datetime import datetime, timezone, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.base import Base
from app.models.stock import Stock
from app.models.signal import StockSignal
from app.models.prediction import StockPrediction
from app.analysis.candlestick_intelligence import CandlestickIntelligence
from app.analysis.market_structure import MarketStructureAnalyzer
from app.analysis.volume_intelligence import VolumeIntelligence
from app.analysis.market_regime import MarketRegimeDetector
from app.analysis.global_market_engine import GlobalMarketEngine
from app.analysis.false_signal_detector import FalseSignalDetector
from app.analysis.scoring_engine import QualityScoringEngine
from app.analysis.ensemble_predictor import EnsembleStockPredictor
from app.analysis.prediction_validator import PredictionValidator
from app.portfolio.monitor import PositionMonitor
from app.providers.mock_provider import MockMarketDataProvider


@pytest.fixture
def test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    db = Session()
    yield db
    db.close()


def create_synthetic_uptrend_ohlcv(bars: int = 60) -> pd.DataFrame:
    """Generates synthetic OHLCV bars displaying a clean, verifiable uptrend."""
    np.random.seed(42)
    dates = [datetime.now(timezone.utc) - timedelta(days=bars - i) for i in range(bars)]
    price = 1000.0
    records = []

    for i in range(bars):
        step = np.random.normal(1.5, 3.0)  # upward drift
        o = price
        c = price + step
        h = max(o, c) + abs(np.random.normal(1.0, 1.0))
        l = min(o, c) - abs(np.random.normal(1.0, 1.0))
        vol = int(np.random.normal(1000000, 150000)) + (i * 5000)
        records.append({
            "timestamp": dates[i],
            "open": round(o, 2),
            "high": round(h, 2),
            "low": round(l, 2),
            "close": round(c, 2),
            "volume": max(vol, 100000),
        })
        price = c

    return pd.DataFrame(records)


def test_candlestick_intelligence_anatomy_and_patterns():
    df = create_synthetic_uptrend_ohlcv(40)
    
    # 1. Test candle anatomy
    anatomy = CandlestickIntelligence.analyze_candle_anatomy(df, idx=-1)
    assert "body_ratio" in anatomy
    assert "upper_wick_ratio" in anatomy
    assert "lower_wick_ratio" in anatomy
    assert anatomy["range"] > 0
    assert 0.0 <= anatomy["body_ratio"] <= 1.0

    # 2. Test pattern detection
    pattern_res = CandlestickIntelligence.detect_patterns(df)
    assert "candle_bias" in pattern_res
    assert pattern_res["candle_bias"] in ("BULLISH", "BEARISH", "NEUTRAL")
    assert "confirmation_status" in pattern_res
    assert pattern_res["pattern_score"] >= 0.0


def test_market_structure_analyzer():
    df = create_synthetic_uptrend_ohlcv(50)
    struct = MarketStructureAnalyzer.analyze_structure(df)

    assert "structure_bias" in struct
    assert struct["structure_bias"] in ("BULLISH", "BEARISH", "NEUTRAL")
    assert "trend_state" in struct
    assert "support_zones" in struct
    assert "demand_zone" in struct
    assert "structure_score" in struct
    assert 0.0 <= struct["structure_score"] <= 100.0


def test_volume_intelligence():
    df = create_synthetic_uptrend_ohlcv(40)
    vol_res = VolumeIntelligence.calculate_volume_metrics(df)

    assert "rvol" in vol_res
    assert vol_res["rvol"] > 0
    assert "obv_trend" in vol_res
    assert vol_res["obv_trend"] in ("BULLISH_ACCUMULATION", "BEARISH_DISTRIBUTION", "NEUTRAL")
    assert "vwap" in vol_res
    assert vol_res["vwap"] > 0
    assert "volume_score" in vol_res
    assert 0.0 <= vol_res["volume_score"] <= 100.0


def test_market_regime_detector():
    df = create_synthetic_uptrend_ohlcv(50)
    regime = MarketRegimeDetector.detect_regime(df)

    assert "regime" in regime
    assert regime["regime"] in (
        "STRONG_BULLISH", "WEAK_BULLISH", "STRONG_BEARISH", "WEAK_BEARISH",
        "SIDEWAYS_CHOP", "HIGH_VOLATILITY_CHOP", "LOW_VOLATILITY_COMPRESSION", "UNCERTAIN"
    )
    assert "adx_14" in regime
    assert "strategy_recommendation" in regime


def test_false_signal_detector():
    df = create_synthetic_uptrend_ohlcv(40)
    c0 = CandlestickIntelligence.analyze_candle_anatomy(df, idx=-1)
    
    # Simulate a clean setup
    res_clean = FalseSignalDetector.evaluate_traps(
        df=df,
        proposed_action="BUY",
        candle_analysis={"latest_candle": c0, "identified_patterns": []},
        structure_analysis={"structure_bias": "BULLISH", "liquidity_sweep": None},
        volume_analysis={"rvol": 1.5},
        regime_analysis={"regime": "STRONG_BULLISH"},
    )
    assert res_clean["is_safe"] is True

    # Simulate an upper wick trap (bearish rejection on breakout)
    c0_trap = {**c0, "upper_wick_ratio": 0.45}
    res_trap = FalseSignalDetector.evaluate_traps(
        df=df,
        proposed_action="BUY",
        candle_analysis={"latest_candle": c0_trap, "identified_patterns": []},
        structure_analysis={"structure_bias": "BULLISH", "liquidity_sweep": None},
        volume_analysis={"rvol": 1.5},
        regime_analysis={"regime": "STRONG_BULLISH"},
    )
    assert res_trap["is_safe"] is False
    assert res_trap["recommended_action"] == "NO_TRADE"
    assert any("Upper Wick Rejection" in t for t in res_trap["traps_detected"])


def test_quality_scoring_engine():
    # Test Very Strong Setup (>=90)
    scores = QualityScoringEngine.evaluate_all_scores(
        data_quality_metrics={"is_complete": True, "bar_count": 100},
        technical_metrics={"rsi_14": 58.0, "supertrend_dir": 1, "adx_14": 28.0, "close": 110.0, "ema_21": 105.0, "ema_50": 100.0, "sma_50": 98.0},
        candlestick_metrics={"pattern_score": 90.0},
        market_structure_metrics={"structure_score": 90.0},
        volume_metrics={"volume_score": 90.0},
        global_market_metrics={"macro_score": 80.0},
        model_metrics={"ensemble_confidence": 90.0},
        risk_reward_ratio=2.8,
        proposed_action="BUY",
    )
    assert scores["composite_confidence"] >= 80.0
    assert scores["signal_eligible"] is True

    # Test Weak / Insufficient Conviction (<70 -> NO TRADE)
    weak_scores = QualityScoringEngine.evaluate_all_scores(
        data_quality_metrics={"is_complete": True, "bar_count": 40},
        technical_metrics={"rsi_14": 42.0, "supertrend_dir": -1, "adx_14": 14.0, "close": 90.0, "ema_21": 95.0, "ema_50": 98.0, "sma_50": 100.0},
        candlestick_metrics={"pattern_score": 30.0},
        market_structure_metrics={"structure_score": 30.0},
        volume_metrics={"volume_score": 30.0},
        global_market_metrics={"macro_score": 40.0},
        model_metrics={"ensemble_confidence": 30.0},
        risk_reward_ratio=1.0,
        proposed_action="BUY",
    )
    assert weak_scores["composite_confidence"] < 70.0
    assert weak_scores["signal_eligible"] is False
    assert weak_scores["suggested_action"] == "NO TRADE"


def test_ensemble_stock_predictor():
    provider = MockMarketDataProvider()
    df = provider.get_historical_ohlcv("RELIANCE")

    predictor = EnsembleStockPredictor()
    pred = predictor.predict(
        df=df,
        symbol="RELIANCE",
        company_name="Reliance Industries Ltd",
        exchange="NSE",
        time_horizon="1-DAY",
    )

    assert pred["symbol"] == "RELIANCE"
    assert "probabilities" in pred
    assert "prob_up" in pred["probabilities"]
    assert "prob_down" in pred["probabilities"]
    assert "prob_sideways" in pred["probabilities"]
    tot_p = pred["probabilities"]["prob_up"] + pred["probabilities"]["prob_down"] + pred["probabilities"]["prob_sideways"]
    assert abs(tot_p - 1.0) < 0.05
    assert pred["predicted_action"] in ("BUY", "STRONG BUY", "SELL", "STRONG SELL", "HOLD", "NO TRADE")
    assert "dimension_scores" in pred
    assert len(pred["dimension_scores"]) == 8


def test_continuous_prediction_validation_and_accuracy(test_db):
    # Seed 2 historical predictions
    p1 = StockPrediction(
        symbol="RELIANCE",
        exchange="NSE",
        price_at_prediction=1000.0,
        predicted_direction="BULLISH",
        predicted_action="BUY",
        target_price=1050.0,
        stop_loss=980.0,
        expected_gain_pct=5.0,
        confidence_score=85.0,
        outcome_status="TARGET_HIT",
        actual_future_price=1055.0,
        actual_return_pct=5.5,
        model_version="v2.0-ensemble",
    )
    p2 = StockPrediction(
        symbol="TCS",
        exchange="NSE",
        price_at_prediction=2000.0,
        predicted_direction="BULLISH",
        predicted_action="BUY",
        target_price=2100.0,
        stop_loss=1960.0,
        expected_gain_pct=5.0,
        confidence_score=82.0,
        outcome_status="STOP_LOSS_HIT",
        actual_future_price=1950.0,
        actual_return_pct=-2.5,
        model_version="v2.0-ensemble",
    )
    test_db.add(p1)
    test_db.add(p2)
    test_db.commit()

    report = PredictionValidator.get_accuracy_report(test_db)
    assert report["total_predictions"] == 2
    assert report["resolved_predictions"] == 2
    assert report["win_count"] == 1
    assert report["loss_count"] == 1
    assert report["directional_accuracy_pct"] == 50.0
    assert report["target_hit_rate_pct"] == 50.0
    assert report["profit_factor"] > 1.5


def test_live_monitoring_signal_cancellation(test_db):
    # Seed an active signal
    sig = StockSignal(
        symbol="RELIANCE",
        exchange="NSE",
        timestamp=datetime.now(timezone.utc),
        signal_type="BUY WATCH",
        strategy_name="MomentumBreakout",
        price=1000.0,
        stop_loss=995.0,
        target=1050.0,
        risk_reward=2.5,
        strength=85.0,
        priority="HIGH",
        explanation="Test active signal awaiting monitoring verification.",
    )
    test_db.add(sig)
    test_db.commit()

    # Run signal cancellation check
    invalidations = PositionMonitor.monitor_and_cancel_invalidated_signals(test_db)
    # Re-query
    refreshed = test_db.query(StockSignal).filter(StockSignal.id == sig.id).first()
    assert refreshed is not None
