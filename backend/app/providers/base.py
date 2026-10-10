"""Abstract Base Class for Market Data Providers."""

from abc import ABC, abstractmethod
from datetime import datetime, timezone, time
from typing import List, Optional, Dict, Any
import zoneinfo
import pandas as pd
from app.schemas.candle import QuoteRead


class BaseMarketDataProvider(ABC):
    """Abstract interface defining required market data methods."""

    def __init__(self, name: str):
        self.name = name

    @abstractmethod
    def get_supported_universe(self, exchange: str = "NSE") -> List[Dict[str, Any]]:
        """Returns the list of stocks available on the given exchange."""
        pass

    @abstractmethod
    def get_quote(self, symbol: str, exchange: str = "NSE") -> QuoteRead:
        """Fetches the latest live or delayed quote for a given symbol."""
        pass

    @abstractmethod
    def get_historical_ohlcv(
        self,
        symbol: str,
        exchange: str = "NSE",
        timeframe: str = "1d",
        period: str = "1y",
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> pd.DataFrame:
        """
        Fetches historical OHLCV candles as a pandas DataFrame.
        Columns required: ['timestamp', 'open', 'high', 'low', 'close', 'volume'].
        """
        pass

    def get_market_status(self, exchange: str = "NSE") -> Dict[str, Any]:
        """
        Determines if the market is currently OPEN, CLOSED, or in PRE-MARKET.
        Indian Stock Market (NSE/BSE) trading hours:
        Pre-market: 09:00 - 09:15 IST
        Normal trading: 09:15 - 15:30 IST (Monday - Friday)
        """
        try:
            tz = zoneinfo.ZoneInfo("Asia/Kolkata")
        except Exception:
            tz = timezone.utc

        now_ist = datetime.now(tz)
        weekday = now_ist.weekday()  # 0 is Monday, 6 is Sunday

        is_weekend = weekday >= 5
        curr_time = now_ist.time()

        pre_open_start = time(9, 0)
        market_open = time(9, 15)
        market_close = time(15, 30)

        if is_weekend:
            status = "CLOSED"
            reason = "Weekend"
        elif pre_open_start <= curr_time < market_open:
            status = "PRE_MARKET"
            reason = "Pre-market session"
        elif market_open <= curr_time <= market_close:
            status = "OPEN"
            reason = "Regular trading session"
        else:
            status = "CLOSED"
            reason = "Outside trading hours"

        return {
            "exchange": exchange,
            "status": status,
            "reason": reason,
            "server_time_ist": now_ist.strftime("%Y-%m-%d %H:%M:%S IST"),
            "is_open": status == "OPEN",
            "market_open_time": "09:15 IST",
            "market_close_time": "15:30 IST",
        }
