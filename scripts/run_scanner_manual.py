#!/usr/bin/env python3
"""CLI utility to manually trigger a stock universe scan and view signals."""

import sys
import os

# Add backend directory to sys.path
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE_DIR, "backend"))

from app.database.session import SessionLocal, init_db
from app.scanner.engine import scanner_engine
from app.models.signal import StockSignal


def main():
    print("Initializing database...")
    init_db()

    db = SessionLocal()
    try:
        print("\nTriggering manual market scan (NSE)...")
        job = scanner_engine.run_scan(db=db, exchange="NSE", force=True)

        print("\n" + "=" * 60)
        print(f"Scan Job #{job.id} Status: {job.status}")
        print(f"Total Stocks: {job.total_stocks}")
        print(f"Scanned: {job.scanned_stocks}")
        print(f"Passed Actionable Signals: {job.passed_signals}")
        print(f"Failed Symbols: {len(job.failed_symbols or [])}")
        print("=" * 60)

        # Print latest signals
        signals = (
            db.query(StockSignal)
            .order_by(StockSignal.id.desc())
            .limit(10)
            .all()
        )
        print("\nLatest Signals:")
        for s in signals:
            print(
                f"[{s.signal_type}] {s.symbol} @ ₹{s.price:.2f} | Strategy: {s.strategy_name} | "
                f"Strength: {s.strength:.0f}% | Stop: ₹{s.stop_loss or 0:.2f} | Target: ₹{s.target or 0:.2f}"
            )
            print(f"   Reason: {s.explanation}\n")

    finally:
        db.close()


if __name__ == "__main__":
    main()
