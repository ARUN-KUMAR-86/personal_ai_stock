"""Groww Trade API Market Data Provider."""

from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import pandas as pd
from app.core.config import settings
from app.core.logging import logger
from app.core.exceptions import MarketDataProviderError
from app.providers.base import BaseMarketDataProvider
from app.schemas.candle import QuoteRead


class GrowwMarketDataProvider(BaseMarketDataProvider):
    """
    Market Data Provider using Groww's official Trading API.
    Requires GROWW_API_AUTH_TOKEN or API Key & Secret configuration.
    """

    def __init__(self):
        super().__init__(name="GrowwTradeAPI")
        self.auth_token = settings.GROWW_API_AUTH_TOKEN
        self.api_key = settings.GROWW_API_KEY
        self.api_secret = settings.GROWW_API_SECRET
        self._client = None
        self._init_client()

    def _init_client(self):
        """Initializes GrowwAPI client if credentials are configured."""
        if self.auth_token or (self.api_key and self.api_secret):
            try:
                # Import growwapi if installed
                import importlib
                groww_module = importlib.import_module("growwapi")
                GrowwAPI = getattr(groww_module, "GrowwAPI")
                if self.auth_token:
                    self._client = GrowwAPI(API_AUTH_TOKEN=self.auth_token)
                else:
                    self._client = GrowwAPI(api_key=self.api_key, api_secret=self.api_secret)
                logger.info("Groww API client initialized successfully.")
            except ImportError:
                logger.warning("growwapi library not installed. Groww provider in fallback mode.")
            except Exception as e:
                logger.error(f"Failed to initialize Groww API client: {e}")

    def is_configured(self) -> bool:
        return self._client is not None

    def get_supported_universe(self, exchange: str = "NSE") -> List[Dict[str, Any]]:
        # Groww supports all NSE and BSE listed equities
        from app.providers.yahoo_provider import NIFTY_50_UNIVERSE
        return [dict(s, exchange=exchange) for s in NIFTY_50_UNIVERSE]

    def get_quote(self, symbol: str, exchange: str = "NSE") -> QuoteRead:
        if not self.is_configured():
            raise MarketDataProviderError(
                "Groww Trade API is not configured. Please supply GROWW_API_AUTH_TOKEN in .env or switch to 'yahoo'/'mock'."
            )
        try:
            groww_exchange = "NSE" if exchange.upper() == "NSE" else "BSE"
            response = self._client.get_quote(
                exchange=groww_exchange,
                segment="CASH",
                trading_symbol=symbol.upper(),
            )
            # Response parsing based on Groww Trade API documentation
            ltp = float(response.get("ltp", response.get("close", 0.0)))
            open_p = float(response.get("open", ltp))
            high_p = float(response.get("high", ltp))
            low_p = float(response.get("low", ltp))
            close_p = float(response.get("close", ltp))
            volume = float(response.get("volume", 0.0))
            change = float(response.get("change", ltp - close_p))
            pct_change = float(response.get("percent_change", (change / close_p * 100) if close_p else 0.0))

            return QuoteRead(
                symbol=symbol.upper(),
                exchange=exchange.upper(),
                price=round(ltp, 2),
                change=round(change, 2),
                percent_change=round(pct_change, 2),
                open=round(open_p, 2),
                high=round(high_p, 2),
                low=round(low_p, 2),
                previous_close=round(close_p, 2),
                volume=round(volume, 0),
                timestamp=datetime.now(timezone.utc),
                is_live=True,  # Groww Trade API gives live tick quotes to subscribers
                is_delayed=False,
                data_source="GrowwTradeAPI-Live",
            )
        except Exception as e:
            logger.error(f"Groww get_quote error for {symbol}: {e}")
            raise MarketDataProviderError(f"Groww quote retrieval failed for {symbol}: {str(e)}")

    def get_historical_ohlcv(
        self,
        symbol: str,
        exchange: str = "NSE",
        timeframe: str = "1d",
        period: str = "1y",
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> pd.DataFrame:
        if not self.is_configured():
            raise MarketDataProviderError(
                "Groww Trade API is not configured. Please supply GROWW_API_AUTH_TOKEN in .env."
            )
        try:
            # Call historical data endpoint
            response = self._client.get_historical_candles(
                exchange="NSE" if exchange.upper() == "NSE" else "BSE",
                segment="CASH",
                trading_symbol=symbol.upper(),
                start_time=start.strftime("%Y-%m-%d") if start else None,
                end_time=end.strftime("%Y-%m-%d") if end else None,
            )
            # Standardize to DataFrame
            candles = response.get("candles", [])
            df = pd.DataFrame(candles, columns=["timestamp", "open", "high", "low", "close", "volume"])
            df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
            return df
        except Exception as e:
            logger.error(f"Groww historical data error for {symbol}: {e}")
            raise MarketDataProviderError(f"Groww historical data failed for {symbol}: {str(e)}")
