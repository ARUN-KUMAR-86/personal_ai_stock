"""Authentication and device registration API endpoints."""

from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token, verify_password, get_password_hash, get_current_user
from app.database.session import get_db
from app.models.user import User
from app.schemas.auth import LoginRequest, Token, RegisterDeviceTokenRequest, UserRead

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=Token)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Authenticates the owner and returns a JWT access token."""
    user = db.query(User).filter(User.username == request.username).first()

    # If owner does not exist in DB yet, seed initial owner credentials
    if not user and request.username == settings.OWNER_USERNAME and request.password == settings.OWNER_PASSWORD:
        user = User(
            username=settings.OWNER_USERNAME,
            hashed_password=get_password_hash(settings.OWNER_PASSWORD),
            is_admin=True,
            created_at=datetime.now(timezone.utc),
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(subject=user.username)
    return Token(access_token=access_token, token_type="bearer")


@router.post("/register-fcm")
def register_fcm_token(
    request: RegisterDeviceTokenRequest,
    current_user: str = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Registers the Android device's Firebase Cloud Messaging token for push notifications."""
    user = db.query(User).filter(User.username == current_user).first()
    if user:
        user.fcm_token = request.fcm_token
        db.commit()
    return {"message": "FCM device token registered successfully", "token": request.fcm_token}


@router.get("/me", response_model=UserRead)
def get_current_user_profile(
    current_user: str = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieves current owner profile."""
    user = db.query(User).filter(User.username == current_user).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
