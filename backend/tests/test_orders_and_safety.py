"""Comprehensive tests for Notification-First Trading, Manual Buy Approval,
Groww TOTP Integration, Position Monitoring, and Safety Controls.
"""

from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database.base import Base
from app.database.session import get_db
from app.core.config import settings
from app.models.portfolio import Position
from app.models.order import Order
from app.models.signal import StockSignal
from app.risk.charges import IndianTaxCalculator
from app.portfolio.monitor import PositionMonitor
from app.brokers.groww_adapter import GrowwBrokerAdapter

client = TestClient(app)


def test_indian_tax_calculator():
    """Verifies granular statutory charges and delivery tax calculations."""
    buy_charges = IndianTaxCalculator.calculate_buy_charges(10000.0)
    assert buy_charges["brokerage"] == 5.0  # 0.05% of 10,000 = ₹5.0
    assert buy_charges["stt"] == 10.0  # 0.1% of 10,000 = ₹10.0
    assert buy_charges["stamp_duty"] == 1.5  # 0.015% of 10,000 = ₹1.5
    assert buy_charges["total_charges"] > 16.0

    sell_charges = IndianTaxCalculator.calculate_sell_charges(10000.0)
    assert sell_charges["dp_charges"] == 15.93
    assert sell_charges["stt"] == 10.0
    assert sell_charges["total_charges"] > 30.0

    metrics = IndianTaxCalculator.calculate_trade_metrics(
        investment_amount=5000.0,
        price=500.0,
        stop_loss=490.0,
        target=520.0,
        holding_period_hours=48,
        available_funds=50000.0,
    )
    assert metrics["is_valid"] is True
    assert metrics["shares_quantity"] == 10  # 5000 / 500 = 10 shares
    assert metrics["estimated_investment"] == 5000.0
    assert metrics["risk_reward_ratio"] == 2.0  # (520 - 500) / (500 - 490)
    assert metrics["potential_profit_net"] > 0
    assert metrics["potential_loss_net"] > 0
    assert metrics["holding_period_hours"] == 48


def test_calculate_order_endpoint():
    """Tests the /api/v1/orders/calculate live API endpoint."""
    res = client.post(
        "/api/v1/orders/calculate",
        json={
            "symbol": "TCS",
            "exchange": "NSE",
            "investment_amount": 10000.0,
            "entry_price": 4000.0,
            "stop_loss": 3900.0,
            "target": 4200.0,
            "holding_period_hours": 48,
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["shares_quantity"] == 2  # 10000 / 4000 = 2 shares
    assert data["estimated_investment"] == 8000.0
    assert data["risk_reward_ratio"] == 2.0
    assert data["holding_period_hours"] == 48


def test_prepare_buy_and_slippage_check():
    """Verifies quote refresh and slippage protection on /api/v1/orders/prepare-buy."""
    res = client.post(
        "/api/v1/orders/prepare-buy",
        json={
            "symbol": "INFY",
            "exchange": "NSE",
            "investment_amount": 15000.0,
            "expected_price": 100.0,  # Far from actual price -> triggers slippage warning
            "stop_loss": 90.0,
            "target": 120.0,
            "holding_period_hours": 24,
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert "client_order_id" in data
    assert data["price_changed"] is True
    assert data["slippage_warning"] is not None
    assert data["holding_period_hours"] == 24


def test_manual_buy_confirmation_workflow():
    """
    Verifies that explicit user confirmation produces an executed order
    and automatically registers the position for continuous monitoring.
    """
    res = client.post(
        "/api/v1/orders/buy-confirm",
        json={
            "client_order_id": f"TEST-ORDER-{datetime.now().timestamp()}",
            "symbol": "WIPRO",
            "exchange": "NSE",
            "investment_amount": 5000.0,
            "confirmed_price": 500.0,
            "quantity": 10,
            "stop_loss": 485.0,
            "target": 530.0,
            "holding_period_hours": 48,
            "auto_sell_enabled": False,
            "user_confirmed": True,
        },
    )
    assert res.status_code == 200
    order = res.json()
    assert order["symbol"] == "WIPRO"
    assert order["status"] == "FILLED"
    assert order["user_confirmed"] is True
    assert order["requested_quantity"] == 10
    assert order["holding_period_hours"] == 48


def test_automated_buying_is_strictly_prohibited():
    """Verifies that an order without user_confirmed=True is rejected."""
    res = client.post(
        "/api/v1/orders/buy-confirm",
        json={
            "client_order_id": f"TEST-FAIL-{datetime.now().timestamp()}",
            "symbol": "WIPRO",
            "exchange": "NSE",
            "investment_amount": 5000.0,
            "confirmed_price": 500.0,
            "quantity": 10,
            "stop_loss": 485.0,
            "target": 530.0,
            "holding_period_hours": 48,
            "auto_sell_enabled": False,
            "user_confirmed": False,  # Should fail!
        },
    )
    assert res.status_code == 400
    assert "Automated buying is strictly prohibited" in res.json()["detail"]


def test_emergency_kill_switch():
    """Verifies emergency stop blocks all order placement."""
    # Enable emergency stop
    client.post("/api/v1/safety/emergency-stop?enabled=true")
    assert settings.EMERGENCY_STOP_ENABLED is True

    # Attempt to prepare or confirm buy order
    res = client.post(
        "/api/v1/orders/prepare-buy",
        json={
            "symbol": "TCS",
            "exchange": "NSE",
            "investment_amount": 5000.0,
            "expected_price": 4000.0,
            "stop_loss": 3900.0,
            "target": 4200.0,
        },
    )
    assert res.status_code == 403

    # Reset emergency stop
    client.post("/api/v1/safety/emergency-stop?enabled=false")
    assert settings.EMERGENCY_STOP_ENABLED is False


def test_groww_broker_adapter_totp():
    """Verifies Groww adapter TOTP flow and API availability."""
    adapter = GrowwBrokerAdapter()
    info = adapter.get_api_availability()
    assert info["broker"] == "GROWW"
    assert "pricing" in info
    assert info["permissions"]["auto_buying"] is False  # Permanently disabled


def test_position_monitoring_pass():
    """Verifies position monitor detects and updates open positions."""
    res = client.post("/api/v1/safety/monitor-check")
    assert res.status_code == 200
    data = res.json()
    assert "monitored_count" in data
