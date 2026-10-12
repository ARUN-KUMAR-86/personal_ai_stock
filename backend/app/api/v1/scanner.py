"""Stock scanner trigger and monitoring endpoints."""

from typing import List
from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.orm import Session

from app.database.session import get_db, SessionLocal
from app.models.scan_job import ScanJob
from app.schemas.scan import ScanJobRead, ScanTriggerRequest
from app.scanner.engine import scanner_engine

router = APIRouter(prefix="/scanner", tags=["Stock Scanner"])


def _background_scan_task(symbols: list, exchange: str, force: bool):
    db = SessionLocal()
    try:
        scanner_engine.run_scan(db=db, symbols=symbols, exchange=exchange, force=force)
    finally:
        db.close()


@router.post("/scan")
def trigger_scan(
    request: ScanTriggerRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """Triggers an automatic scan over supported stocks."""
    if scanner_engine.is_scanning:
        return {"message": "A scan is already in progress.", "status": "RUNNING"}

    background_tasks.add_task(
        _background_scan_task,
        symbols=request.symbols,
        exchange=request.exchange or "NSE",
        force=request.force_rescan,
    )
    return {"message": "Stock scan initiated in background.", "status": "STARTED"}


@router.get("/status")
def get_scanner_status(db: Session = Depends(get_db)):
    """Returns the current status of the scanner engine and latest job details."""
    latest_job = db.query(ScanJob).order_by(ScanJob.id.desc()).first()
    return {
        "is_scanning": scanner_engine.is_scanning,
        "latest_job": latest_job,
    }


@router.get("/jobs", response_model=List[ScanJobRead])
def get_scan_jobs(limit: int = 10, db: Session = Depends(get_db)):
    """Lists past scanner jobs and results."""
    return db.query(ScanJob).order_by(ScanJob.id.desc()).limit(limit).all()


@router.get("/schedule/status")
def get_schedule_status_endpoint():
    """Returns recurring automated analysis scheduler status."""
    from app.scanner.scheduler import get_schedule_status
    return get_schedule_status()


@router.post("/schedule/start")
def start_schedule_endpoint(interval_minutes: int = 15):
    """Enables or updates the automated market analysis schedule."""
    from app.scanner.scheduler import enable_auto_scan
    return enable_auto_scan(interval_minutes=interval_minutes)


@router.post("/schedule/stop")
def stop_schedule_endpoint():
    """Pauses or stops the automated market analysis schedule."""
    from app.scanner.scheduler import disable_auto_scan
    return disable_auto_scan()

