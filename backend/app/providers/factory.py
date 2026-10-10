"""Market Data Provider Factory."""

from functools import lru_cache
from app.core.config import settings
from app.core.logging import logger
from app.providers.base import BaseMarketDataProvider
from app.providers.yahoo_provider import YahooMarketDataProvider
from app.providers.groww_provider import GrowwMarketDataProvider
from app.providers.mock_provider import MockMarketDataProvider


@lru_cache()
def get_market_data_provider() -> BaseMarketDataProvider:
    """Returns the singleton instance of the configured market data provider."""
    provider_name = settings.MARKET_DATA_PROVIDER.lower().strip()
    logger.info(f"Initializing market data provider: {provider_name}")

    if provider_name == "yahoo":
        return YahooMarketDataProvider()
    elif provider_name == "groww":
        provider = GrowwMarketDataProvider()
        if not provider.is_configured():
            logger.warning("Groww API not fully configured. Using Mock fallback for safety.")
            return MockMarketDataProvider()
        return provider
    elif provider_name in ("mock", "test", "simulated"):
        return MockMarketDataProvider()
    else:
        logger.warning(f"Unknown provider '{provider_name}'. Defaulting to YahooMarketDataProvider.")
        return YahooMarketDataProvider()
