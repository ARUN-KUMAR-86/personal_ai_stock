"""Integration tests for FastAPI endpoints."""

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check_endpoint():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "configured_provider" in data


def test_market_status_endpoint():
    response = client.get("/api/v1/market-status")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert data["exchange"] == "NSE"


def test_stock_universe_endpoint():
    response = client.get("/api/v1/stocks/universe")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0
    assert "symbol" in data[0]


def test_auth_login_endpoint():
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "owner", "password": "SecureOwnerPass123!"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_portfolio_summary_endpoint():
    response = client.get("/api/v1/portfolio/summary")
    assert response.status_code == 200
    data = response.json()
    assert "total_portfolio_value" in data
    assert "positions" in data


def test_groww_status_endpoint():
    response = client.get("/api/v1/groww/status")
    assert response.status_code == 200
    data = response.json()
    assert data["broker"] == "GROWW"
    assert data["order_execution_enabled"] is False  # Safe default


def test_cloud_root_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


def test_scanner_schedule_endpoints():
    # 1. Check schedule status
    status_res = client.get("/api/v1/scanner/schedule/status")
    assert status_res.status_code == 200
    assert "auto_scan_active" in status_res.json()

    # 2. Start schedule
    start_res = client.post("/api/v1/scanner/schedule/start?interval_minutes=30")
    assert start_res.status_code == 200
    start_data = start_res.json()
    assert start_data["status"] == "SCHEDULED"
    assert start_data["interval_minutes"] == 30

    # Verify status changed
    status_res2 = client.get("/api/v1/scanner/schedule/status")
    assert status_res2.status_code == 200
    assert status_res2.json()["auto_scan_active"] is True
    assert status_res2.json()["interval_minutes"] == 30

    # 3. Stop schedule
    stop_res = client.post("/api/v1/scanner/schedule/stop")
    assert stop_res.status_code == 200
    assert stop_res.json()["status"] == "STOPPED"

    # Verify status changed
    status_res3 = client.get("/api/v1/scanner/schedule/status")
    assert status_res3.status_code == 200
    assert status_res3.json()["auto_scan_active"] is False

