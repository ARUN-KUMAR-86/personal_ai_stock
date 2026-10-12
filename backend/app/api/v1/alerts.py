"""Alert history and push notification test endpoints."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
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

router = APIRouter(prefix="/alerts", tags=["Alerts & Notifications"])


@router.get("/history", response_model=List[AlertRead])
def get_alert_history(
    unread_only: bool = False,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    """Retrieves notification history and alert events."""
    query = db.query(AlertHistory)
    if unread_only:
        query = query.filter(AlertHistory.is_read == False)
    return query.order_by(AlertHistory.created_at.desc()).limit(limit).all()


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


@router.get("/devices", response_model=List[DeviceTokenRead])
def get_registered_devices(db: Session = Depends(get_db)):
    """Lists registered devices for notifications."""
    from app.models.alert import DeviceToken

    return db.query(DeviceToken).filter(DeviceToken.is_active == True).all()
