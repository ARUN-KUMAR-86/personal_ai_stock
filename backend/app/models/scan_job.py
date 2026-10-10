"""Scanner job tracking and historical run log."""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, Text, JSON
from app.database.base import Base


class ScanJob(Base):
    __tablename__ = "scan_jobs"

    id = Column(Integer, primary_key=True, index=True)
    started_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), index=True)
    finished_at = Column(DateTime, nullable=True)
    status = Column(String(20), nullable=False, default="RUNNING", index=True)  # RUNNING, COMPLETED, FAILED
    total_stocks = Column(Integer, default=0)
    scanned_stocks = Column(Integer, default=0)
    passed_signals = Column(Integer, default=0)
    failed_stocks = Column(Integer, default=0)
    failed_symbols = Column(JSON, default=list)
    error_details = Column(Text, nullable=True)
