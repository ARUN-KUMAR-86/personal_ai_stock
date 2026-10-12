"""APScheduler background job scheduler for recurring market scanning."""

from typing import Optional
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from app.core.config import settings
from app.core.logging import logger
from app.database.session import SessionLocal
from app.scanner.engine import scanner_engine
from app.portfolio.monitor import PositionMonitor

scheduler = BackgroundScheduler()


def _get_setting_value(key: str, default: str) -> str:
    db = SessionLocal()
    try:
        from app.models.setting import AppSetting
        record = db.query(AppSetting).filter(AppSetting.key == key).first()
        if record:
            return record.value
    except Exception as e:
        logger.debug(f"Could not load setting {key}: {e}")
    finally:
        db.close()
    return default


def _set_setting_value(key: str, value: str):
    db = SessionLocal()
    try:
        from app.models.setting import AppSetting
        record = db.query(AppSetting).filter(AppSetting.key == key).first()
        if record:
            record.value = value
        else:
            record = AppSetting(key=key, value=value)
            db.add(record)
        db.commit()
    except Exception as e:
        logger.warning(f"Could not persist setting {key}={value}: {e}")
        db.rollback()
    finally:
        db.close()


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


def _scheduled_position_monitor_job():
    """Worker function executed by APScheduler to monitor open positions against SL/TP/deadline."""
    db = SessionLocal()
    try:
        PositionMonitor.check_and_update_positions(db=db)
    except Exception as e:
        logger.error(f"Position monitor job failed with exception: {e}")
    finally:
        db.close()


def is_auto_scan_active() -> bool:
    """Returns True if the recurring market scan job is active and scheduled."""
    if not scheduler.running:
        return False
    job = scheduler.get_job("recurring_market_scan")
    return job is not None and job.next_run_time is not None


def enable_auto_scan(interval_minutes: Optional[int] = None) -> dict:
    """Starts or updates recurring background market scanning."""
    interval = interval_minutes or settings.SCAN_INTERVAL_MINUTES
    if not scheduler.running:
        start_scheduler()

    scheduler.add_job(
        _scheduled_scan_job,
        trigger=IntervalTrigger(minutes=interval),
        id="recurring_market_scan",
        name="Recurring Market Scan",
        replace_existing=True,
    )
    _set_setting_value("auto_scan_enabled", "true")
    _set_setting_value("scan_interval_minutes", str(interval))

    job = scheduler.get_job("recurring_market_scan")
    next_run = job.next_run_time.isoformat() if (job and job.next_run_time) else None
    logger.info(f"Recurring market scan enabled: every {interval} mins. Next run: {next_run}")
    return {
        "status": "SCHEDULED",
        "auto_scan_active": True,
        "interval_minutes": interval,
        "next_run_time": next_run,
        "message": f"Automated analysis scheduled every {interval} minutes.",
    }


def disable_auto_scan() -> dict:
    """Stops the recurring background market scanning job."""
    if scheduler.running:
        job = scheduler.get_job("recurring_market_scan")
        if job:
            scheduler.remove_job("recurring_market_scan")
    _set_setting_value("auto_scan_enabled", "false")
    logger.info("Recurring market scan paused/disabled.")
    return {
        "status": "STOPPED",
        "auto_scan_active": False,
        "message": "Automated analysis schedule stopped.",
    }


def get_schedule_status() -> dict:
    """Returns current scheduler state, next run time, and interval."""
    is_active = False
    next_run = None
    interval_str = _get_setting_value("scan_interval_minutes", str(settings.SCAN_INTERVAL_MINUTES))
    try:
        interval = int(interval_str)
    except ValueError:
        interval = settings.SCAN_INTERVAL_MINUTES

    if scheduler.running:
        job = scheduler.get_job("recurring_market_scan")
        if job and job.next_run_time:
            is_active = True
            next_run = job.next_run_time.isoformat()

    return {
        "scheduler_running": scheduler.running,
        "auto_scan_active": is_active,
        "interval_minutes": interval,
        "next_run_time": next_run,
        "is_scanning": scanner_engine.is_scanning,
        "market_hours_only": settings.SCAN_MARKET_HOURS_ONLY,
    }


def start_scheduler():
    """Starts the background scanning and position monitoring scheduler."""
    if not scheduler.running:
        saved_auto = _get_setting_value("auto_scan_enabled", "true" if settings.AUTO_SCAN_ENABLED else "false")
        auto_enabled = saved_auto.lower() == "true"
        interval_str = _get_setting_value("scan_interval_minutes", str(settings.SCAN_INTERVAL_MINUTES))
        try:
            interval = int(interval_str)
        except ValueError:
            interval = settings.SCAN_INTERVAL_MINUTES

        if auto_enabled:
            scheduler.add_job(
                _scheduled_scan_job,
                trigger=IntervalTrigger(minutes=interval),
                id="recurring_market_scan",
                name="Recurring Market Scan",
                replace_existing=True,
            )
            logger.info(f"Background scanner scheduled every {interval} minutes.")

        # Position monitoring job
        scheduler.add_job(
            _scheduled_position_monitor_job,
            trigger=IntervalTrigger(seconds=settings.POSITION_MONITOR_INTERVAL_SECONDS),
            id="recurring_position_monitor",
            name="Recurring Position Monitor",
            replace_existing=True,
        )
        logger.info(f"Position monitor scheduled every {settings.POSITION_MONITOR_INTERVAL_SECONDS} seconds.")

        scheduler.start()


def shutdown_scheduler():
    """Gracefully shuts down scheduler."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Background scanner scheduler shut down.")
