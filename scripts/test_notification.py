#!/usr/bin/env python3
"""CLI utility to test alert generation and notification dispatch."""

import sys
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE_DIR, "backend"))

from app.database.session import SessionLocal, init_db
from app.notifications.notifier import notifier


def main():
    init_db()
    db = SessionLocal()
    try:
        print("Dispatching test alert to database & FCM (if configured)...")
        alert = notifier.send_notification(
            db=db,
            symbol="RELIANCE",
            exchange="NSE",
            alert_type="BUY_ENTRY",
            title="PERSONAL AI STOCK ALERT: RELIANCE (BUY WATCH)",
            body=(
                "Symbol: RELIANCE\n"
                "Exchange: NSE\n"
                "Signal: BUY WATCH\n"
                "Latest price: ₹2980.50\n"
                "Reasons:\n"
                "- Trend Momentum Breakout with RVOL 1.45x\n"
                "- RSI 62.5 in bullish expansion zone\n\n"
                "Entry condition: Enter above ₹2980.50\n"
                "Stop-loss: ₹2910.00\n"
                "Target: ₹3120.00\n"
                "Risk/reward: 2.0\n\n"
                "Status: Review the signal before trading.\n"
                "This is not a guarantee of profit."
            ),
            price=2980.50,
        )
        print(f"Alert ID #{alert.id} created successfully!")
        print(f"Sent to FCM: {alert.sent_to_fcm}")
        print(f"FCM Message ID: {alert.fcm_message_id}")
        print(f"FCM Available: {notifier.is_fcm_available()}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
