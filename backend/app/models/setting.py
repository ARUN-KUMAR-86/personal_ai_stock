"""Application settings key-value persistence model."""

from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime
from app.database.base import Base


class AppSetting(Base):
    """Stores dynamic runtime configuration that survives server restarts."""
    __tablename__ = "app_settings"

    key = Column(String(100), primary_key=True, index=True)
    value = Column(String(500), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
