"""Trading Safety & Emergency Controls API endpoints."""

from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.database.session import get_db
from app.models.order import Order
from app.models.portfolio import Position
from app.schemas.order import SafetyStatusResponse, UpdateSafetySettingsRequest, PositionMonitoringUpdateRequest
from app.brokers.factory import get_broker_adapter
from app.portfolio.monitor import PositionMonitor

router = APIRouter(prefix="/safety", tags=["Trading Safety Controls"])


@router.get("/status", response_model=SafetyStatusResponse)
def get_safety_status():
    """
    Returns current trading safety parameters:
    - Emergency stop state
    - Automatic selling opt-in state
    - Capital & portfolio exposure limits
    - Execution mode
    - Permanent prohibition of automated buying
    """
    broker = get_broker_adapter()
    mode = "GROWW_LIVE" if (broker.is_configured() and broker.order_execution_enabled) else "PAPER"

    return {
        "emergency_stop_enabled": settings.EMERGENCY_STOP_ENABLED,
        "auto_sell_enabled": settings.AUTO_SELL_ENABLED,
        "max_position_risk_pct": settings.MAX_POSITION_RISK_PCT,
        "max_single_stock_pct": settings.MAX_SINGLE_STOCK_PCT,
        "max_portfolio_exposure_pct": settings.MAX_PORTFOLIO_EXPOSURE_PCT,
        "execution_mode": mode,
        "auto_buying_allowed": False,  # Always False for user safety
    }


@router.post("/emergency-stop")
def toggle_emergency_stop(enabled: bool):
    """
    Emergency kill switch:
    Immediately halts or resumes new trading activities across the entire system.
    """
    settings.EMERGENCY_STOP_ENABLED = enabled
    status_str = "ACTIVATED" if enabled else "DEACTIVATED"
    logger.warning(f"EMERGENCY KILL SWITCH {status_str} by user request.")
    return {
        "status": status_str,
        "emergency_stop_enabled": settings.EMERGENCY_STOP_ENABLED,
        "message": (
            "All new order placement is HALTED."
            if enabled
            else "Emergency halt lifted. Trading enabled."
        ),
    }


@router.put("/settings", response_model=SafetyStatusResponse)
def update_safety_settings(request: UpdateSafetySettingsRequest):
    """Updates configurable risk and safety limits."""
    if request.emergency_stop_enabled is not None:
        settings.EMERGENCY_STOP_ENABLED = request.emergency_stop_enabled
    if request.auto_sell_enabled is not None:
        settings.AUTO_SELL_ENABLED = request.auto_sell_enabled
    if request.max_position_risk_pct is not None:
        settings.MAX_POSITION_RISK_PCT = request.max_position_risk_pct
    if request.max_single_stock_pct is not None:
        settings.MAX_SINGLE_STOCK_PCT = request.max_single_stock_pct
    if request.max_portfolio_exposure_pct is not None:
        settings.MAX_PORTFOLIO_EXPOSURE_PCT = request.max_portfolio_exposure_pct

    broker = get_broker_adapter()
    mode = "GROWW_LIVE" if (broker.is_configured() and broker.order_execution_enabled) else "PAPER"

    return {
        "emergency_stop_enabled": settings.EMERGENCY_STOP_ENABLED,
        "auto_sell_enabled": settings.AUTO_SELL_ENABLED,
        "max_position_risk_pct": settings.MAX_POSITION_RISK_PCT,
        "max_single_stock_pct": settings.MAX_SINGLE_STOCK_PCT,
        "max_portfolio_exposure_pct": settings.MAX_PORTFOLIO_EXPOSURE_PCT,
        "execution_mode": mode,
        "auto_buying_allowed": False,
    }


@router.post("/monitor-check")
def trigger_position_monitor(db: Session = Depends(get_db)):
    """Triggers an on-demand position monitoring and exit check pass."""
    result = PositionMonitor.check_and_update_positions(db)
    return result


@router.put("/positions/{position_id}/monitoring")
def update_position_monitoring(
    position_id: int,
    request: PositionMonitoringUpdateRequest,
    db: Session = Depends(get_db),
):
    """Updates stop-loss, target, holding period, or auto-sell toggle for a specific open position."""
    pos = db.query(Position).filter(Position.id == position_id, Position.is_open == True).first()
    if not pos:
        raise HTTPException(status_code=404, detail="Open position not found.")

    if request.stop_loss is not None:
        pos.stop_loss = request.stop_loss
    if request.target is not None:
        pos.target = request.target
    if request.holding_period_hours is not None:
        pos.holding_period_hours = request.holding_period_hours
    if request.auto_sell_enabled is not None:
        pos.auto_sell_enabled = request.auto_sell_enabled

    db.commit()
    db.refresh(pos)
    return {
        "position_id": pos.id,
        "symbol": pos.symbol,
        "stop_loss": pos.stop_loss,
        "target": pos.target,
        "holding_period_hours": pos.holding_period_hours,
        "auto_sell_enabled": pos.auto_sell_enabled,
        "message": "Position monitoring parameters updated successfully.",
    }
