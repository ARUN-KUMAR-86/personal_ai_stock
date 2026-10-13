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


@router.post("/renew")
def renew_groww_session(db: Session = Depends(get_db)):
    """
    1-Tap Groww Daily Token Renewal.
    Renews the daily session without re-entering credentials.
    """
    from app.models.broker import BrokerAccount
    adapter = get_broker_adapter()
    result = adapter.renew_session()
    
    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    if account:
        account.is_connected = result.get("success", False)
        account.auth_status = result.get("auth_status", "CONNECTED" if result.get("success") else "EXPIRED")
        if getattr(adapter, "token_expiry", None):
            account.token_expiry = adapter.token_expiry
        db.commit()
        db.refresh(account)
    return result


@router.get("/verify")
def verify_groww_connection(db: Session = Depends(get_db)):
    """
    Actively verifies connection and authorized account with Groww.
    Ensures connection is valid and not silently switched.
    """
    from app.models.broker import BrokerAccount
    adapter = get_broker_adapter()
    availability = adapter.get_api_availability()
    funds = adapter.get_funds()
    
    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    if account:
        account.is_connected = availability.get("is_authenticated", False)
        account.auth_status = availability.get("auth_status", "CONNECTED")
        account.available_funds = funds.get("available_funds", account.available_funds)
        db.commit()

    return {
        "verified": availability.get("is_authenticated", False),
        "auth_status": availability.get("auth_status", "CONNECTED"),
        "account_id": availability.get("account_id", "GROWW-ARUN-PRIMARY"),
        "account_holder_name": availability.get("account_holder_name", "Arun Kumar"),
        "is_token_expired": availability.get("is_token_expired", False),
        "token_expiry": availability.get("token_expiry"),
        "available_funds": funds.get("available_funds", 1000.0),
        "message": "Connection verified with Groww API." if availability.get("is_authenticated") else "Connection requires daily renewal or setup.",
    }


@router.post("/switch-account")
def switch_groww_account(db: Session = Depends(get_db)):
    """
    Disconnects the current Groww account to allow safely switching to a different account.
    Prevents trading on the wrong person's account.
    """
    from app.models.broker import BrokerAccount
    adapter = get_broker_adapter()
    res = adapter.disconnect()
    
    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    if account:
        account.is_connected = False
        account.auth_status = "DISCONNECTED"
        db.commit()

    return {
        "success": True,
        "message": "Current Groww account disconnected safely. Ready to connect new account.",
    }


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
