"""Unit tests for automatic scanner engine."""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database.base import Base
from app.models.stock import Stock
from app.models.scan_job import ScanJob
from app.scanner.engine import scanner_engine


def get_test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    return Session()


def test_scanner_sync_universe():
    db = get_test_db()
    added = scanner_engine.sync_universe(db, exchange="NSE")
    assert added > 0
    count = db.query(Stock).filter(Stock.exchange == "NSE").count()
    assert count == added


def test_scanner_run_scan():
    db = get_test_db()
    # Pre-populate 2 test stocks
    db.add(Stock(symbol="RELIANCE", exchange="NSE", name="Reliance Industries Ltd"))
    db.add(Stock(symbol="TCS", exchange="NSE", name="Tata Consultancy Services"))
    db.commit()

    job = scanner_engine.run_scan(db=db, symbols=["RELIANCE", "TCS"], exchange="NSE", force=True)

    assert job is not None
    assert job.status in ("COMPLETED", "RUNNING")
    assert job.total_stocks == 2
    assert job.scanned_stocks + job.failed_stocks == 2
