"""APScheduler background job scheduler for recurring market scanning."""

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from app.core.config import settings
from app.core.logging import logger
from app.database.session import SessionLocal
from app.scanner.engine import scanner_engine

scheduler = BackgroundScheduler()


def _scheduled_scan_job():
    """Worker function executed by APScheduler on periodic intervals."""
    logger.info("Executing scheduled market scan...")
    db = SessionLocal()
    try:
        scanner_engine.run_scan(db=db, exchange="NSE")
    except Exception as e:
        logger.error(f"Scheduled scan failed with exception: {e}")
    finally:
        db.close()


def start_scheduler():
    """Starts the background scanning scheduler if auto-scan is enabled."""
    if not settings.AUTO_SCAN_ENABLED:
        logger.info("Auto-scanning is disabled via settings.")
        return

    if not scheduler.running:
        scheduler.add_job(
            _scheduled_scan_job,
            trigger=IntervalTrigger(minutes=settings.SCAN_INTERVAL_MINUTES),
            id="recurring_market_scan",
            name="Recurring Market Scan",
            replace_existing=True,
        )
        scheduler.start()
        logger.info(f"Background scanner scheduled every {settings.SCAN_INTERVAL_MINUTES} minutes.")


def shutdown_scheduler():
    """Gracefully shuts down scheduler."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Background scanner scheduler shut down.")
