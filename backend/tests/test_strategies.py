"""Unit tests for Strategy evaluation and signal generation."""

import pandas as pd
from app.strategies.momentum_breakout import MomentumBreakoutStrategy
from app.strategies.mean_reversion import MeanReversionStrategy
from app.strategies.macd_crossover import MacdCrossStrategy
from app.providers.mock_provider import MockMarketDataProvider


def test_momentum_breakout_strategy():
    provider = MockMarketDataProvider()
    df = provider.get_historical_ohlcv("RELIANCE")

    strategy = MomentumBreakoutStrategy()
    signal = strategy.evaluate(df, "RELIANCE", "NSE")

    assert signal.symbol == "RELIANCE"
    assert signal.exchange == "NSE"
    assert signal.signal_type in ("BUY WATCH", "HOLD", "SELL/EXIT WATCH", "NO TRADE")
    assert signal.strategy_name == "MomentumBreakout"
    assert signal.strength >= 0.0 and signal.strength <= 100.0
    assert signal.explanation is not None
    if signal.signal_type == "BUY WATCH":
        assert signal.stop_loss is not None
        assert signal.target is not None
        assert signal.stop_loss < signal.price < signal.target
        assert signal.risk_reward is not None and signal.risk_reward > 0


def test_mean_reversion_strategy():
    provider = MockMarketDataProvider()
    df = provider.get_historical_ohlcv("TCS")

    strategy = MeanReversionStrategy()
    signal = strategy.evaluate(df, "TCS", "NSE")

    assert signal.symbol == "TCS"
    assert signal.strategy_name == "MeanReversionPullback"
    assert signal.signal_type in ("BUY WATCH", "HOLD", "SELL/EXIT WATCH", "NO TRADE")


def test_macd_crossover_strategy():
    provider = MockMarketDataProvider()
    df = provider.get_historical_ohlcv("INFY")

    strategy = MacdCrossStrategy()
    signal = strategy.evaluate(df, "INFY", "NSE")

    assert signal.symbol == "INFY"
    assert signal.strategy_name == "MacdCross"
    assert signal.signal_type in ("BUY WATCH", "HOLD", "SELL/EXIT WATCH", "NO TRADE")
