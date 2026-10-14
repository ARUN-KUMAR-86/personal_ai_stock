"""Application configuration and settings."""

import os
from typing import Any, List, Optional, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # App Settings
    APP_NAME: str = "Personal AI Stock Intelligence"
    API_V1_STR: str = "/api/v1"
    DEBUG: bool = False
    ENVIRONMENT: str = "production"

    # Security & Authentication
    SECRET_KEY: str = "change-me-to-a-secure-random-secret-key-32-chars-min"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    OWNER_USERNAME: str = "owner"
    OWNER_PASSWORD: str = "SecureOwnerPass123!"

    # Database
    DATABASE_URL: str = "sqlite:///./stock_intel.db"

    # Market Data
    MARKET_DATA_PROVIDER: str = "yahoo"  # "yahoo", "groww", "mock"
    DEFAULT_TIMEZONE: str = "Asia/Kolkata"
    MARKET_CURRENCY: str = "INR"
    NSE_MARKET_OPEN: str = "09:15"
    NSE_MARKET_CLOSE: str = "15:30"
    STALE_DATA_THRESHOLD_MINUTES: int = 30
    CACHE_EXPIRATION_SECONDS: int = 300  # 5 minutes for live quotes

    # Stock Scanner
    SCAN_INTERVAL_MINUTES: int = 15
    SCAN_BATCH_SIZE: int = 25
    AUTO_SCAN_ENABLED: bool = True
    SCAN_MARKET_HOURS_ONLY: bool = False  # Set false to allow off-hours scanning using latest close

    # Risk Management
    MAX_PORTFOLIO_EXPOSURE_PCT: float = 25.0
    MAX_SINGLE_STOCK_PCT: float = 10.0
    MAX_POSITION_RISK_PCT: float = 2.0
    MIN_RISK_REWARD_RATIO: float = 1.5
    FUNDS_LOW_THRESHOLD_INR: float = 10000.0

    # Trading Safety & Controls
    AUTO_SELL_ENABLED: bool = False  # Separate opt-in setting for automatic position exit
    EMERGENCY_STOP_ENABLED: bool = False  # Emergency control to immediately halt new trades
    MAX_SLIPPAGE_PCT: float = 1.0  # Slippage threshold requiring quote refresh before buy confirmation
    DEFAULT_HOLDING_PERIOD_HOURS: int = 48  # Default intended holding period: 24 or 48 hours
    POSITION_MONITOR_INTERVAL_SECONDS: int = 10
    ORDER_EXECUTION_MODE: str = "PAPER"  # "PAPER" or "GROWW_LIVE"

    # Groww API (Disabled for real execution by default)
    GROWW_API_AUTH_TOKEN: Optional[str] = None
    GROWW_API_KEY: Optional[str] = None
    GROWW_API_SECRET: Optional[str] = None
    GROWW_TOTP_KEY: Optional[str] = None
    GROWW_ORDER_EXECUTION_ENABLED: bool = False

    # Firebase Cloud Messaging
    FCM_SERVICE_ACCOUNT_PATH: Optional[str] = None
    FCM_SERVICE_ACCOUNT_JSON: Optional[str] = None
    NOTIFICATION_COOLDOWN_MINUTES: int = 60
    DEFAULT_FCM_DEVICE_TOKEN: Optional[str] = None

    # AI Analysis & Explainable Thesis Generator
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = "gemini-1.5-pro"
    AI_ANALYSIS_ENABLED: bool = True

    # CORS
    CORS_ORIGINS: Union[List[str], str] = ["*"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Any) -> List[str]:
        if isinstance(v, str):
            val = v.strip()
            if not val or val == "*":
                return ["*"]
            if val.startswith("[") and val.endswith("]"):
                try:
                    import json
                    parsed = json.loads(val)
                    if isinstance(parsed, list):
                        return [str(item).strip() for item in parsed]
                except Exception:
                    pass
            return [item.strip() for item in val.split(",") if item.strip()]
        elif isinstance(v, list):
            return [str(item).strip() for item in v]
        return ["*"]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
