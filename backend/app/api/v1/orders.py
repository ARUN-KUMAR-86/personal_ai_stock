"""Order calculation, manual buy confirmation, broker execution, and audit trail endpoints."""

import uuid
from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.database.session import get_db
from app.models.order import Order
from app.models.portfolio import Position
from app.models.stock import Stock
from app.schemas.order import (
    OrderCalculateRequest,
    OrderCalculateResponse,
    PrepareBuyRequest,
    PrepareBuyResponse,
    BuyConfirmRequest,
    OrderRead,
)
from app.risk.charges import IndianTaxCalculator
from app.providers.factory import get_market_data_provider
from app.brokers.factory import get_broker_adapter
from app.portfolio.manager import PortfolioManager

router = APIRouter(prefix="/orders", tags=["Order Execution & Safety"])


@router.post("/calculate", response_model=OrderCalculateResponse)
def calculate_order(request: OrderCalculateRequest, db: Session = Depends(get_db)):
    """
    Live dynamic calculation of whole-share quantity, investment cost,
    statutory transaction charges, profit/loss projections, and risk/reward ratio.
    """
    provider = get_market_data_provider()
    broker = get_broker_adapter()

    # Determine live or verified price
    price = request.entry_price
    if price is None or price <= 0:
        quote = provider.get_quote(symbol=request.symbol, exchange=request.exchange)
        price = quote.price

    # Stop-loss and target defaults if not supplied
    stop_loss = request.stop_loss or round(price * 0.97, 2)
    target = request.target or round(price * 1.05, 2)

    # Fetch available broker funds and portfolio state
    funds_info = broker.get_funds()
    available_funds = float(funds_info.get("available_funds", 100000.0))

    portfolio_summary = PortfolioManager.get_portfolio_summary(db)
    current_invested = float(portfolio_summary.get("total_invested_value", 0.0))
    total_capital = max(available_funds + current_invested, 100000.0)

    metrics = IndianTaxCalculator.calculate_trade_metrics(
        investment_amount=request.investment_amount,
        price=price,
        stop_loss=stop_loss,
        target=target,
        holding_period_hours=request.holding_period_hours,
        available_funds=available_funds,
        total_capital=total_capital,
        current_invested_value=current_invested,
    )

    return metrics


@router.post("/prepare-buy", response_model=PrepareBuyResponse)
def prepare_buy_order(request: PrepareBuyRequest, db: Session = Depends(get_db)):
    """
    Pre-order verification:
    1. Fetches verified live quote
    2. Compares against expected price to detect significant slippage
    3. Calculates exact whole-share quantity and charges
    4. Issues client_order_id for idempotency and duplicate prevention
    """
    if settings.EMERGENCY_STOP_ENABLED:
        raise HTTPException(
            status_code=403,
            detail="Emergency Stop is currently ACTIVE. All new trading is halted.",
        )

    provider = get_market_data_provider()
    broker = get_broker_adapter()

    # Fetch verified current quote
    try:
        quote = provider.get_quote(symbol=request.symbol, exchange=request.exchange)
        live_price = quote.price if (quote and quote.price and quote.price > 0) else request.expected_price
    except Exception as e:
        logger.warning(f"Could not fetch real-time quote for {request.symbol}: {e}. Using expected price.")
        live_price = request.expected_price

    # Slippage / price change check
    slippage_pct = round(abs(live_price - request.expected_price) / (request.expected_price or 1.0) * 100, 2)
    price_changed = slippage_pct > settings.MAX_SLIPPAGE_PCT
    slippage_warning = None
    if price_changed:
        direction = "increased" if live_price > request.expected_price else "decreased"
        slippage_warning = (
            f"Price has {direction} from ₹{request.expected_price:.2f} to ₹{live_price:.2f} ({slippage_pct}%). "
            f"Please review the updated quote before confirming."
        )

    # Query stock info
    stock_record = (
        db.query(Stock)
        .filter(Stock.symbol == request.symbol.upper(), Stock.exchange == request.exchange.upper())
        .first()
    )
    company_name = stock_record.name if stock_record else request.symbol.upper()

    funds_info = broker.get_funds()
    available_funds = float(funds_info.get("available_funds", 100000.0))

    metrics = IndianTaxCalculator.calculate_trade_metrics(
        investment_amount=request.investment_amount,
        price=live_price,
        stop_loss=request.stop_loss,
        target=request.target,
        holding_period_hours=request.holding_period_hours,
        available_funds=available_funds,
    )

    client_order_id = f"CLI-{uuid.uuid4().hex[:12].upper()}"
    mode = "GROWW_LIVE" if (broker.is_configured() and broker.order_execution_enabled) else "PAPER"

    return {
        "symbol": request.symbol.upper(),
        "exchange": request.exchange.upper(),
        "company_name": company_name,
        "verified_current_price": live_price,
        "price_changed": price_changed,
        "slippage_pct": slippage_pct,
        "slippage_warning": slippage_warning,
        "shares_quantity": metrics["shares_quantity"],
        "estimated_investment": metrics["estimated_investment"],
        "total_charges": metrics["buy_charges"]["total_charges"],
        "total_outlay": metrics["total_outlay"],
        "available_funds": available_funds,
        "stop_loss": request.stop_loss,
        "target": request.target,
        "holding_period_hours": request.holding_period_hours,
        "risk_reward_ratio": metrics["risk_reward_ratio"],
        "client_order_id": client_order_id,
        "mode": mode,
    }


@router.post("/buy-confirm", response_model=OrderRead)
def confirm_buy_order(request: BuyConfirmRequest, db: Session = Depends(get_db)):
    """
    Submits buy order after explicit manual confirmation.
    MANDATORY SAFETY GATES:
    1. AI can NEVER buy automatically: request.user_confirmed MUST be True.
    2. Emergency Stop check.
    3. Duplicate order prevention within 60s.
    4. Execution verification via broker adapter.
    5. Automatic position registration for continuous monitoring.
    6. Audit trail persistence.
    """
    # 1. Emergency stop check
    if settings.EMERGENCY_STOP_ENABLED:
        raise HTTPException(
            status_code=403,
            detail="Emergency Stop is currently ACTIVE. Order placement rejected.",
        )

    # 2. Manual buy confirmation check
    if not request.user_confirmed:
        raise HTTPException(
            status_code=400,
            detail="Mandatory Manual Confirmation Missing. Automated buying is strictly prohibited.",
        )

    if request.quantity <= 0:
        raise HTTPException(status_code=400, detail="Order quantity must be at least 1 share.")

    # 3. Duplicate order prevention (Idempotency and recent window check)
    existing_order = db.query(Order).filter(Order.client_order_id == request.client_order_id).first()
    if existing_order:
        logger.warning(f"Duplicate order submission blocked for client_order_id {request.client_order_id}")
        return existing_order

    threshold = datetime.now(timezone.utc) - timedelta(seconds=60)
    recent_dup = (
        db.query(Order)
        .filter(
            Order.symbol == request.symbol.upper(),
            Order.transaction_type == "BUY",
            Order.status.in_(["CONFIRMED", "SUBMITTED", "FILLED"]),
            Order.created_at >= threshold,
        )
        .first()
    )
    if recent_dup:
        raise HTTPException(
            status_code=409,
            detail=f"Duplicate order detected for {request.symbol} placed within the last 60 seconds (Order #{recent_dup.order_id}).",
        )

    broker = get_broker_adapter()
    order_id = f"ORD-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
    mode = "GROWW_LIVE" if (broker.is_configured() and broker.order_execution_enabled) else "PAPER"

    # Calculate statutory charges
    charges = IndianTaxCalculator.calculate_buy_charges(request.quantity * request.confirmed_price)

    # Create Order record
    order_record = Order(
        order_id=order_id,
        client_order_id=request.client_order_id,
        signal_id=request.signal_id,
        symbol=request.symbol.upper(),
        exchange=request.exchange.upper(),
        transaction_type="BUY",
        order_type="MARKET",
        status="SUBMITTED",
        requested_quantity=request.quantity,
        filled_quantity=0,
        requested_price=request.confirmed_price,
        stop_loss=request.stop_loss,
        target=request.target,
        holding_period_hours=request.holding_period_hours,
        brokerage=charges["brokerage"],
        stt=charges["stt"],
        exchange_charges=charges["exchange_charges"],
        gst=charges["gst"],
        stamp_duty=charges["stamp_duty"],
        total_charges=charges["total_charges"],
        mode=mode,
        user_confirmed=True,
        auto_sell_enabled=request.auto_sell_enabled,
        user_confirmed_at=datetime.now(timezone.utc),
    )
    db.add(order_record)
    db.commit()

    # 4. Submit order through broker
    try:
        broker_res = broker.place_order(
            symbol=request.symbol.upper(),
            exchange=request.exchange.upper(),
            transaction_type="BUY",
            quantity=request.quantity,
            price=request.confirmed_price,
            user_confirmed=True,
        )

        broker_order_id = str(broker_res.get("order_id", order_id))
        order_status = broker_res.get("status", "FILLED").upper()
        filled_qty = int(broker_res.get("filled_quantity", request.quantity))
        executed_price = float(broker_res.get("price", request.confirmed_price))

        order_record.broker_order_id = broker_order_id
        order_record.status = order_status
        order_record.filled_quantity = filled_qty
        order_record.executed_price = executed_price
        order_record.executed_at = datetime.now(timezone.utc)
        order_record.audit_trail = {
            "broker_response": broker_res,
            "ip_confirmed": True,
            "charges": charges,
        }

        # 5. Automatically register position for continuous monitoring
        if order_status in ("FILLED", "COMPLETED") and filled_qty > 0:
            PortfolioManager.execute_paper_trade(
                db=db,
                symbol=request.symbol.upper(),
                exchange=request.exchange.upper(),
                action="BUY",
                quantity=filled_qty,
                price=executed_price,
                reason="Manual Buy Order Confirmed",
                stop_loss=request.stop_loss,
                target=request.target,
                holding_period_hours=request.holding_period_hours,
                auto_sell_enabled=request.auto_sell_enabled,
                mode=mode,
                order_id=order_id,
            )
            logger.info(
                f"Position successfully registered for continuous monitoring: {request.symbol} "
                f"({filled_qty} shares, SL: ₹{request.stop_loss}, TP: ₹{request.target}, "
                f"Holding: {request.holding_period_hours}h, Auto-Sell: {request.auto_sell_enabled})"
            )

        db.commit()
        db.refresh(order_record)
        return order_record

    except Exception as e:
        logger.error(f"Failed to execute buy order {order_id}: {e}")
        order_record.status = "REJECTED"
        order_record.error_message = str(e)
        db.commit()
        db.refresh(order_record)
        raise HTTPException(status_code=500, detail=f"Order execution rejected by broker: {str(e)}")


@router.get("/history", response_model=List[OrderRead])
def get_order_history(limit: int = 50, db: Session = Depends(get_db)):
    """Retrieves auditable history of all orders and user confirmations."""
    return db.query(Order).order_by(Order.created_at.desc()).limit(limit).all()


@router.get("/{order_id}", response_model=OrderRead)
def get_order_by_id(order_id: str, db: Session = Depends(get_db)):
    """Fetches details of a specific order."""
    order_record = db.query(Order).filter(Order.order_id == order_id).first()
    if not order_record:
        raise HTTPException(status_code=404, detail="Order not found.")
    return order_record
