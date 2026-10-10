"""Notification service supporting Firebase Cloud Messaging (FCM) and alert history."""

import os
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.models.alert import AlertHistory
from app.models.signal import StockSignal


class FCMNotifier:
    """Manages push notifications to Android devices via Firebase Cloud Messaging."""

    def __init__(self):
        self._initialized = False
        self._init_firebase()

    def _init_firebase(self):
        if settings.FCM_SERVICE_ACCOUNT_PATH and os.path.exists(settings.FCM_SERVICE_ACCOUNT_PATH):
            try:
                import firebase_admin
                from firebase_admin import credentials

                if not firebase_admin._apps:
                    cred = credentials.Certificate(settings.FCM_SERVICE_ACCOUNT_PATH)
                    firebase_admin.initialize_app(cred)
                self._initialized = True
                logger.info("Firebase Admin initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
                self._initialized = False
        else:
            logger.info("FCM service account file not configured or not found. Operating in local notification mode.")

    def is_fcm_available(self) -> bool:
        return self._initialized

    def format_alert_message(self, signal: StockSignal) -> Dict[str, str]:
        """Formats alert according to strict transparency and risk disclaimer guidelines."""
        title = f"PERSONAL AI STOCK ALERT: {signal.symbol} ({signal.signal_type})"
        
        indicators = signal.indicator_summary or {}
        rsi = indicators.get("rsi_14", "N/A")
        rvol = indicators.get("rvol", "N/A")
        ema21 = indicators.get("ema_21", "N/A")

        body = (
            f"Symbol: {signal.symbol}\n"
            f"Exchange: {signal.exchange}\n"
            f"Signal: {signal.signal_type}\n"
            f"Latest Price: ₹{signal.price}\n"
            f"Timestamp: {signal.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}\n\n"
            f"Reasons:\n"
            f"- Strategy: {signal.strategy_name}\n"
            f"- Indicators: RSI(14)={rsi}, RVOL={rvol}x, EMA21=₹{ema21}\n"
            f"- Details: {signal.explanation}\n\n"
            f"Entry Condition: {signal.entry_condition or 'Review market'}\n"
            f"Stop-loss: ₹{signal.stop_loss if signal.stop_loss else 'None'}\n"
            f"Target: ₹{signal.target if signal.target else 'None'}\n"
            f"Risk/Reward: {signal.risk_reward if signal.risk_reward else 'N/A'}\n\n"
            f"Status: Review the signal before trading.\n"
            f"This is not a guarantee of profit."
        )

        return {"title": title, "body": body}

    def should_suppress_duplicate(
        self,
        db: Session,
        symbol: str,
        signal_type: str,
        cooldown_minutes: int = settings.NOTIFICATION_COOLDOWN_MINUTES,
    ) -> bool:
        """Checks if a matching alert was recently generated to avoid duplicate spam."""
        threshold = datetime.now(timezone.utc) - timedelta(minutes=cooldown_minutes)
        recent_alert = (
            db.query(AlertHistory)
            .filter(
                AlertHistory.symbol == symbol,
                AlertHistory.alert_type == signal_type,
                AlertHistory.created_at >= threshold,
            )
            .first()
        )
        return recent_alert is not None

    def send_notification(
        self,
        db: Session,
        symbol: str,
        exchange: str,
        alert_type: str,
        title: str,
        body: str,
        signal_id: Optional[int] = None,
        price: Optional[float] = None,
        target_token: Optional[str] = None,
    ) -> AlertHistory:
        """Dispatches notification via FCM and records alert in history."""
        sent_to_fcm = False
        message_id = None

        token_to_use = target_token or settings.DEFAULT_FCM_DEVICE_TOKEN

        if self._initialized and token_to_use:
            try:
                from firebase_admin import messaging

                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data={
                        "symbol": symbol,
                        "exchange": exchange,
                        "alert_type": alert_type,
                        "price": str(price or 0.0),
                    },
                    token=token_to_use,
                )
                message_id = messaging.send(message)
                sent_to_fcm = True
                logger.info(f"FCM message dispatched successfully for {symbol}: {message_id}")
            except Exception as e:
                logger.error(f"FCM dispatch error: {e}")
                sent_to_fcm = False

        # Store alert record in database
        alert_record = AlertHistory(
            symbol=symbol,
            exchange=exchange,
            alert_type=alert_type,
            title=title,
            message=body,
            signal_id=signal_id,
            price=price,
            is_read=False,
            sent_to_fcm=sent_to_fcm,
            fcm_message_id=message_id,
        )
        db.add(alert_record)
        db.commit()
        db.refresh(alert_record)
        return alert_record


notifier = FCMNotifier()
