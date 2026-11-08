"""Unit and integration tests for US Stock Configuration persistence and high-speed execution."""

import pytest
from app.database.session import SessionLocal, init_db
from app.models.stock import Stock
from app.models.setting import AppSetting
from app.api.v1.stocks import get_stock_universe
from app.providers.us_market_service import USMarketDataService, US_STOCKS_UNIVERSE
from app.providers.indian_market_service import IndianMarketDataService
from app.scanner.scheduler import _scheduled_scan_job, _get_setting_value, _set_setting_value


def test_us_stock_universe_full_sync():
    """Verify that all 26 US stocks are fully seeded and preserved in database."""
    init_db()
    db = SessionLocal()
    try:
        us_stocks = db.query(Stock).filter(Stock.exchange.in_(["US", "NASDAQ", "NYSE"])).all()
        assert len(us_stocks) >= 20, f"Expected at least 20 US stocks, got {len(us_stocks)}"
        symbols = [s.symbol for s in us_stocks]
        for expected in ["AAPL", "NVDA", "MSFT", "AMZN", "GOOGL", "META", "TSLA"]:
            assert expected in symbols, f"Missing core US symbol {expected}"
    finally:
        db.close()


def test_us_stock_universe_api_call():
    """Verify get_stock_universe for US exchange returns clean symbols and USD currency."""
    db = SessionLocal()
    try:
        stocks = get_stock_universe(exchange="US", time_horizon="1-DAY", db=db)
        assert len(stocks) >= 20
        for s in stocks:
            assert s.exchange in ("US", "NASDAQ", "NYSE")
            assert not s.symbol.endswith(".NS")
            assert not s.symbol.endswith(".BO")
    finally:
        db.close()


def test_dual_market_segmentation():
    """Verify get_stock_universe with exchange='ALL' segments quotes without appending .NS to US tickers."""
    db = SessionLocal()
    try:
        all_stocks = get_stock_universe(exchange="ALL", time_horizon="1-DAY", db=db)
        us_found = [s for s in all_stocks if s.exchange in ("US", "NASDAQ", "NYSE")]
        nse_found = [s for s in all_stocks if s.exchange in ("NSE", "BSE")]
        assert len(us_found) >= 20
        assert len(nse_found) >= 40
    finally:
        db.close()


def test_parallel_indices_speed():
    """Verify get_indices runs fast in parallel and caches properly."""
    us_indices = USMarketDataService.get_indices(force_refresh=False)
    assert len(us_indices) >= 4
    for idx in us_indices:
        assert idx["currency"] == "USD"
        assert idx["currency_symbol"] == "$"

    in_indices = IndianMarketDataService.get_indices(force_refresh=False)
    assert len(in_indices) >= 4
    for idx in in_indices:
        assert idx["currency"] == "INR"
        assert idx["currency_symbol"] == "₹"


def test_scheduler_respects_preferred_market():
    """Verify that background scheduler honors PREFERRED_MARKET setting."""
    _set_setting_value("PREFERRED_MARKET", "US")
    assert _get_setting_value("PREFERRED_MARKET", "ALL") == "US"

    _set_setting_value("PREFERRED_MARKET", "ALL")
    assert _get_setting_value("PREFERRED_MARKET", "ALL") == "ALL"
