"""Unit tests for Portfolio Management and Paper Trading."""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database.base import Base
from app.models.portfolio import Position, PaperTrade
from app.portfolio.manager import PortfolioManager


def get_test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    return Session()


def test_paper_trade_buy_and_sell():
    db = get_test_db()

    # 1. Buy 10 shares of RELIANCE at 2800
    trade = PortfolioManager.execute_paper_trade(
        db=db,
        symbol="RELIANCE",
        exchange="NSE",
        action="BUY",
        quantity=10,
        price=2800.0,
        reason="Test buy",
    )
    assert trade.action == "BUY"
    assert trade.quantity == 10
    assert trade.price == 2800.0

    # Verify open position
    pos = db.query(Position).filter(Position.symbol == "RELIANCE", Position.is_open == True).first()
    assert pos is not None
    assert pos.quantity == 10
    assert pos.avg_entry_price == 2800.0

    # 2. Sell 5 shares at 2900 (profit)
    sell_trade = PortfolioManager.execute_paper_trade(
        db=db,
        symbol="RELIANCE",
        exchange="NSE",
        action="SELL",
        quantity=5,
        price=2900.0,
        reason="Test partial exit",
    )
    assert sell_trade.action == "SELL"
    assert sell_trade.pnl > 0  # 100 profit per share minus fees

    # Verify remaining position
    db.refresh(pos)
    assert pos.quantity == 5
    assert pos.is_open == True


def test_ultra_sync_endpoint():
    from fastapi.testclient import TestClient
    from app.main import app
    client = TestClient(app)
    response = client.get("/api/v1/portfolio/ultra-sync?run_auto_sell=true")
    assert response.status_code == 200
    data = response.json()
    assert "timestamp" in data
    assert "latency_benchmark_ms" in data
    assert "portfolio" in data
    assert "available_funds" in data
    assert "recent_trades" in data
    assert isinstance(data["recent_trades"], list)


def test_ultra_trade_endpoint():
    from fastapi.testclient import TestClient
    from app.main import app
    client = TestClient(app)
    payload = {
        "symbol": "INFY",
        "exchange": "NSE",
        "action": "BUY",
        "quantity": 2,
        "price": 1500.0,
        "reason": "UltraTrade Unit Test",
        "stop_loss": 1400.0,
        "target": 1650.0,
        "holding_period_hours": 48,
        "auto_sell_enabled": True,
    }
    response = client.post("/api/v1/portfolio/ultra-trade", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "EXECUTED"
    assert data["trade"]["symbol"] == "INFY"
    assert data["trade"]["quantity"] == 2
    assert "portfolio" in data


def test_delete_position():
    db = get_test_db()
    trade = PortfolioManager.execute_paper_trade(
        db=db,
        symbol="AAPL",
        exchange="US",
        action="BUY",
        quantity=5,
        price=180.0,
        reason="Test buy AAPL",
    )
    pos = db.query(Position).filter(Position.symbol == "AAPL", Position.is_open == True).first()
    assert pos is not None

    # Delete position
    res = PortfolioManager.delete_position(db=db, position_id=pos.id)
    assert res["status"] == "SUCCESS"
    assert res["deleted_position_id"] == pos.id

    # Verify deleted
    deleted_pos = db.query(Position).filter(Position.id == pos.id).first()
    assert deleted_pos is None


def test_manual_sale_with_position_id():
    db = get_test_db()
    trade = PortfolioManager.execute_paper_trade(
        db=db,
        symbol="NVDA",
        exchange="NASDAQ",
        action="BUY",
        quantity=10,
        price=120.0,
        reason="Test buy NVDA",
    )
    pos = db.query(Position).filter(Position.symbol == "NVDA", Position.is_open == True).first()
    assert pos is not None

    # Sell with position_id and exchange alias "US"
    res = PortfolioManager.record_manual_sale(
        db=db,
        position_id=pos.id,
        symbol="NVDA",
        exchange="US",
        selling_price=130.0,
        quantity_sold=10,
    )
    assert res["status"] == "SUCCESS"
    assert res["realized_pnl"] == 100.0  # (130 - 120) * 10
    assert res["remaining_quantity"] == 0
