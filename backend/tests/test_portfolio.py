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
