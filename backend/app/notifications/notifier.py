"""Notification service supporting multi-channel delivery: FCM Push, SSE Real-Time, Desktop Alerts, and Persistent Queue."""

import os
import subprocess
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.models.alert import AlertHistory, NotificationQueue, DeviceToken
from app.models.signal import StockSignal
from app.notifications.broadcaster import broadcaster


class FCMNotifier:
    """
    Institutional Multi-Channel Notification Engine:
    - Dispatches to FCM (Android Push)
    - Dispatches to SSE Broadcaster (Live Web & Mobile Clients)
    - Dispatches to Linux Desktop Notifications (notify-send)
    - Persists into durable NotificationQueue with status tracking & retry logic
    - Enforces P0 to P4 priority classification
    - Independent Rupee & Percentage profit/loss threshold monitoring
    """

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
                logger.error(f"Failed to parse FCM_SERVICE_ACCOUNT_JSON: {e}")
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
                logger.info("Firebase Admin SDK initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
                self._initialized = False
        else:
            logger.info("FCM credentials not configured or not found. Operating in local & SSE notification mode.")

    def is_fcm_available(self) -> bool:
        return self._initialized

    def format_alert_message(self, signal: StockSignal) -> Dict[str, str]:
        """Formats alert according to strict transparency and risk disclaimer guidelines."""
        priority_tag = signal.priority or "P2"
        title = f"[{priority_tag}] PERSONAL AI STOCK ALERT: {signal.symbol} ({signal.signal_type})"
        
        indicators = signal.indicator_summary or {}
        rsi = indicators.get("rsi_14", "N/A")
        rvol = indicators.get("rvol", "N/A")
        ema21 = indicators.get("ema_21", "N/A")

        data_src = getattr(signal, "data_source", None) or "Verified Market Data"
        holding_h = getattr(signal, "holding_period_hours", None) or 48

        body = (
            f"Symbol: {signal.symbol}\n"
            f"Exchange: {signal.exchange}\n"
            f"Priority: {priority_tag}\n"
            f"Signal: {signal.signal_type} [POTENTIAL OPPORTUNITY]\n"
            f"Latest Price: ₹{signal.price}\n"
            f"Data Source: {data_src}\n"
            f"Timestamp: {signal.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC') if signal.timestamp else 'Live'}\n"
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

    def dispatch_desktop_notification(self, title: str, body: str, is_critical: bool = False):
        """Attempts to display a native desktop alert on Linux systems if display is active."""
        try:
            urgency = "critical" if is_critical else "normal"
            # Format single line preview for notify-send body if multiline
            clean_body = body.replace("\n\n", " | ").replace("\n", " ")
            if len(clean_body) > 160:
                clean_body = clean_body[:157] + "..."
            subprocess.Popen(
                ["notify-send", "-u", urgency, "-a", "Zed AI Stock Monitor", title, clean_body],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            logger.debug(f"Desktop notification note: {e}")

    def should_suppress_duplicate(
        self,
        db: Session,
        symbol: str,
        signal_type: str,
        cooldown_minutes: int = settings.NOTIFICATION_COOLDOWN_MINUTES,
    ) -> bool:
        """Checks if an identical signal alert was recently generated."""
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
        action: str = "BUY",
        signal_id: Optional[int] = None,
        price: Optional[float] = None,
        target_token: Optional[str] = None,
        priority: str = "P2",
        threshold_key: Optional[str] = None,
        pnl_inr: Optional[float] = None,
        pnl_pct: Optional[float] = None,
        position_id: Optional[int] = None,
    ) -> AlertHistory:
        """Dispatches notification across all active channels (FCM, SSE, Desktop, Queue)."""
        sent_to_fcm = False
        fcm_message_id = None
        is_critical = (priority == "P0" or action == "SELL")

        # 1. Fetch tokens for FCM dispatch
        tokens_to_send = []
        if target_token:
            tokens_to_send.append(target_token)
        else:
            try:
                active_tokens = db.query(DeviceToken).filter(DeviceToken.is_active == True).all()
                tokens_to_send = [d.token for d in active_tokens]
            except Exception as db_err:
                logger.warning(f"Failed to query registered devices: {db_err}")

            if not tokens_to_send and settings.DEFAULT_FCM_DEVICE_TOKEN:
                tokens_to_send.append(settings.DEFAULT_FCM_DEVICE_TOKEN)

        # 2. Attempt FCM dispatch
        if self._initialized and tokens_to_send:
            try:
                from firebase_admin import messaging
                for tok in tokens_to_send:
                    try:
                        msg = messaging.Message(
                            notification=messaging.Notification(title=title, body=body),
                            data={
                                "symbol": symbol,
                                "exchange": exchange,
                                "alert_type": alert_type,
                                "priority": priority,
                                "price": str(price or 0.0),
                                "pnl_inr": str(pnl_inr or 0.0),
                                "pnl_pct": str(pnl_pct or 0.0),
                                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                            },
                            token=tok,
                            android=messaging.AndroidConfig(
                                priority="high" if is_critical else "normal",
                                notification=messaging.AndroidNotification(
                                    channel_id="stock_intelligence_alerts_v2",
                                    sound="default" if not is_critical else "alert_critical",
                                ),
                            ),
                        )
                        mid = messaging.send(msg)
                        fcm_message_id = mid
                        sent_to_fcm = True
                        logger.info(f"FCM dispatched for {symbol} ({alert_type}) to {tok[:8]}...: {mid}")
                    except Exception as tok_err:
                        logger.error(f"FCM token error for {tok[:8]}...: {tok_err}")
            except Exception as e:
                logger.error(f"FCM dispatch error: {e}")

        # 3. Native desktop alert
        self.dispatch_desktop_notification(title, body, is_critical=is_critical)

        # 4. Save alert record in database
        alert_record = AlertHistory(
            symbol=symbol,
            exchange=exchange,
            alert_type=alert_type,
            action=action,
            title=title,
            message=body,
            signal_id=signal_id,
            price=price,
            priority=priority,
            threshold_key=threshold_key,
            pnl_inr=pnl_inr,
            pnl_pct=pnl_pct,
            delivery_status="SENT" if sent_to_fcm else ("DELIVERED" if not tokens_to_send else "QUEUED"),
            position_id=position_id,
            is_read=False,
            sent_to_fcm=sent_to_fcm,
            fcm_message_id=fcm_message_id,
            created_at=datetime.now(timezone.utc),
        )
        db.add(alert_record)
        db.commit()
        db.refresh(alert_record)

        # Enforce strict FIFO queue of 100 notifications maximum
        self._enforce_fifo_capacity(db, max_capacity=100)

        # 5. Enqueue in persistent notification queue if FCM failed or needs verification
        queue_item = NotificationQueue(
            alert_id=alert_record.id,
            channel="FCM" if tokens_to_send else "SSE",
            status="SENT" if (sent_to_fcm or not tokens_to_send) else "PENDING",
            priority=priority,
            payload={
                "symbol": symbol,
                "exchange": exchange,
                "title": title,
                "body": body,
                "priority": priority,
                "price": price,
                "pnl_inr": pnl_inr,
                "pnl_pct": pnl_pct,
                "threshold_key": threshold_key,
            },
        )
        db.add(queue_item)
        db.commit()

        # 6. Real-time Server-Sent Events (SSE) broadcast
        try:
            broadcaster.broadcast({
                "id": alert_record.id,
                "symbol": symbol,
                "exchange": exchange,
                "alert_type": alert_type,
                "priority": priority,
                "title": title,
                "message": body,
                "price": price,
                "pnl_inr": pnl_inr,
                "pnl_pct": pnl_pct,
                "threshold_key": threshold_key,
                "is_critical": is_critical,
                "created_at": alert_record.created_at.isoformat(),
            })
        except Exception as be:
            logger.warning(f"SSE broadcast error: {be}")

        return alert_record

    def _enforce_fifo_capacity(self, db: Session, max_capacity: int = 100) -> None:
        """
        Enforces FIFO (First In, First Out) retention policy:
        Keeps strictly at most max_capacity (default 100) newest notifications.
        Any older notifications beyond 100 are pruned.
        """
        try:
            total = db.query(AlertHistory).count()
            if total > max_capacity:
                excess = total - max_capacity
                oldest_ids = [
                    row[0] for row in (
                        db.query(AlertHistory.id)
                        .order_by(AlertHistory.created_at.asc(), AlertHistory.id.asc())
                        .limit(excess)
                        .all()
                    )
                ]
                if oldest_ids:
                    db.query(NotificationQueue).filter(NotificationQueue.alert_id.in_(oldest_ids)).delete(synchronize_session=False)
                    db.query(AlertHistory).filter(AlertHistory.id.in_(oldest_ids)).delete(synchronize_session=False)
                    db.commit()
                    logger.info(f"FIFO notification queue: pruned {len(oldest_ids)} oldest alerts to maintain capacity of {max_capacity}.")
        except Exception as e:
            logger.warning(f"Error enforcing notification FIFO capacity: {e}")

    def send_threshold_alert(
        self,
        db: Session,
        position: Any,
        current_price: float,
        threshold_key: str,
        threshold_name: str,
        pnl_inr: float,
        pnl_pct: float,
        priority: str,
    ) -> AlertHistory:
        """
        Generates and dispatches an exact Profit or Loss Threshold Alert.
        Fully populates: Stock name, Purchase price, Current price, Quantity,
        Total investment, Current profit/loss in INR, Percentage, Threshold, Priority, Timestamp.
        """
        symbol = position.symbol.upper()
        exchange = position.exchange or "NSE"
        qty = position.quantity
        avg_buy = position.avg_entry_price
        total_inv = round(avg_buy * qty, 2)
        now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

        total_sell = round(current_price * qty, 2)
        is_profit = pnl_inr >= 0
        cur_sym = "$" if exchange.upper() in ("US", "NASDAQ", "NYSE") else "₹"
        cur_code = "USD" if cur_sym == "$" else "INR"
        pnl_inr_str = f"+{cur_sym}{pnl_inr:.2f}" if is_profit else f"-{cur_sym}{abs(pnl_inr):.2f}"
        pnl_pct_str = f"+{pnl_pct:.2f}%" if is_profit else f"-{abs(pnl_pct):.2f}%"
        status_tag = f"+{cur_sym}{int(abs(pnl_inr))} PROFIT" if is_profit else f"-{cur_sym}{int(abs(pnl_inr))} LOSS"

        market_tag = f"{symbol} – {exchange} – {cur_code}"
        title = f"🔴 SELL ALERT ({status_tag}): {market_tag} @ {cur_sym}{current_price:,.2f}"

        broker_name = "US Broker" if cur_sym == "$" else "Groww"
        body = (
            f"🔴 SELL ALERT: {market_tag} reached {threshold_name}!\n"
            f"• Buy Price: {cur_sym}{avg_buy:,.2f} | Total Buy Amount: {cur_sym}{total_inv:,.2f} (Qty: {qty})\n"
            f"• Sell Price: {cur_sym}{current_price:,.2f} | Total Sell Amount: {cur_sym}{total_sell:,.2f}\n"
            f"• Profit / Loss: {pnl_inr_str} ({pnl_pct_str})\n"
            f"• Milestone: {threshold_name}\n"
            f"Action: Execute SELL order in {broker_name} to {'lock in your profit' if is_profit else 'protect your capital'}!"
        )

        return self.send_notification(
            db=db,
            symbol=symbol,
            exchange=exchange,
            alert_type="SELL",
            action="SELL",
            title=title,
            body=body,
            price=current_price,
            priority=priority,
            threshold_key=threshold_key,
            pnl_inr=pnl_inr,
            pnl_pct=pnl_pct,
            position_id=position.id,
        )

    def send_buy_sell_alert(
        self,
        db: Session,
        symbol: str,
        exchange: str,
        action: str,  # "BUY" or "SELL"
        price: float,
        stop_loss: Optional[float] = None,
        target: Optional[float] = None,
        risk_reward: Optional[float] = None,
        reason: Optional[str] = None,
        gemini_research: Optional[Dict[str, Any]] = None,
        signal_id: Optional[int] = None,
        time_horizon: str = "1-DAY",
        priority: str = "P1",
    ) -> AlertHistory:
        """Dispatches an approved AI research recommendation alert."""
        norm_action = "BUY" if "BUY" in action.upper() else "SELL"
        icon = "🟢" if norm_action == "BUY" else "🔴"
        horizon_tag = "⚡ 1-DAY" if time_horizon == "1-DAY" else "📅 1-MONTH"
        is_us = exchange.upper() in ("US", "NASDAQ", "NYSE")
        curr = "$" if is_us else "₹"

        thesis_headline = ""
        catalysts = []
        if gemini_research:
            thesis_headline = gemini_research.get("headline", "")
            catalysts = gemini_research.get("catalysts", [])

        title = f"[{priority}] {horizon_tag} {icon} {norm_action} OPPORTUNITY: {symbol.upper()} @ {curr}{price:,.2f}"

        horizon_desc = "1-DAY (Short Term / 24-48 Hours)" if time_horizon == "1-DAY" else "1-MONTH (Long Term / Positional 30 Days)"
        body_lines = [
            f"Action: {norm_action}",
            f"Priority: {priority}",
            f"Horizon: {horizon_desc}",
            f"Stock: {symbol.upper()} ({exchange.upper()})",
            f"Current Price: {curr}{price:,.2f}",
        ]
        if target:
            body_lines.append(f"Target: {curr}{target:,.2f}")
        if stop_loss:
            body_lines.append(f"Stop-Loss: {curr}{stop_loss:,.2f}")
        if risk_reward:
            body_lines.append(f"Risk/Reward: 1:{risk_reward:.2f}")
        if thesis_headline:
            body_lines.append(f"\nAI Research: {thesis_headline}")
        elif reason:
            body_lines.append(f"\nReason: {reason}")
        if catalysts:
            body_lines.append("Supporting Catalysts:\n" + "\n".join(f"• {c}" for c in catalysts[:2]))

        body_lines.append("\nNote: Click 'I BOUGHT THIS STOCK' after executing your purchase in Groww.")
        body = "\n".join(body_lines)

        return self.send_notification(
            db=db,
            symbol=symbol.upper(),
            exchange=exchange.upper(),
            alert_type=norm_action,
            action=norm_action,
            title=title,
            body=body,
            signal_id=signal_id,
            price=price,
            priority=priority,
        )

    def send_trade_alert(
        self,
        db: Session,
        symbol: str,
        exchange: str,
        action: str,
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
        priority: str = "P1",
    ) -> AlertHistory:
        """Compatibility wrapper routing to send_buy_sell_alert."""
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
            priority=priority,
        )

    def process_notification_queue(self, db: Session) -> Dict[str, Any]:
        """Processes pending items in the durable notification queue with retries."""
        pending = (
            db.query(NotificationQueue)
            .filter(
                NotificationQueue.status == "PENDING",
                NotificationQueue.retry_count < NotificationQueue.max_retries,
            )
            .order_by(NotificationQueue.created_at.asc())
            .limit(20)
            .all()
        )

        processed = 0
        failed = 0
        for item in pending:
            item.last_attempt = datetime.now(timezone.utc)
            item.retry_count += 1
            try:
                # Attempt FCM dispatch if token available
                active_tokens = db.query(DeviceToken).filter(DeviceToken.is_active == True).all()
                if self._initialized and active_tokens:
                    from firebase_admin import messaging
                    for dt in active_tokens:
                        payload = item.payload or {}
                        msg = messaging.Message(
                            notification=messaging.Notification(
                                title=payload.get("title", "Stock Alert"),
                                body=payload.get("body", ""),
                            ),
                            token=dt.token,
                        )
                        messaging.send(msg)
                    item.status = "SENT"
                    processed += 1
                else:
                    # Broadcasted locally
                    item.status = "SENT"
                    processed += 1
            except Exception as e:
                item.last_error = str(e)
                if item.retry_count >= item.max_retries:
                    item.status = "FAILED"
                failed += 1

        db.commit()
        return {"processed": processed, "failed": failed, "remaining_pending": len(pending) - processed}


notifier = FCMNotifier()
