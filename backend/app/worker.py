"""Standalone Cloud Background Worker Daemon for 24/7 Market & Portfolio Monitoring."""

import os
import sys
import time
import signal
from pathlib import Path
from datetime import datetime, timezone

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.core.config import settings
from app.core.logging import logger
from app.database.session import init_db, SessionLocal
from app.scanner.scheduler import start_scheduler, shutdown_scheduler, scheduler
from app.portfolio.monitor import PositionMonitor
from app.providers.factory import get_market_data_provider

_running = True


def handle_shutdown(signum, frame):
    global _running
    logger.info(f"Worker received signal {signum}. Initiating graceful shutdown...")
    _running = False
    shutdown_scheduler()
    sys.exit(0)


def run_cloud_worker():
    """
    Independent 24/7 Cloud Background Worker.
    Continues continuous portfolio threshold monitoring, market scans,
    and notification retries even when laptop is closed or browser is offline.
    """
    logger.info("=======================================================")
    logger.info("   STARTING ZED 24/7 CLOUD MONITORING WORKER DAEMON    ")
    logger.info("=======================================================")

    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    # 1. Initialize Database & Migrations
    init_db()

    # 2. Start APScheduler Background Jobs
    start_scheduler()

    provider = get_market_data_provider()
    last_health_check = 0.0

    logger.info("24/7 Cloud Worker is actively monitoring positions and market...")

    while _running:
        try:
            now = time.time()
            # Periodic health heartbeat every 5 minutes
            if now - last_health_check >= 300.0:
                last_health_check = now
                db = SessionLocal()
                try:
                    from app.models.portfolio import Position
                    active_count = db.query(Position).filter(Position.is_open == True).count()
                    market_info = provider.get_market_status(exchange="NSE")
                    logger.info(
                        f"Worker Heartbeat: Active Positions={active_count}, "
                        f"Market Open={market_info.get('is_open')}, "
                        f"Scheduler Jobs={len(scheduler.get_jobs())}"
                    )
                finally:
                    db.close()

            time.sleep(5.0)

        except Exception as e:
            logger.error(f"Unexpected error in cloud worker main loop: {e}. Auto-recovering...")
            time.sleep(5.0)


if __name__ == "__main__":
    run_cloud_worker()
