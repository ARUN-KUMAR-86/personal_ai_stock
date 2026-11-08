"""Unit tests for Indian & US Stock Market Dual-Market System."""

import pytest
from app.providers.indian_market_service import IndianMarketDataService
from app.providers.us_market_service import USMarketDataService
from app.analysis.market_news_service import MarketSpecificNewsService
from app.analysis.complete_analyzer import CompleteStockAnalyzer


def test_indian_market_service_basics():
    status = IndianMarketDataService.get_market_session_status()
    assert status["market"] == "INDIA"
    assert status["currency"] == "INR"
    assert status["currency_symbol"] == "₹"
    assert "09:15" in status["market_open_time"]
    assert "15:30" in status["market_close_time"]

    universe = IndianMarketDataService.get_universe()
    assert len(universe) >= 20
    symbols = [s["symbol"] for s in universe]
    assert "RELIANCE" in symbols
    assert "TCS" in symbols
    assert "INFY" in symbols

    indices = IndianMarketDataService.get_indices()
    assert len(indices) >= 4
    idx_symbols = [i["symbol"] for i in indices]
    assert "^NSEI" in idx_symbols


def test_us_market_service_basics():
    status = USMarketDataService.get_market_session_status()
    assert status["market"] == "US"
    assert status["currency"] == "USD"
    assert status["currency_symbol"] == "$"
    assert "09:30" in status["market_open_time"]
    assert "16:00" in status["market_close_time"]

    universe = USMarketDataService.get_universe()
    assert len(universe) >= 20
    symbols = [s["symbol"] for s in universe]
    assert "AAPL" in symbols
    assert "NVDA" in symbols
    assert "TSLA" in symbols

    indices = USMarketDataService.get_indices()
    assert len(indices) >= 4
    idx_symbols = [i["symbol"] for i in indices]
    assert "^GSPC" in idx_symbols


def test_market_specific_macro_intelligence():
    india_macro = MarketSpecificNewsService.get_market_macro_intelligence("INDIA")
    assert "SEBI" in india_macro["regulatory_body"]
    assert "RBI" in india_macro["central_bank"]
    assert india_macro["currency"] == "INR (₹)"

    us_macro = MarketSpecificNewsService.get_market_macro_intelligence("US")
    assert "SEC" in us_macro["regulatory_body"]
    assert "Federal Reserve" in us_macro["central_bank"]
    assert us_macro["currency"] == "USD ($)"


def test_complete_stock_analyzer_indian_and_us():
    # 1. Test Indian stock
    res_in = CompleteStockAnalyzer.analyze_stock("RELIANCE", market="INDIA", exchange="NSE")
    assert res_in["symbol"] == "RELIANCE"
    assert res_in["market"] == "INDIA"
    assert res_in["currency"] == "INR"
    assert res_in["currency_symbol"] == "₹"
    assert res_in["current_price"] > 0
    assert "target_1" in res_in
    assert "target_2" in res_in
    assert "stop_loss" in res_in
    assert len(res_in["reasons_supporting_prediction"]) >= 5
    assert len(res_in["risk_factors"]) >= 3
    assert "invalidation_condition" in res_in
    assert "short_term_prediction" in res_in
    assert "medium_term_prediction" in res_in
    assert "long_term_outlook" in res_in

    # 2. Test US stock
    res_us = CompleteStockAnalyzer.analyze_stock("AAPL", market="US", exchange="NASDAQ")
    assert res_us["symbol"] == "AAPL"
    assert res_us["market"] == "US"
    assert res_us["currency"] == "USD"
    assert res_us["currency_symbol"] == "$"
    assert res_us["current_price"] > 0
    assert "target_1" in res_us
    assert "target_2" in res_us
    assert "stop_loss" in res_us
    assert len(res_us["reasons_supporting_prediction"]) >= 5
    assert len(res_us["risk_factors"]) >= 3
    assert "invalidation_condition" in res_us
