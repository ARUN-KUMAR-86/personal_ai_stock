"""Unit tests for FCM Notifications and duplicate alert suppression."""

from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database.base import Base
from app.models.signal import StockSignal
from app.models.alert import AlertHistory
from app.notifications.notifier import notifier


def get_test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    return Session()


def test_format_alert_message():
    signal = StockSignal(
        symbol="RELIANCE",
        exchange="NSE",
        timestamp=datetime.now(timezone.utc),
        signal_type="BUY WATCH",
        strategy_name="MomentumBreakout",
        price=2950.0,
        stop_loss=2890.0,
        target=3070.0,
        risk_reward=2.0,
        strength=85.0,
        entry_condition="Enter on confirmation above ₹2950",
        invalidation_condition="Close below ₹2890",
        indicator_summary={"rsi_14": 62.5, "rvol": 1.45, "ema_21": 2920.0},
        explanation="Bullish momentum breakout with elevated volume.",
    )

    formatted = notifier.format_alert_message(signal)
    assert "title" in formatted
    assert "body" in formatted
    assert "PERSONAL AI STOCK ALERT" in formatted["title"]
    assert "RELIANCE" in formatted["body"]
    assert "BUY WATCH" in formatted["body"]
    assert "₹2950.0" in formatted["body"]
    assert "Stop-loss: ₹2890.0" in formatted["body"]
    assert "Target: ₹3070.0" in formatted["body"]
    assert "This is not a guarantee of profit." in formatted["body"]


def test_duplicate_alert_suppression():
    db = get_test_db()

    # Initially no alerts sent
    assert notifier.should_suppress_duplicate(db, "RELIANCE", "BUY WATCH") is False

    # Send first alert
    notifier.send_notification(
        db=db,
        symbol="RELIANCE",
        exchange="NSE",
        alert_type="BUY WATCH",
        title="Test Alert",
        body="Test Body",
        price=2950.0,
    )

    # Immediately after, should be suppressed by cooldown
    assert notifier.should_suppress_duplicate(db, "RELIANCE", "BUY WATCH") is True

    # Different symbol should NOT be suppressed
    assert notifier.should_suppress_duplicate(db, "TCS", "BUY WATCH") is False

    # Different alert type on same symbol should NOT be suppressed
    assert notifier.should_suppress_duplicate(db, "RELIANCE", "SELL/EXIT WATCH") is False
