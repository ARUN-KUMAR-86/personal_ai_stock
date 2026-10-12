"""Tests for User-Managed Persistent Watchlist API."""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_watchlist_crud_lifecycle():
    symbol = "TATAMOTORS"

    # 1. Add to watchlist
    add_resp = client.post(f"/api/v1/watchlist/{symbol}?exchange=NSE&notes=High%20conviction%20EV%20play")
    assert add_resp.status_code == 200
    data = add_resp.json()
    assert data["symbol"] == symbol
    assert data["notes"] == "High conviction EV play"

    # 2. Check if watchlisted
    check_resp = client.get(f"/api/v1/watchlist/check/{symbol}?exchange=NSE")
    assert check_resp.status_code == 200
    assert check_resp.json()["is_watchlisted"] is True

    # 3. List watchlist
    list_resp = client.get("/api/v1/watchlist?exchange=NSE")
    assert list_resp.status_code == 200
    items = list_resp.json()
    assert any(it["symbol"] == symbol for it in items)

    # 4. Remove from watchlist
    del_resp = client.delete(f"/api/v1/watchlist/{symbol}?exchange=NSE")
    assert del_resp.status_code == 200
    assert del_resp.json()["removed"] is True

    # 5. Check if watchlisted now false
    check_again = client.get(f"/api/v1/watchlist/check/{symbol}?exchange=NSE")
    assert check_again.status_code == 200
    assert check_again.json()["is_watchlisted"] is False


def test_watchlist_scan():
    # Add a stock
    client.post("/api/v1/watchlist/RELIANCE?exchange=NSE")

    # Trigger watchlist scan
    scan_resp = client.post("/api/v1/watchlist/scan?exchange=NSE&force=true")
    assert scan_resp.status_code == 200
    res = scan_resp.json()
    assert "Watchlist scan executed" in res["message"]
