"""Alert history and push notification test endpoints."""

import json
import asyncio
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.alert import AlertHistory
from app.schemas.alert import (
    AlertRead,
    AlertMarkReadRequest,
    NotificationTestRequest,
    DeviceTokenCreate,
    DeviceTokenRead,
)
from app.notifications.notifier import notifier
from app.notifications.broadcaster import broadcaster

router = APIRouter(prefix="/alerts", tags=["Alerts & Notifications"])


@router.get("/stream")
async def stream_realtime_alerts(request: Request):
    """
    Real-time Server-Sent Events (SSE) notification stream.
    Instantly pushes new BUY and SELL alerts to web dashboard and connected clients.
    """
    async def event_generator():
        queue = broadcaster.subscribe()
        try:
            # Initial connection confirmation
            yield "event: connected\ndata: {\"status\": \"connected\", \"message\": \"Live SSE feed active\"}\n\n"
            while True:
                if await request.is_disconnected():
                    break
                try:
                    alert_payload = await asyncio.wait_for(queue.get(), timeout=15.0)
                    yield f"event: alert\ndata: {json.dumps(alert_payload)}\n\n"
                except asyncio.TimeoutError:
                    # Keepalive heartbeat ping
                    yield ": heartbeat\n\n"
        finally:
            broadcaster.unsubscribe(queue)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/history", response_model=List[AlertRead])
def get_alert_history(
    action: Optional[str] = None,  # Filter by BUY or SELL
    unread_only: bool = False,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    """Retrieves real-time notification history (filtered by BUY or SELL)."""
    query = db.query(AlertHistory)
    if action:
        norm = action.upper().strip()
        query = query.filter((AlertHistory.action == norm) | (AlertHistory.alert_type == norm))
    if unread_only:
        query = query.filter(AlertHistory.is_read == False)
    return query.order_by(AlertHistory.created_at.desc()).limit(limit).all()


@router.post("/clear")
def clear_alert_history(db: Session = Depends(get_db)):
    """Clears all historical notifications."""
    deleted_count = db.query(AlertHistory).delete()
    db.commit()
    return {"status": "SUCCESS", "deleted_count": deleted_count}


@router.post("/{alert_id}/read")
def mark_single_alert_read(alert_id: int, db: Session = Depends(get_db)):
    """Marks a single alert as read."""
    alert = db.query(AlertHistory).filter(AlertHistory.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found.")
    alert.is_read = True
    db.commit()
    return {"status": "SUCCESS", "alert_id": alert_id}


@router.post("/mark-read")
def mark_alerts_read(request: AlertMarkReadRequest, db: Session = Depends(get_db)):
    """Marks specified alerts as read."""
    db.query(AlertHistory).filter(AlertHistory.id.in_(request.alert_ids)).update(
        {AlertHistory.is_read: True}, synchronize_session=False
    )
    db.commit()
    return {"message": f"Marked {len(request.alert_ids)} alerts as read."}


@router.post("/test-push")
def test_push_notification(request: NotificationTestRequest, db: Session = Depends(get_db)):
    """Dispatches a test notification to verify Android FCM configuration."""
    alert = notifier.send_notification(
        db=db,
        symbol=request.symbol,
        exchange=request.exchange,
        alert_type="TEST_ALERT",
        title=request.title,
        body=request.body,
        target_token=request.device_token,
    )
    return {
        "status": "SENT",
        "alert_id": alert.id,
        "sent_to_fcm": alert.sent_to_fcm,
        "fcm_message_id": alert.fcm_message_id,
        "fcm_available": notifier.is_fcm_available(),
    }


@router.post("/register-token", response_model=DeviceTokenRead)
def register_device_token(request: DeviceTokenCreate, db: Session = Depends(get_db)):
    """Registers an Android phone FCM token to receive real-time push alerts."""
    from app.models.alert import DeviceToken

    device = db.query(DeviceToken).filter(DeviceToken.token == request.token).first()
    if device:
        device.device_name = request.device_name
        device.is_active = True
    else:
        device = DeviceToken(
            token=request.token,
            device_name=request.device_name,
            is_active=True,
        )
        db.add(device)
    db.commit()
    db.refresh(device)
    return device


@router.post("/unregister-token")
def unregister_device_token(token: str, db: Session = Depends(get_db)):
    """Unregisters an Android device from receiving notifications."""
    from app.models.alert import DeviceToken

    device = db.query(DeviceToken).filter(DeviceToken.token == token).first()
    if device:
        device.is_active = False
        db.commit()
        return {"status": "UNREGISTERED", "token": token}
    return {"status": "NOT_FOUND", "token": token}


@router.get("/trade-alerts", response_model=List[AlertRead])
def get_trade_alerts(
    status: Optional[str] = None,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    """Retrieves trade alerts with pending approval status and historical responses."""
    query = db.query(AlertHistory).filter(AlertHistory.alert_type == "TRADE_ALERT")
    if status:
        query = query.filter(AlertHistory.status == status.upper())
    return query.order_by(AlertHistory.created_at.desc()).limit(limit).all()


@router.post("/trade-alerts/{alert_id}/respond")
def respond_to_trade_alert(
    alert_id: int,
    request: dict,  # {"action": "APPROVE" or "REJECT", "confirmed_price": float (optional)}
    db: Session = Depends(get_db),
):
    """
    1-Tap Approval / Rejection Workflow for PERSONAL AI STOCK — TRADE ALERT.
    No real or simulated trade is placed without user approval.
    Enforces authorized Groww account verification and daily token validity.
    """
    from datetime import datetime, timezone
    from app.models.broker import BrokerAccount
    from app.models.portfolio import Position, PaperTrade
    from app.brokers.factory import get_broker_adapter
    from app.portfolio.manager import PortfolioManager

    alert = db.query(AlertHistory).filter(AlertHistory.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Trade alert not found.")

    if alert.status != "PENDING_APPROVAL":
        return {
            "success": False,
            "status": alert.status,
            "message": f"Trade alert has already been responded to ({alert.status}).",
        }

    user_action = str(request.get("action", "")).upper().strip()
    if user_action not in ("APPROVE", "REJECT"):
        raise HTTPException(status_code=400, detail="Action must be APPROVE or REJECT.")

    # 1. REJECT Flow
    if user_action == "REJECT":
        alert.status = "REJECTED"
        alert.responded_at = datetime.now(timezone.utc)
        alert.is_read = True
        db.commit()
        return {
            "success": True,
            "status": "REJECTED",
            "symbol": alert.symbol,
            "message": f"Trade alert for {alert.symbol} was rejected. No order placed.",
        }

    # 2. APPROVE Flow
    account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
    if account and not account.is_trading_active:
        raise HTTPException(
            status_code=400,
            detail="Trading is currently paused in Trading Controls. Resume trading to execute approved orders.",
        )

    broker = get_broker_adapter()
    # Check authorized account match
    if not broker.verify_authorized_account():
        raise HTTPException(
            status_code=403,
            detail=f"Groww account mismatch: Session does not match authorized account {broker.authorized_account_id}.",
        )

    # Check token expiry
    if broker.is_token_expired():
        raise HTTPException(
            status_code=401,
            detail="Groww access token has expired. Please renew your daily session before approving trades.",
        )

    exec_price = float(request.get("confirmed_price") or alert.price or 100.0)
    qty = max(1, alert.estimated_quantity or 1)
    action_type = (alert.action or "BUY").upper()

    try:
        # Place order through broker adapter (with user_confirmed=True)
        broker_res = broker.place_order(
            symbol=alert.symbol,
            exchange=alert.exchange,
            transaction_type=action_type,
            quantity=qty,
            price=exec_price,
            user_confirmed=True,
        )

        broker_order_id = str(broker_res.get("order_id", f"ORD-{alert.symbol}-{alert.id}"))
        actual_price = float(broker_res.get("price", exec_price))
        actual_qty = int(broker_res.get("filled_quantity", qty))

        # Register position / execute trade in portfolio
        trade = PortfolioManager.execute_paper_trade(
            db=db,
            symbol=alert.symbol,
            exchange=alert.exchange,
            action=action_type,
            quantity=actual_qty,
            price=actual_price,
            reason=f"Approved Trade Alert #{alert.id}",
            stop_loss=alert.stop_loss,
            target=alert.target,
            mode=broker_res.get("mode", "PAPER"),
            order_id=broker_order_id,
        )

        # Update broker account balance
        if account:
            if action_type == "BUY":
                cost = (actual_price * actual_qty) + trade.fees
                account.available_funds = max(0.0, account.available_funds - cost)
            else:
                proceeds = (actual_price * actual_qty) - trade.fees
                account.available_funds += proceeds
                account.account_balance += trade.pnl

        # Update alert status
        alert.status = "EXECUTED"
        alert.responded_at = datetime.now(timezone.utc)
        alert.order_id = broker_order_id
        alert.broker_verified = True
        alert.is_read = True
        alert.execution_result = {
            "broker_order_id": broker_order_id,
            "executed_price": actual_price,
            "filled_quantity": actual_qty,
            "fees": trade.fees,
            "pnl": trade.pnl,
        }
        db.commit()

        # Check auto-withdraw rule on profitable sales
        if action_type == "SELL" and account and account.auto_withdraw_profits and trade.pnl >= account.auto_withdraw_threshold:
            from app.api.v1.trading_control import check_auto_withdraw
            check_auto_withdraw(db)

        # Send execution confirmation notification
        try:
            notifier.send_notification(
                db=db,
                symbol=alert.symbol,
                exchange=alert.exchange,
                alert_type=f"{action_type}_EXECUTED",
                title=f"PERSONAL AI STOCK — ORDER EXECUTED ({action_type})",
                body=(
                    f"Order #{broker_order_id} verified on {alert.symbol}.\n"
                    f"Executed: {actual_qty} shares @ ₹{actual_price:.2f}\n"
                    f"P&L: ₹{trade.pnl:.2f}\n"
                    f"Available Funds: ₹{(account.available_funds if account else 0.0):.2f}"
                ),
                price=actual_price,
            )
        except Exception:
            pass

        return {
            "success": True,
            "status": "EXECUTED",
            "action": action_type,
            "symbol": alert.symbol,
            "order_id": broker_order_id,
            "price": actual_price,
            "quantity": actual_qty,
            "pnl": trade.pnl,
            "message": f"Successfully executed {action_type} for {alert.symbol} ({actual_qty} shares at ₹{actual_price:.2f}).",
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to execute order with broker: {str(e)}")

