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
        cert_data = None
        if settings.FCM_SERVICE_ACCOUNT_JSON and settings.FCM_SERVICE_ACCOUNT_JSON.strip():
            import json
            try:
                cert_data = json.loads(settings.FCM_SERVICE_ACCOUNT_JSON.strip())
            except Exception as e:
                logger.error(f"Failed to parse FCM_SERVICE_ACCOUNT_JSON environment variable: {e}")
        elif settings.FCM_SERVICE_ACCOUNT_PATH and os.path.exists(settings.FCM_SERVICE_ACCOUNT_PATH):
            cert_data = settings.FCM_SERVICE_ACCOUNT_PATH

        if cert_data:
            try:
                import firebase_admin
                from firebase_admin import credentials

                if not firebase_admin._apps:
                    cred = credentials.Certificate(cert_data)
                    firebase_admin.initialize_app(cred)
                self._initialized = True
                logger.info("Firebase Admin initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
                self._initialized = False
        else:
            logger.info("FCM credentials not configured or not found. Operating in local notification mode.")

    def is_fcm_available(self) -> bool:
        return self._initialized

    def format_alert_message(self, signal: StockSignal) -> Dict[str, str]:
        """Formats alert according to strict transparency and risk disclaimer guidelines."""
        title = f"PERSONAL AI STOCK ALERT: {signal.symbol} ({signal.signal_type})"
        
        indicators = signal.indicator_summary or {}
        rsi = indicators.get("rsi_14", "N/A")
        rvol = indicators.get("rvol", "N/A")
        ema21 = indicators.get("ema_21", "N/A")

        data_src = getattr(signal, "data_source", None) or "Verified Market Data"
        holding_h = getattr(signal, "holding_period_hours", None) or 48

        body = (
            f"Symbol: {signal.symbol}\n"
            f"Exchange: {signal.exchange}\n"
            f"Signal: {signal.signal_type} [POTENTIAL OPPORTUNITY]\n"
            f"Latest Price: ₹{signal.price}\n"
            f"Data Source: {data_src}\n"
            f"Timestamp: {signal.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}\n"
            f"Intended Holding Period: {holding_h} Hours\n\n"
            f"Reasons:\n"
            f"- Strategy: {signal.strategy_name}\n"
            f"- Indicators: RSI(14)={rsi}, RVOL={rvol}x, EMA21=₹{ema21}\n"
            f"- Details: {signal.explanation}\n\n"
            f"Execution Levels:\n"
            f"Entry Condition: {signal.entry_condition or 'Review market'}\n"
            f"Stop-loss: ₹{signal.stop_loss if signal.stop_loss else 'None'}\n"
            f"Target: ₹{signal.target if signal.target else 'None'}\n"
            f"Risk/Reward: {signal.risk_reward if signal.risk_reward else 'N/A'}\n\n"
            f"Status: Potential opportunity. Review the signal before trading.\n"
            f"This is not a guarantee of profit.\n"
            f"Automatic buying is disabled. Every purchase requires your explicit manual confirmation."
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

        tokens_to_send = []
        if target_token:
            tokens_to_send.append(target_token)
        else:
            try:
                from app.models.alert import DeviceToken
                active_tokens = db.query(DeviceToken).filter(DeviceToken.is_active == True).all()
                tokens_to_send = [d.token for d in active_tokens]
            except Exception as db_err:
                logger.warning(f"Failed to query registered devices: {db_err}")

            if not tokens_to_send and settings.DEFAULT_FCM_DEVICE_TOKEN:
                tokens_to_send.append(settings.DEFAULT_FCM_DEVICE_TOKEN)

        if self._initialized and tokens_to_send:
            try:
                from firebase_admin import messaging

                for tok in tokens_to_send:
                    try:
                        message = messaging.Message(
                            notification=messaging.Notification(title=title, body=body),
                            data={
                                "symbol": symbol,
                                "exchange": exchange,
                                "alert_type": alert_type,
                                "price": str(price or 0.0),
                                "signal_id": str(signal_id or ""),
                                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                            },
                            token=tok,
                        )
                        mid = messaging.send(message)
                        message_id = mid
                        sent_to_fcm = True
                        logger.info(f"FCM message dispatched successfully for {symbol} to token {tok[:8]}...: {mid}")
                    except Exception as tok_err:
                        logger.error(f"FCM dispatch error for token {tok[:8]}...: {tok_err}")
            except Exception as e:
                logger.error(f"FCM messaging general error: {e}")
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

    def send_buy_sell_alert(
        self,
        db: Session,
        symbol: str,
        exchange: str,
        action: str,  # strictly "BUY" or "SELL"
        price: float,
        stop_loss: Optional[float] = None,
        target: Optional[float] = None,
        risk_reward: Optional[float] = None,
        reason: Optional[str] = None,
        gemini_research: Optional[Dict[str, Any]] = None,
        signal_id: Optional[int] = None,
        time_horizon: str = "1-DAY",  # "1-DAY" (Short Term) or "1-MONTH" (Long Term)
    ) -> AlertHistory:
        """
        Creates, logs, and dispatches a dedicated realtime BUY or SELL notification.
        Supports 1-DAY (Short Term) and 1-MONTH (Long Term) horizons, and foreign / US stocks.
        """
        norm_action = "BUY" if "BUY" in action.upper() else "SELL"
        icon = "🟢" if norm_action == "BUY" else "🔴"
        horizon_tag = "⚡ 1-DAY" if time_horizon == "1-DAY" else "📅 1-MONTH"
        is_us = exchange.upper() in ("US", "NASDAQ", "NYSE")
        curr = "$" if is_us else "₹"

        thesis_headline = ""
        thesis_summary = ""
        catalysts = []
        if gemini_research:
            thesis_headline = gemini_research.get("headline", "")
            thesis_summary = gemini_research.get("investment_thesis", "")
            catalysts = gemini_research.get("catalysts", [])

        title = f"{horizon_tag} {icon} {norm_action} ALERT: {symbol.upper()} @ {curr}{price:,.2f}"

        horizon_desc = "1-DAY (Short Term / 24-48 Hours)" if time_horizon == "1-DAY" else "1-MONTH (Long Term / Positional 30 Days)"
        body_lines = [
            f"Action: {norm_action}",
            f"Horizon: {horizon_desc}",
            f"Stock: {symbol.upper()} ({exchange.upper()})",
            f"Price: {curr}{price:,.2f}",
        ]
        if target:
            body_lines.append(f"Target: {curr}{target:,.2f}")
        if stop_loss:
            body_lines.append(f"Stop-Loss: {curr}{stop_loss:,.2f}")
        if risk_reward:
            body_lines.append(f"Risk/Reward: 1:{risk_reward:.2f}")
        if thesis_headline:
            body_lines.append(f"\nGemini Research: {thesis_headline}")
        elif reason:
            body_lines.append(f"\nReason: {reason}")
        if catalysts:
            body_lines.append("Catalysts:\n" + "\n".join(f"• {c}" for c in catalysts[:2]))

        body = "\n".join(body_lines)

        sent_to_fcm = False
        message_id = None
        try:
            from app.models.alert import DeviceToken
            tokens = [d.token for d in db.query(DeviceToken).filter(DeviceToken.is_active == True).all()]
            if self._initialized and tokens:
                from firebase_admin import messaging
                for tok in tokens:
                    msg = messaging.Message(
                        notification=messaging.Notification(title=title, body=body),
                        data={
                            "symbol": symbol.upper(),
                            "exchange": exchange.upper(),
                            "action": norm_action,
                            "alert_type": norm_action,
                            "time_horizon": time_horizon,
                            "price": str(price),
                            "click_action": "FLUTTER_NOTIFICATION_CLICK",
                        },
                        token=tok,
                    )
                    mid = messaging.send(msg)
                    message_id = mid
                    sent_to_fcm = True
        except Exception as e:
            logger.warning(f"FCM push notification error: {e}")

        alert = AlertHistory(
            symbol=symbol.upper(),
            exchange=exchange.upper(),
            alert_type=norm_action,
            action=norm_action,
            time_horizon=time_horizon,
            title=title,
            message=body,
            signal_id=signal_id,
            price=price,
            stop_loss=stop_loss,
            target=target,
            reason=reason or thesis_headline,
            risk_level="High Conviction" if norm_action == "BUY" else "Capital Protection",
            gemini_research=gemini_research,
            sent_to_fcm=sent_to_fcm,
            fcm_message_id=message_id,
            created_at=datetime.now(timezone.utc),
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)

        # Broadcast via Real-time SSE
        try:
            from app.notifications.broadcaster import broadcaster
            broadcaster.broadcast({
                "id": alert.id,
                "symbol": alert.symbol,
                "exchange": alert.exchange,
                "action": alert.action,
                "alert_type": alert.alert_type,
                "time_horizon": alert.time_horizon,
                "title": alert.title,
                "message": alert.message,
                "price": alert.price,
                "stop_loss": alert.stop_loss,
                "target": alert.target,
                "gemini_research": alert.gemini_research,
                "created_at": alert.created_at.isoformat() if alert.created_at else None,
            })
        except Exception as be:
            logger.warning(f"Failed to broadcast real-time alert: {be}")

        return alert

    def send_trade_alert(
        self,
        db: Session,
        symbol: str,
        exchange: str,
        action: str,  # "BUY" or "SELL"
        price: float,
        suggested_investment: float = 100.0,
        estimated_quantity: int = 1,
        reason: str = "AI analysis and market signals",
        risk_level: str = "Medium",
        stop_loss: Optional[float] = None,
        target: Optional[float] = None,
        signal_id: Optional[int] = None,
        gemini_research: Optional[Dict[str, Any]] = None,
        time_horizon: str = "1-DAY",
    ) -> AlertHistory:
        """Compatibility wrapper that routes directly to send_buy_sell_alert."""
        return self.send_buy_sell_alert(
            db=db,
            symbol=symbol,
            exchange=exchange,
            action=action,
            price=price,
            stop_loss=stop_loss,
            target=target,
            reason=reason,
            gemini_research=gemini_research,
            signal_id=signal_id,
            time_horizon=time_horizon,
        )


notifier = FCMNotifier()
