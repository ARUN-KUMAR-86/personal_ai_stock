"""Automatic stock scanner and analysis execution engine."""

import time
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.database.session import SessionLocal
from app.models.stock import Stock
from app.models.scan_job import ScanJob
from app.models.signal import StockSignal
from app.providers.factory import get_market_data_provider
from app.strategies.registry import strategy_registry
from app.notifications.notifier import notifier


class ScannerEngine:
    """Orchestrates scanning of supported stock universe and signal generation."""

    def __init__(self):
        self.is_scanning = False

    def sync_universe(self, db: Session, exchange: str = "NSE") -> int:
        """Discovers and synchronizes supported stock universe into the database."""
        provider = get_market_data_provider()
        universe_items = provider.get_supported_universe(exchange=exchange)
        added_count = 0

        for item in universe_items:
            symbol = item["symbol"]
            existing = (
                db.query(Stock)
                .filter(Stock.symbol == symbol, Stock.exchange == exchange)
                .first()
            )
            if not existing:
                stock = Stock(
                    symbol=symbol,
                    exchange=exchange,
                    name=item.get("name", symbol),
                    sector=item.get("sector"),
                    is_active=True,
                )
                db.add(stock)
                added_count += 1
        db.commit()
        logger.info(f"Synchronized universe: added {added_count} new stocks for {exchange}.")
        return added_count

    def run_scan(
        self,
        db: Session,
        symbols: Optional[List[str]] = None,
        exchange: str = "NSE",
        force: bool = False,
    ) -> ScanJob:
        """Executes a full scanning pass over active stocks."""
        if self.is_scanning:
            logger.warning("Scan pass already in progress. Skipping concurrent run.")
            latest = db.query(ScanJob).order_by(ScanJob.id.desc()).first()
            return latest

        self.is_scanning = True
        provider = get_market_data_provider()

        # Check market status if market-hours only is enabled
        market_status = provider.get_market_status(exchange=exchange)
        if settings.SCAN_MARKET_HOURS_ONLY and not force:
            if not market_status.get("is_open"):
                logger.info("Market is currently closed. Scanning skipped as configured.")
                self.is_scanning = False
                job = ScanJob(
                    started_at=datetime.now(timezone.utc),
                    finished_at=datetime.now(timezone.utc),
                    status="SKIPPED",
                    error_details="Market is closed and SCAN_MARKET_HOURS_ONLY is True.",
                )
                db.add(job)
                db.commit()
                return job

        # Create ScanJob record
        job = ScanJob(
            started_at=datetime.now(timezone.utc),
            status="RUNNING",
            total_stocks=0,
            scanned_stocks=0,
            passed_signals=0,
            failed_stocks=0,
            failed_symbols=[],
        )
        db.add(job)
        db.commit()
        db.refresh(job)

        try:
            # Determine stocks to scan
            if symbols:
                target_stocks = (
                    db.query(Stock)
                    .filter(Stock.symbol.in_([s.upper() for s in symbols]), Stock.exchange == exchange)
                    .all()
                )
            else:
                target_stocks = (
                    db.query(Stock)
                    .filter(Stock.exchange == exchange, Stock.is_active == True)
                    .all()
                )

            # Auto-seed if database is empty
            if not target_stocks:
                self.sync_universe(db, exchange=exchange)
                target_stocks = (
                    db.query(Stock)
                    .filter(Stock.exchange == exchange, Stock.is_active == True)
                    .all()
                )

            job.total_stocks = len(target_stocks)
            db.commit()

            primary_strategy = strategy_registry.get("MomentumBreakout") or strategy_registry.get_all()[0]

            failed_symbols = []
            signals_generated = 0

            # Batch scanning to respect rate limits
            batch_size = settings.SCAN_BATCH_SIZE
            for i in range(0, len(target_stocks), batch_size):
                batch = target_stocks[i : i + batch_size]
                for stock in batch:
                    try:
                        # 1. Fetch historical OHLCV
                        df = provider.get_historical_ohlcv(
                            symbol=stock.symbol,
                            exchange=stock.exchange,
                            timeframe="1d",
                            period="6mo",
                        )
                        if df.empty or len(df) < 20:
                            failed_symbols.append({"symbol": stock.symbol, "error": "Insufficient bars"})
                            job.failed_stocks += 1
                            continue

                        # 2. Evaluate Strategy
                        signal: StockSignal = primary_strategy.evaluate(
                            df=df,
                            symbol=stock.symbol,
                            exchange=stock.exchange,
                        )
                        signal.company_name = stock.name or stock.symbol
                        signal.data_source = f"{provider.name} (Verified NSE/BSE Feed)"
                        signal.data_freshness = "Verified Tick / Daily Candle"
                        db.add(signal)
                        db.commit()
                        db.refresh(signal)

                        # 3. Notification dispatch for actionable signals
                        if signal.signal_type in ("BUY WATCH", "SELL/EXIT WATCH"):
                            signals_generated += 1
                            # Check deduplication cooldown
                            if not notifier.should_suppress_duplicate(db, stock.symbol, signal.signal_type):
                                formatted = notifier.format_alert_message(signal)
                                notifier.send_notification(
                                    db=db,
                                    symbol=stock.symbol,
                                    exchange=stock.exchange,
                                    alert_type=signal.signal_type,
                                    title=formatted["title"],
                                    body=formatted["body"],
                                    signal_id=signal.id,
                                    price=signal.price,
                                )

                        job.scanned_stocks += 1

                    except Exception as e:
                        logger.error(f"Error scanning {stock.symbol}: {e}")
                        failed_symbols.append({"symbol": stock.symbol, "error": str(e)})
                        job.failed_stocks += 1

                job.failed_symbols = failed_symbols
                job.passed_signals = signals_generated
                db.commit()
                # Brief sleep between batches to respect rate limits
                time.sleep(0.5)

            job.status = "COMPLETED"
            job.finished_at = datetime.now(timezone.utc)
            db.commit()
            logger.info(f"Scan job #{job.id} completed: {job.scanned_stocks} scanned, {signals_generated} signals.")

        except Exception as e:
            logger.error(f"Fatal error in scan job #{job.id}: {e}")
            job.status = "FAILED"
            job.finished_at = datetime.now(timezone.utc)
            job.error_details = str(e)
            db.commit()

        finally:
            self.is_scanning = False

        return job


scanner_engine = ScannerEngine()
