"""Groww broker integration endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.brokers.factory import get_broker_adapter
from app.schemas.broker import BrokerAccountRead

router = APIRouter(prefix="/groww", tags=["Groww Broker Integration"])


@router.get("/status")
def get_groww_status():
    """Returns official Groww API configuration and connectivity status."""
    adapter = get_broker_adapter()
    return {
        "broker": "GROWW",
        "is_configured": adapter.is_configured(),
        "order_execution_enabled": adapter.order_execution_enabled,
        "instructions": (
            "To connect Groww, set GROWW_API_AUTH_TOKEN or GROWW_API_KEY and GROWW_API_SECRET in backend/.env. "
            "For account security, real-money automated order execution is disabled by default."
        ),
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
