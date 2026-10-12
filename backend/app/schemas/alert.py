"""Alert schemas."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class AlertRead(BaseModel):
    id: int
    symbol: str
    exchange: str
    alert_type: str
    title: str
    message: str
    signal_id: Optional[int] = None
    price: Optional[float] = None
    is_read: bool
    sent_to_fcm: bool
    fcm_message_id: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AlertMarkReadRequest(BaseModel):
    alert_ids: list[int]


class NotificationTestRequest(BaseModel):
    title: str = "PERSONAL AI STOCK ALERT [TEST]"
    body: str = "Test notification from Personal AI Stock Intelligence Backend"
    symbol: str = "RELIANCE"
    exchange: str = "NSE"
    device_token: Optional[str] = None


class DeviceTokenCreate(BaseModel):
    token: str
    device_name: Optional[str] = "Android Phone"


class DeviceTokenRead(BaseModel):
    id: int
    token: str
    device_name: Optional[str] = None
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
