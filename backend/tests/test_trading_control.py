"""Automated tests for Dedicated Trading Control, Groww Verification, and Trade Alert Approvals."""

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database.session import SessionLocal
from app.models.broker import BrokerAccount, FundTransaction
from app.models.alert import AlertHistory


@pytest.fixture
def client():
    return TestClient(app)


def test_trading_control_summary(client):
    res = client.get("/api/v1/trading-control/summary")
    assert res.status_code == 200
    data = res.json()
    assert "groww_account_status" in data
    assert "trading_budget" in data
    assert "amount_in_positions" in data
    assert "todays_pnl" in data
    assert "Hybrid Guard" in data["trading_mode"] or "Option B" in data["trading_mode"]
    assert "max_amount_per_trade" in data
    assert "daily_loss_limit" in data
    assert "auto_withdraw_profits" in data


def test_start_and_stop_trading(client):
    # Stop trading
    stop_res = client.post("/api/v1/trading-control/stop")
    assert stop_res.status_code == 200
    assert stop_res.json()["is_trading_active"] is False

    summary_stop = client.get("/api/v1/trading-control/summary").json()
    assert summary_stop["is_trading_active"] is False

    # Start trading
    start_res = client.post("/api/v1/trading-control/start")
    assert start_res.status_code == 200
    assert start_res.json()["is_trading_active"] is True

    summary_start = client.get("/api/v1/trading-control/summary").json()
    assert summary_start["is_trading_active"] is True


def test_update_trading_budget_and_settings(client):
    # Set budget to 300, max trade to 100, loss limit to 50, trading mode to Option B
    update_res = client.post(
        "/api/v1/trading-control/settings",
        json={
            "trading_budget": 300.0,
            "max_amount_per_trade": 100.0,
            "daily_loss_limit": 50.0,
            "auto_withdraw_profits": False,
            "trading_mode": "Option B: Hybrid Guard (Auto Stop-Loss)",
        },
    )
    assert update_res.status_code == 200
    data = update_res.json()
    assert data["trading_budget"] == 300.0
    assert data["max_amount_per_trade"] == 100.0
    assert data["daily_loss_limit"] == 50.0
    assert data["auto_withdraw_profits"] is False
    assert "Hybrid Guard" in data["trading_mode"]


def test_record_deposit_and_withdrawal(client):
    # Record deposit of 500
    dep_res = client.post(
        "/api/v1/trading-control/transactions",
        json={"transaction_type": "DEPOSIT", "amount": 500.0, "note": "Bank UPI deposit"},
    )
    assert dep_res.status_code == 200
    assert dep_res.json()["transaction_type"] == "DEPOSIT"
    assert dep_res.json()["status"] == "CONFIRMED"

    # Record withdrawal of 200
    with_res = client.post(
        "/api/v1/trading-control/transactions",
        json={"transaction_type": "WITHDRAWAL", "amount": 200.0, "note": "Withdrawal to HDFC bank"},
    )
    assert with_res.status_code == 200
    assert with_res.json()["transaction_type"] == "WITHDRAWAL"
    assert with_res.json()["status"] == "CONFIRMED"

    # Fetch transaction list
    tx_list_res = client.get("/api/v1/trading-control/transactions")
    assert tx_list_res.status_code == 200
    txs = tx_list_res.json()
    assert len(txs) >= 2


def test_groww_renew_and_verify(client):
    # Verify Groww status
    verify_res = client.get("/api/v1/groww/verify")
    assert verify_res.status_code == 200
    vdata = verify_res.json()
    assert "account_id" in vdata
    assert "auth_status" in vdata

    # Renew session
    renew_res = client.post("/api/v1/groww/renew")
    assert renew_res.status_code == 200
    rdata = renew_res.json()
    assert "auth_status" in rdata


def test_trade_alert_reject_and_approve(client):
    db = SessionLocal()
    # Create test pending trade alert
    alert = AlertHistory(
        symbol="TCS",
        exchange="NSE",
        alert_type="TRADE_ALERT",
        title="PERSONAL AI STOCK — TRADE ALERT: BUY TCS",
        message="Stock: TCS\nAction: BUY\nSuggested investment: ₹100\nEstimated quantity: 1 shares",
        price=100.0,
        action="BUY",
        suggested_investment=100.0,
        estimated_quantity=1,
        estimated_order_value=100.0,
        reason="AI analysis and market signals",
        risk_level="Medium",
        stop_loss=95.0,
        target=110.0,
        status="PENDING_APPROVAL",
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    alert_id = alert.id
    db.close()

    # Reject alert test
    reject_res = client.post(
        f"/api/v1/alerts/trade-alerts/{alert_id}/respond",
        json={"action": "REJECT"},
    )
    assert reject_res.status_code == 200
    assert reject_res.json()["status"] == "REJECTED"

    # Create another alert for approve test
    db2 = SessionLocal()
    alert2 = AlertHistory(
        symbol="INFY",
        exchange="NSE",
        alert_type="TRADE_ALERT",
        title="PERSONAL AI STOCK — TRADE ALERT: BUY INFY",
        message="Stock: INFY\nAction: BUY\nSuggested investment: ₹100\nEstimated quantity: 1 shares",
        price=100.0,
        action="BUY",
        suggested_investment=100.0,
        estimated_quantity=1,
        estimated_order_value=100.0,
        reason="AI analysis and market signals",
        risk_level="Medium",
        stop_loss=96.0,
        target=108.0,
        status="PENDING_APPROVAL",
    )
    db2.add(alert2)
    db2.commit()
    db2.refresh(alert2)
    alert2_id = alert2.id
    db2.close()

    # Approve alert test
    approve_res = client.post(
        f"/api/v1/alerts/trade-alerts/{alert2_id}/respond",
        json={"action": "APPROVE", "confirmed_price": 100.0},
    )
    assert approve_res.status_code == 200
    appr_data = approve_res.json()
    assert appr_data["success"] is True
    assert appr_data["status"] == "EXECUTED"
    assert "order_id" in appr_data
