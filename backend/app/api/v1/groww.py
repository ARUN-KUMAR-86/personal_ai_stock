"""Groww broker integration endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.brokers.factory import get_broker_adapter
from app.schemas.broker import BrokerAccountRead, GrowwLoginRequest

router = APIRouter(prefix="/groww", tags=["Groww Broker Integration"])


@router.get("/status")
def get_groww_status():
    """Returns official Groww API configuration and connectivity status."""
    adapter = get_broker_adapter()
    return adapter.get_api_availability()


@router.post("/login")
def login_groww(request: GrowwLoginRequest):
    """
    In-App Groww Broker Login & Session Initialization.
    Accepts API Key, Secret, and TOTP key directly from personal app,
    verifies TOTP generation, validates session, and saves credentials securely.
    """
    adapter = get_broker_adapter()
    return adapter.update_credentials(
        api_key=request.api_key,
        api_secret=request.api_secret,
        totp_key=request.totp_key,
        auth_token=request.auth_token,
        order_execution_enabled=request.order_execution_enabled,
    )


@router.post("/logout")
def logout_groww():
    """Disconnects Groww session and reverts to simulated paper trading."""
    adapter = get_broker_adapter()
    return adapter.disconnect()


@router.post("/auth/refresh")
def refresh_groww_auth():
    """Refreshes or authenticates Groww session using TOTP."""
    adapter = get_broker_adapter()
    success = adapter.authenticate()
    return {
        "broker": "GROWW",
        "authenticated": success,
        "token_expiry": adapter.token_expiry.isoformat() if getattr(adapter, "token_expiry", None) else None,
        "message": "Groww session authenticated via TOTP flow." if success else "Authentication failed. Check credentials in backend/.env.",
    }


@router.get("/margin")
def get_groww_margin():
    """Fetches real-time margin and limits from Groww."""
    adapter = get_broker_adapter()
    return adapter.get_funds()


@router.get("/positions")
def get_groww_positions():
    """Fetches real-time positions from Groww."""
    adapter = get_broker_adapter()
    return adapter.get_positions()


@router.get("/holdings")
def get_groww_holdings():
    """Fetches real-time demat holdings from Groww."""
    adapter = get_broker_adapter()
    return adapter.get_holdings()


@router.get("/orders/{order_id}")
def verify_groww_order_status(order_id: str):
    """Verifies actual order status on Groww."""
    adapter = get_broker_adapter()
    return adapter.get_order_status(order_id=order_id)
