"""Scan job schemas."""

from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, ConfigDict


class ScanJobRead(BaseModel):
    id: int
    started_at: datetime
    finished_at: Optional[datetime] = None
    status: str
    total_stocks: int
    scanned_stocks: int
    passed_signals: int
    failed_stocks: int
    failed_symbols: Optional[List[Any]] = []
    error_details: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ScanTriggerRequest(BaseModel):
    force_rescan: bool = False
    symbols: Optional[List[str]] = None
    exchange: Optional[str] = "NSE"
