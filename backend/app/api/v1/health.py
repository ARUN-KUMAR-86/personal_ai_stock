"""System health check and market status endpoints."""

from fastapi import APIRouter
from app.core.config import settings
from app.providers.factory import get_market_data_provider

router = APIRouter(tags=["System & Market Status"])


@router.get("/health")
def health_check():
    """Health check endpoint confirming API service status and configured provider."""
    provider = get_market_data_provider()
    return {
        "status": "healthy",
        "app_name": settings.APP_NAME,
        "configured_provider": provider.name,
        "environment": settings.ENVIRONMENT,
        "auto_scan_enabled": settings.AUTO_SCAN_ENABLED,
    }


@router.get("/market-status")
def get_market_status(exchange: str = "NSE"):
    """Returns current trading session status (OPEN, CLOSED, PRE_MARKET) for the given exchange."""
    provider = get_market_data_provider()
    return provider.get_market_status(exchange=exchange)
