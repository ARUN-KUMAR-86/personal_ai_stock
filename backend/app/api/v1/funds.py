"""Trading funds and margin management endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.broker import BrokerAccount
from app.schemas.broker import BrokerAccountRead
from app.brokers.factory import get_broker_adapter

router = APIRouter(prefix="/funds", tags=["Trading Funds & Margins"])


@router.get("", response_model=BrokerAccountRead)
def get_funds(db: Session = Depends(get_db)):
    """Retrieves broker-reported trading funds and margin details."""
    broker_adapter = get_broker_adapter()
    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()

    if not account:
        funds_data = broker_adapter.get_funds()
        account = BrokerAccount(
            broker_name="GROWW",
            is_connected=funds_data["is_connected"],
            available_funds=funds_data["available_funds"],
            unsettled_funds=funds_data["unsettled_funds"],
            withdrawable_funds=funds_data["withdrawable_funds"],
            currency=funds_data["currency"],
            last_synced_at=funds_data["last_synced_at"],
            error_message=funds_data["error_message"],
        )
        db.add(account)
        db.commit()
        db.refresh(account)

    return account


@router.post("/sync", response_model=BrokerAccountRead)
def sync_funds(db: Session = Depends(get_db)):
    """Forces synchronization of funds and margins with the configured broker."""
    broker_adapter = get_broker_adapter()
    funds_data = broker_adapter.get_funds()

    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    if not account:
        account = BrokerAccount(broker_name="GROWW")
        db.add(account)

    account.is_connected = funds_data["is_connected"]
    account.available_funds = funds_data["available_funds"]
    account.unsettled_funds = funds_data["unsettled_funds"]
    account.withdrawable_funds = funds_data["withdrawable_funds"]
    account.currency = funds_data["currency"]
    account.last_synced_at = funds_data["last_synced_at"]
    account.error_message = funds_data["error_message"]

    db.commit()
    db.refresh(account)
    return account
