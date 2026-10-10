"""Mock Market Data Provider for offline testing and continuous integration."""

from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional
import numpy as np
import pandas as pd
from app.providers.base import BaseMarketDataProvider
from app.schemas.candle import QuoteRead

SAMPLE_UNIVERSE = [
    {"symbol": "RELIANCE", "name": "Reliance Industries Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "TCS", "name": "Tata Consultancy Services Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "HDFCBANK", "name": "HDFC Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "INFY", "name": "Infosys Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "ICICIBANK", "name": "ICICI Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "BHARTIARTL", "name": "Bharti Airtel Ltd", "exchange": "NSE", "sector": "Telecom"},
    {"symbol": "SBIN", "name": "State Bank of India", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "LICI", "name": "Life Insurance Corp of India", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "ITC", "name": "ITC Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "HINDUNILVR", "name": "Hindustan Unilever Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "LT", "name": "Larsen & Toubro Ltd", "exchange": "NSE", "sector": "Capital Goods"},
    {"symbol": "BAJFINANCE", "name": "Bajaj Finance Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "TATAMOTORS", "name": "Tata Motors Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "SUNPHARMA", "name": "Sun Pharmaceutical Industries", "exchange": "NSE", "sector": "Healthcare"},
    {"symbol": "MARUTI", "name": "Maruti Suzuki India Ltd", "exchange": "NSE", "sector": "Automobile"},
]


class MockMarketDataProvider(BaseMarketDataProvider):
    """Provides explicitly labeled test market data for development and tests."""

    def __init__(self):
        super().__init__(name="TEST_SIMULATED")

    def get_supported_universe(self, exchange: str = "NSE") -> List[Dict[str, Any]]:
        return [dict(s, exchange=exchange) for s in SAMPLE_UNIVERSE]

    def get_quote(self, symbol: str, exchange: str = "NSE") -> QuoteRead:
        base_prices = {
            "RELIANCE": 2980.50,
            "TCS": 4120.00,
            "HDFCBANK": 1640.25,
            "INFY": 1820.75,
            "TATAMOTORS": 980.50,
        }
        base_price = base_prices.get(symbol.upper(), 1500.0)
        now = datetime.now(timezone.utc)

        return QuoteRead(
            symbol=symbol.upper(),
            exchange=exchange,
            price=round(base_price, 2),
            change=round(base_price * 0.012, 2),
            percent_change=1.20,
            open=round(base_price * 0.995, 2),
            high=round(base_price * 1.015, 2),
            low=round(base_price * 0.992, 2),
            previous_close=round(base_price / 1.012, 2),
            volume=1250000.0,
            timestamp=now,
            is_live=False,
            is_delayed=False,
            data_source="TEST_SIMULATED",
        )

    def get_historical_ohlcv(
        self,
        symbol: str,
        exchange: str = "NSE",
        timeframe: str = "1d",
        period: str = "1y",
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> pd.DataFrame:
        np.random.seed(abs(hash(symbol)) % (2**32))
        days = 250
        dates = pd.date_range(end=datetime.now(timezone.utc), periods=days, freq="B")

        base_prices = {
            "RELIANCE": 2800.0,
            "TCS": 3900.0,
            "HDFCBANK": 1500.0,
            "INFY": 1650.0,
            "TATAMOTORS": 850.0,
        }
        start_price = base_prices.get(symbol.upper(), 1200.0)

        # Generate geometric brownian motion
        returns = np.random.normal(0.0008, 0.015, days)
        price_series = start_price * np.exp(np.cumsum(returns))

        open_p = price_series * (1 + np.random.normal(0, 0.005, days))
        high_p = np.maximum(open_p, price_series) * (1 + np.abs(np.random.normal(0, 0.008, days)))
        low_p = np.minimum(open_p, price_series) * (1 - np.abs(np.random.normal(0, 0.008, days)))
        close_p = price_series
        volume = np.random.uniform(500000, 3000000, days)

        df = pd.DataFrame(
            {
                "timestamp": dates,
                "open": np.round(open_p, 2),
                "high": np.round(high_p, 2),
                "low": np.round(low_p, 2),
                "close": np.round(close_p, 2),
                "volume": np.round(volume, 0),
            }
        )
        return df
