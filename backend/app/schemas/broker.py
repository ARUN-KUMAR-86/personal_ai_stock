"""Broker synchronization schemas."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class BrokerAccountRead(BaseModel):
    id: int
    broker_name: str
    is_connected: bool
    available_funds: float
    unsettled_funds: float
    withdrawable_funds: float
    currency: str
    last_synced_at: Optional[datetime] = None
    error_message: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class BrokerSyncRequest(BaseModel):
    sync_positions: bool = True
    sync_funds: bool = True
