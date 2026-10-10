"""Custom exception classes for stock intelligence system."""

class StockIntelException(Exception):
    """Base exception for application errors."""
    pass


class MarketDataProviderError(StockIntelException):
    """Raised when market data retrieval fails."""
    pass


class RateLimitExceededError(MarketDataProviderError):
    """Raised when market data provider rate limits are hit."""
    pass


class StaleDataError(MarketDataProviderError):
    """Raised when retrieved data is outdated beyond allowable threshold."""
    pass


class BrokerIntegrationError(StockIntelException):
    """Raised when broker communication fails."""
    pass


class RiskCheckFailedError(StockIntelException):
    """Raised when trade violates portfolio risk parameters."""
    pass
