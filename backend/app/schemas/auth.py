"""Authentication and user schemas."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    username: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterDeviceTokenRequest(BaseModel):
    fcm_token: str


class UserRead(BaseModel):
    id: int
    username: str
    is_admin: bool
    fcm_token: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
