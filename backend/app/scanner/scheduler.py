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
        preferred = _get_setting_value("PREFERRED_MARKET", "ALL").upper()
        if preferred in ("US", "NASDAQ", "NYSE"):
            scan_exchange = "US"
        elif preferred in ("NSE", "BSE", "INDIA"):
            scan_exchange = "NSE"
        else:
            scan_exchange = "ALL"
        scanner_engine.run_scan(db=db, exchange=scan_exchange)
    except Exception as e:
        logger.error(f"Scheduled scan failed with exception: {e}")
    finally:
        db.close()


def _scheduled_realtime_market_monitor_job():
    """Worker function executed every 60 seconds for full-time 24/7 real-time market monitoring."""
    logger.debug("Executing 24/7 real-time market monitoring tick...")
    db = SessionLocal()
    try:
        from app.models.stock import Stock
        from app.models.watchlist import WatchlistItem
        from app.providers.factory import get_market_data_provider

        provider = get_market_data_provider()
        
        # Load stocks partitioned by exchange
        stocks_all = db.query(Stock).filter(Stock.is_active == True).all()
        nse_syms = [s.symbol for s in stocks_all if s.exchange.upper() in ("NSE", "BSE", "INDIA")]
        us_syms = [s.symbol for s in stocks_all if s.exchange.upper() in ("US", "NASDAQ", "NYSE")]
        
        # Also include any watchlist items
        watch_items = db.query(WatchlistItem).all()
        for w in watch_items:
            sym = w.symbol.upper()
            if any(s.symbol == sym and s.exchange.upper() in ("US", "NASDAQ", "NYSE") for s in stocks_all):
                if sym not in us_syms:
                    us_syms.append(sym)
            else:
                if sym not in nse_syms:
                    nse_syms.append(sym)

        if "RELIANCE" not in nse_syms:
            nse_syms.append("RELIANCE")

        # Fast parallel bulk quotes refresh for each respective market
        if nse_syms:
            provider.get_bulk_quotes(nse_syms[:25], exchange="NSE")
        if us_syms:
            provider.get_bulk_quotes(us_syms[:25], exchange="US")

        # Also trigger position monitor
        PositionMonitor.check_and_update_positions(db=db)
    except Exception as e:
        logger.warning(f"Real-time monitoring tick note: {e}")
    finally:
        db.close()


def _scheduled_position_monitor_job():
    """Worker function executed by APScheduler to monitor open positions against SL/TP/deadline and profit/loss thresholds."""
    db = SessionLocal()
    try:
        PositionMonitor.check_and_update_positions(db=db)
    except Exception as e:
        logger.error(f"Position monitor job failed with exception: {e}")
    finally:
        db.close()


def _scheduled_notification_retry_job():
    """Worker function executed by APScheduler to retry pending notifications in queue."""
    db = SessionLocal()
    try:
        from app.notifications.notifier import notifier
        notifier.process_notification_queue(db=db)
    except Exception as e:
        logger.debug(f"Notification queue processor note: {e}")
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

        # Full-time 24/7 real-time market monitor job
        scheduler.add_job(
            _scheduled_realtime_market_monitor_job,
            trigger=IntervalTrigger(seconds=60),
            id="realtime_fulltime_monitor",
            name="24/7 Real-Time Market Monitor",
            replace_existing=True,
        )
        logger.info("24/7 Real-Time Market Monitor scheduled every 60 seconds.")

        # Notification queue durable retry job
        scheduler.add_job(
            _scheduled_notification_retry_job,
            trigger=IntervalTrigger(seconds=30),
            id="recurring_notification_retry",
            name="Recurring Notification Queue Retry",
            replace_existing=True,
        )
        logger.info("Notification Queue Retry worker scheduled every 30 seconds.")

        scheduler.start()


def shutdown_scheduler():
    """Gracefully shuts down scheduler."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Background scanner scheduler shut down.")
