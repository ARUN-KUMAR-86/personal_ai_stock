"""Database engine, session management, and table initialization."""

from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from app.core.config import settings
from app.core.logging import logger
from app.database.base import Base

# Configure engine based on database dialect
db_url = settings.DATABASE_URL
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)

connect_args = {}
if db_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(
    db_url,
    connect_args=connect_args,
    pool_pre_ping=True,
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _migrate_sqlite_columns():
    """Ensures newly added columns exist in existing SQLite databases."""
    if not settings.DATABASE_URL.startswith("sqlite"):
        return
    import sqlite3
    db_path = settings.DATABASE_URL.replace("sqlite:///", "")
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check stock_signals columns
        cursor.execute("PRAGMA table_info(stock_signals);")
        sig_cols = [row[1] for row in cursor.fetchall()]
        if sig_cols:
            new_sig_cols = {
                "company_name": "VARCHAR(100)",
                "entry_range_low": "FLOAT",
                "entry_range_high": "FLOAT",
                "holding_period_hours": "INTEGER DEFAULT 48",
                "data_source": "VARCHAR(100) DEFAULT 'Verified Market Data'",
                "data_freshness": "VARCHAR(50) DEFAULT 'Live'",
                "liquidity_summary": "TEXT",
                "financial_news": "JSON",
                "risk_factors": "JSON",
                "score_breakdown": "JSON",
                "ai_thesis": "JSON",
            }
            for col, col_type in new_sig_cols.items():
                if col not in sig_cols:
                    cursor.execute(f"ALTER TABLE stock_signals ADD COLUMN {col} {col_type};")

        # Check portfolio_positions columns
        cursor.execute("PRAGMA table_info(portfolio_positions);")
        pos_cols = [row[1] for row in cursor.fetchall()]
        if pos_cols:
            new_pos_cols = {
                "holding_period_hours": "INTEGER DEFAULT 48",
                "exit_deadline": "DATETIME",
                "auto_sell_enabled": "BOOLEAN DEFAULT 0",
                "exit_strategy": "VARCHAR(50) DEFAULT 'TARGET_OR_STOPLOSS_OR_EXPIRY'",
                "exit_triggered": "BOOLEAN DEFAULT 0",
                "exit_reason": "VARCHAR(100)",
                "monitored_at": "DATETIME",
                "mode": "VARCHAR(20) DEFAULT 'PAPER'",
                "order_id": "VARCHAR(64)",
            }
            for col, col_type in new_pos_cols.items():
                if col not in pos_cols:
                    cursor.execute(f"ALTER TABLE portfolio_positions ADD COLUMN {col} {col_type};")

        conn.commit()
        conn.close()
    except Exception as e:
        logger.warning(f"SQLite auto-migration check note: {e}")


def init_db() -> None:
    """Creates database tables if they do not exist."""
    # Import all models to ensure they are registered with Base.metadata
    import app.models  # noqa: F401
    Base.metadata.create_all(bind=engine)
    _migrate_sqlite_columns()
    logger.info("Database tables initialized successfully.")


def get_db() -> Generator[Session, None, None]:
    """Dependency that yields a database session and closes it afterwards."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
