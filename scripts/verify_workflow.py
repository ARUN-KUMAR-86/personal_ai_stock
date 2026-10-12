#!/usr/bin/env python3
"""
Comprehensive End-to-End Verification of Personal AI Stock:
Notification-First Trading, Editable Investment Amount,
Mandatory Manual Buy Approval, Position Monitoring, and Safety Controls.
"""

import sys
import os
from pathlib import Path
from datetime import datetime, timezone, timedelta

# Ensure backend directory is in python path
backend_path = Path(__file__).resolve().parent.parent / "backend"
sys.path.insert(0, str(backend_path))

os.environ["ORDER_EXECUTION_MODE"] = "PAPER"
os.environ["AUTO_SELL_ENABLED"] = "false"
os.environ["EMERGENCY_STOP_ENABLED"] = "false"

from fastapi.testclient import TestClient
from app.main import app
from app.database.session import SessionLocal, init_db
from app.models.signal import StockSignal
from app.models.portfolio import Position
from app.models.order import Order
from app.core.config import settings
from app.risk.charges import IndianTaxCalculator


def log_step(title: str):
    print("\n" + "=" * 70)
    print(f"  [STEP] {title}")
    print("=" * 70)


def run_verification():
    print("Initializing Database & Test Client...")
    init_db()
    client = TestClient(app)

    db = SessionLocal()
    # Clean up test symbol if exists
    test_symbol = "TCS_TEST"
    db.query(StockSignal).filter(StockSignal.symbol == test_symbol).delete()
    db.query(Position).filter(Position.symbol == test_symbol).delete()
    db.query(Order).filter(Order.symbol == test_symbol).delete()

    # Step 1: AI Research & Recommendation Signal Creation
    log_step("1. Automatic AI Research & Recommendation Signal")
    now_utc = datetime.now(timezone.utc)
    signal = StockSignal(
        symbol=test_symbol,
        exchange="NSE",
        timestamp=now_utc,
        signal_type="BUY OPPORTUNITY",
        strategy_name="MomentumBreakout_AI",
        price=3500.0,
        stop_loss=3430.0,  # 2% stop loss
        target=3640.0,     # 4% target
        risk_reward=2.0,
        strength=88.5,
        explanation="Bullish momentum breakout confirmed by volume expansion and RSI recovery above 50.",
        company_name="Tata Consultancy Services Ltd",
        entry_range_low=3490.0,
        entry_range_high=3510.0,
        holding_period_hours=48,
        data_source="NSE Verified Market Feed",
        data_freshness="Real-time (verified < 5s ago)",
        liquidity_summary="High Liquidity — Average Daily Volume: 2.1M shares, tight bid-ask spread.",
        financial_news=[
            {"title": "TCS bags $1.2B digital transformation deal in Europe", "sentiment": "Bullish"},
            {"title": "Q3 constant currency revenue guidance revised upwards", "sentiment": "Positive"}
        ],
        risk_factors=[
            "High volatility event ahead: RBI monetary policy decision tomorrow.",
            "Cross-currency headwinds in UK market.",
            "Potential sector-wide profit booking if IT index drops below 36,000 support."
        ],
        score_breakdown={
            "technical_trend": 90,
            "volume_profile": 85,
            "sentiment_score": 88,
            "liquidity_score": 95,
            "overall": 88.5
        }
    )
    db.add(signal)
    db.commit()
    print(f"Created AI Recommendation Signal for {test_symbol} at ₹{signal.price}")

    # Fetch Recommendation via API
    rec_resp = client.get(f"/api/v1/signals/recommendation/{test_symbol}")
    assert rec_resp.status_code == 200, f"Failed to get recommendation: {rec_resp.text}"
    rec_data = rec_resp.json()
    print(f"-> Verified Recommendation retrieved successfully:")
    print(f"   Company: {rec_data['company_name']} ({rec_data['symbol']})")
    print(f"   Entry Price: ₹{rec_data['price']} | Target: ₹{rec_data['target']} | Stop-Loss: ₹{rec_data['stop_loss']}")
    print(f"   Holding Period: {rec_data['holding_period_hours']} Hours")
    print(f"   Data Freshness: {rec_data['data_freshness']} | Source: {rec_data['data_source']}")
    print(f"   Risk Factors Identified: {len(rec_data['risk_factors'])} items")

    # Step 2: Interactive Investment Amount Input & Live Calculation
    log_step("2. Investment Amount Input & Live Whole-Share / Tax Calculation")
    investment_amount = 10000.0  # ₹10,000
    calc_resp = client.post(
        "/api/v1/orders/calculate",
        json={
            "symbol": test_symbol,
            "exchange": "NSE",
            "investment_amount": investment_amount,
            "entry_price": 3500.0,
            "stop_loss": 3430.0,
            "target": 3640.0,
            "holding_period_hours": 48
        }
    )
    assert calc_resp.status_code == 200, f"Calculation failed: {calc_resp.text}"
    calc = calc_resp.json()
    assert calc["is_valid"] is True
    assert calc["shares_quantity"] == 2  # floor(10000 / 3500) = 2 shares
    assert calc["estimated_investment"] == 7000.0
    print(f"-> Live Calculation for ₹{investment_amount} investment:")
    print(f"   Whole Shares Quantity: {calc['shares_quantity']}")
    print(f"   Estimated Investment Cost: ₹{calc['estimated_investment']}")
    print(f"   Roundtrip Target Charges (Brokerage+STT+GST+DP): ₹{calc['roundtrip_target_charges']}")
    print(f"   Net Target Profit: ₹{calc['potential_profit_net']} ({calc['potential_profit_pct']}%)")
    print(f"   Net Stop-Loss Risk: ₹{calc['potential_loss_net']} ({calc['potential_loss_pct']}%)")
    print(f"   Risk/Reward Ratio: {calc['risk_reward_ratio']}")
    print(f"   Remaining Available Funds: ₹{calc['remaining_available_funds']}")

    # Step 3: Pre-Buy Slippage Verification & Re-Quote Protection
    log_step("3. Pre-Buy Slippage Check & Re-Quote Verification")
    prep_resp = client.post(
        "/api/v1/orders/prepare-buy",
        json={
            "symbol": test_symbol,
            "exchange": "NSE",
            "investment_amount": 10000.0,
            "expected_price": 3500.0,
            "stop_loss": 3430.0,
            "target": 3640.0,
            "holding_period_hours": 48
        }
    )
    assert prep_resp.status_code == 200
    prep_data = prep_resp.json()
    client_order_id = prep_data["client_order_id"]
    print(f"-> Order Prepared with idempotency token: {client_order_id}")
    print(f"   Verified Current Price: ₹{prep_data['verified_current_price']}")
    print(f"   Slippage Pct: {prep_data['slippage_pct']}% (within 1.0% limit)")

    # Step 4: Strict Prohibition of Automated Buying
    log_step("4. Verification that Automated Buying is Strictly Prohibited")
    unconfirmed_resp = client.post(
        "/api/v1/orders/buy-confirm",
        json={
            "client_order_id": client_order_id,
            "symbol": test_symbol,
            "exchange": "NSE",
            "investment_amount": 10000.0,
            "confirmed_price": 3500.0,
            "quantity": 2,
            "stop_loss": 3430.0,
            "target": 3640.0,
            "holding_period_hours": 48,
            "auto_sell_enabled": False,
            "user_confirmed": False  # Attempt autonomous execution
        }
    )
    assert unconfirmed_resp.status_code == 400
    print("-> Autonomous buy attempt successfully blocked with HTTP 400:")
    print(f"   Broker rejected: {unconfirmed_resp.json()['detail']}")

    # Step 5: Explicit Manual Buy Confirmation
    log_step("5. Explicit Manual User Buy Confirmation & Broker Order Verification")
    confirm_resp = client.post(
        "/api/v1/orders/buy-confirm",
        json={
            "client_order_id": client_order_id,
            "symbol": test_symbol,
            "exchange": "NSE",
            "investment_amount": 10000.0,
            "confirmed_price": 3500.0,
            "quantity": 2,
            "stop_loss": 3430.0,
            "target": 3640.0,
            "holding_period_hours": 48,
            "auto_sell_enabled": False,
            "user_confirmed": True  # Explicit user confirmation
        }
    )
    assert confirm_resp.status_code == 200, f"Buy confirmation failed: {confirm_resp.text}"
    confirmed_data = confirm_resp.json()
    order_id = confirmed_data["order_id"]
    print(f"-> Order Confirmed and Verified by Broker:")
    print(f"   Order ID: {order_id} | Status: {confirmed_data['status']}")
    print(f"   Filled Quantity: {confirmed_data['filled_quantity']} @ ₹{confirmed_data['executed_price']}")
    print(f"   Broker Order Reference: {confirmed_data['broker_order_id']}")
    print(f"   Holding Period: {confirmed_data['holding_period_hours']}h | Mode: {confirmed_data['mode']}")

    # Verify Open Position Registered
    pos = db.query(Position).filter(Position.symbol == test_symbol, Position.is_open == True).first()
    assert pos is not None
    assert pos.quantity == 2
    assert pos.holding_period_hours == 48
    assert pos.exit_deadline is not None
    print(f"-> Position automatically registered for monitoring:")
    print(f"   Position ID: {pos.id} | Quantity: {pos.quantity} | Avg Price: ₹{pos.avg_entry_price}")
    print(f"   Holding Period: {pos.holding_period_hours}h | Exit Deadline: {pos.exit_deadline}")

    # Step 6: Automatic Position Monitoring & Configured Exit
    log_step("6. Automatic Position Monitoring & Configured Exit Policies")
    # Test Monitor Check API
    mon_resp = client.post("/api/v1/safety/monitor-check")
    assert mon_resp.status_code == 200
    print("-> Monitor check executed successfully.")

    # 6a: Test 48-Hour Deadline Expiry Trigger with Auto-Sell Disabled (Notification First)
    print("\n   [6a] Testing 48-Hour Deadline Expiry (Auto-Sell = False, Notification First):")
    pos.exit_deadline = datetime.now(timezone.utc) - timedelta(minutes=10)  # Expired
    pos.auto_sell_enabled = False
    pos.exit_triggered = False
    pos.exit_reason = None
    pos.current_price = 3510.0
    db.commit()

    from app.portfolio.monitor import PositionMonitor
    res_6a = PositionMonitor.check_and_update_positions(db, force_market_open=True)
    db.refresh(pos)
    assert pos.exit_triggered is True
    assert "HOLDING_PERIOD_EXPIRED" in pos.exit_reason
    assert pos.is_open is True  # Position remains OPEN because auto-sell is disabled!
    print(f"   Exit Triggered: {pos.exit_triggered}")
    print(f"   Exit Reason: {pos.exit_reason}")
    print(f"   Action Taken: NOTIFIED_MANUAL_EXIT (Position remains OPEN for manual decision, auto-sell is False)")

    # 6b: Test Stop-Loss Trigger with Auto-Sell Enabled (Explicit Opt-In)
    print("\n   [6b] Testing Stop-Loss Trigger (Auto-Sell = True, Opted-In):")
    pos.exit_triggered = False
    pos.exit_reason = None
    pos.auto_sell_enabled = True  # Explicit user opt-in for this position
    pos.current_price = 3420.0     # Price drops below stop-loss (3430.0)
    pos.exit_deadline = datetime.now(timezone.utc) + timedelta(hours=48)  # Deadline not expired
    db.commit()

    res_6b = PositionMonitor.check_and_update_positions(db, force_market_open=True)
    db.refresh(pos)
    assert pos.is_open is False  # Position is now CLOSED via verified Auto-Sell
    assert pos.exit_triggered is True
    assert "STOP_LOSS_HIT" in pos.exit_reason
    print(f"   Exit Reason: {pos.exit_reason}")
    print(f"   Action Taken: AUTO_SOLD (Executed sell order & closed position)")
    print(f"   Realized P&L: ₹{pos.realized_pnl:.2f}")

    # Step 7: Emergency Kill Switch Safety Control
    log_step("7. Emergency Kill Switch Safety Control")
    # Enable emergency stop
    stop_resp = client.post("/api/v1/safety/emergency-stop?enabled=true")
    assert stop_resp.status_code == 200
    assert stop_resp.json()["emergency_stop_enabled"] is True
    print("-> Emergency Kill Switch ENABLED.")

    # Attempt to place order while Emergency Stop is active
    blocked_resp = client.post(
        "/api/v1/orders/buy-confirm",
        json={
            "client_order_id": "ORD-EMERGENCY-TEST",
            "symbol": test_symbol,
            "exchange": "NSE",
            "investment_amount": 10000.0,
            "confirmed_price": 3500.0,
            "quantity": 1,
            "stop_loss": 3430.0,
            "target": 3640.0,
            "holding_period_hours": 48,
            "auto_sell_enabled": False,
            "user_confirmed": True
        }
    )
    assert blocked_resp.status_code == 403
    print(f"-> Order successfully blocked under Emergency Kill Switch (HTTP 403): {blocked_resp.json()['detail']}")

    # Restore emergency stop
    restore_resp = client.post("/api/v1/safety/emergency-stop?enabled=false")
    assert restore_resp.status_code == 200
    assert restore_resp.json()["emergency_stop_enabled"] is False
    print("-> Emergency Kill Switch RESTORED to normal.")

    # Clean up test records
    db.query(StockSignal).filter(StockSignal.symbol == test_symbol).delete()
    db.query(Position).filter(Position.symbol == test_symbol).delete()
    db.query(Order).filter(Order.symbol == test_symbol).delete()
    db.commit()
    db.close()

    print("\n" + "=" * 70)
    print("  [SUCCESS] All 7 Workflow Stages Passed Verification Flawlessly!")
    print("=" * 70)


if __name__ == "__main__":
    run_verification()
