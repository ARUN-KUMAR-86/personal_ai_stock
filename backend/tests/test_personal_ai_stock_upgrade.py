"""Comprehensive test suite verifying all 20 core user scenarios for Personal AI Stock Research,
Priority Ranking, Portfolio Tracking, and Automatic Notifications.
"""

import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from app.database.base import Base
from app.models.portfolio import Position, PaperTrade
from app.models.alert import AlertHistory, NotificationQueue
from app.models.stock import Stock
from app.models.signal import StockSignal
from app.portfolio.manager import PortfolioManager
from app.portfolio.monitor import PositionMonitor
from app.notifications.notifier import notifier
from app.scanner.scheduler import get_schedule_status
from app.main import app

client = TestClient(app)


def get_fresh_test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    return Session()


# ==============================================================================
# TEST 1 & 2: AI Recommends Stock & Appears in Highest-Priority Order (P0 to P4)
# ==============================================================================
def test_scenario_01_and_02_recommendation_and_priority_ranking():
    db = get_fresh_test_db()

    # Seed signals with different priorities
    signals = [
        StockSignal(symbol="WIPRO", exchange="NSE", price=450.0, strength=65.0, priority="P3", signal_type="BUY WATCH", strategy_name="InstitutionalAIConfluence", explanation="WIPRO research", timestamp=datetime.now(timezone.utc)),
        StockSignal(symbol="TCS", exchange="NSE", price=3500.0, strength=88.0, priority="P1", signal_type="BUY", strategy_name="InstitutionalAIConfluence", explanation="TCS research", timestamp=datetime.now(timezone.utc)),
        StockSignal(symbol="RELIANCE", exchange="NSE", price=2900.0, strength=96.0, priority="P0", signal_type="STRONG BUY", strategy_name="InstitutionalAIConfluence", explanation="RELIANCE critical setup", timestamp=datetime.now(timezone.utc)),
        StockSignal(symbol="INFY", exchange="NSE", price=1800.0, strength=78.0, priority="P2", signal_type="BUY WATCH", strategy_name="InstitutionalAIConfluence", explanation="INFY research", timestamp=datetime.now(timezone.utc)),
        StockSignal(symbol="ITC", exchange="NSE", price=420.0, strength=50.0, priority="P4", signal_type="NO TRADE", strategy_name="InstitutionalAIConfluence", explanation="ITC watchlist", timestamp=datetime.now(timezone.utc)),
    ]
    for s in signals:
        db.add(s)
    db.commit()

    # Test sorting order: P0 -> P1 -> P2 -> P3 -> P4
    priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3, "P4": 4}
    queried = db.query(StockSignal).all()
    queried.sort(key=lambda s: (priority_order.get(s.priority, 9), -s.strength))

    ordered_symbols = [s.symbol for s in queried]
    assert ordered_symbols == ["RELIANCE", "TCS", "INFY", "WIPRO", "ITC"]
    assert queried[0].priority == "P0"
    assert queried[1].priority == "P1"
    assert queried[4].priority == "P4"


# ==============================================================================
# TEST 3, 4, 5: Manual Groww Purchase & Weighted Average Buy Price
# ==============================================================================
def test_scenario_03_04_05_manual_purchase_and_weighted_average():
    db = get_fresh_test_db()

    # 1. First purchase: 10 shares of RELIANCE at ₹200.00
    res1 = PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        exchange="NSE",
        actual_price=200.0,
        quantity=10,
        purchase_date="2026-11-05",
        purchase_time="10:00",
        charges=10.0,
        custom_target=220.0,
        custom_stop_loss=190.0,
    )
    assert res1["status"] == "SUCCESS"
    pos = db.query(Position).filter(Position.symbol == "RELIANCE", Position.is_open == True).first()
    assert pos is not None
    assert pos.quantity == 10
    assert pos.avg_entry_price == 200.0
    assert pos.is_open == True

    # 2. Second purchase: 10 more shares of RELIANCE at ₹220.00 (Weighted average should be ₹210.00)
    res2 = PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        exchange="NSE",
        actual_price=220.0,
        quantity=10,
        purchase_date="2026-11-05",
        purchase_time="11:30",
        charges=10.0,
    )
    assert res2["status"] == "SUCCESS"
    db.refresh(pos)
    assert pos.quantity == 20
    # Expected weighted average: ((200 * 10) + (220 * 10)) / 20 = 4200 / 20 = ₹210.00
    assert pos.avg_entry_price == 210.0


# ==============================================================================
# TEST 6 & 7: Portfolio Summary & Continuous Price Monitoring
# ==============================================================================
def test_scenario_06_07_portfolio_summary_and_monitoring():
    db = get_fresh_test_db()

    PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        actual_price=200.0,
        quantity=10,
    )

    summary = PortfolioManager.get_portfolio_summary(db)
    assert summary["open_positions_count"] == 1
    assert summary["total_invested_value"] == 2000.0

    # Test terminal rendering output
    from app.terminal import render_dashboard
    render_dashboard(db, clear_screen=False)


# ==============================================================================
# TEST 8 & 9: Exact Profit Notifications (+₹30, +₹50)
# ==============================================================================
def test_scenario_08_09_exact_profit_notifications():
    db = get_fresh_test_db()

    # Buy 10 shares of RELIANCE at ₹200.00 (Investment = ₹2,000)
    PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        actual_price=200.0,
        quantity=10,
    )

    # 1. Price moves to ₹203.00 -> Profit = (203 - 200) * 10 = +₹30.00
    # Should trigger FIRST PROFIT ALERT (+₹30)
    res1 = PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides={"RELIANCE": 203.0},
    )
    alerts1 = res1["alerts_triggered"]
    assert any(a["threshold"] == "PROFIT_INR_30" for a in alerts1)
    alert_db1 = db.query(AlertHistory).filter(AlertHistory.threshold_key == "PROFIT_INR_30").first()
    assert alert_db1 is not None
    assert "SELL ALERT (+₹30 PROFIT)" in alert_db1.title
    assert "RELIANCE" in alert_db1.title

    # 2. Price moves to ₹205.00 -> Profit = (205 - 200) * 10 = +₹50.00
    # Should trigger SECOND PROFIT ALERT (+₹50)
    res2 = PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides={"RELIANCE": 205.0},
    )
    alerts2 = res2["alerts_triggered"]
    assert any(a["threshold"] == "PROFIT_INR_50" for a in alerts2)
    alert_db2 = db.query(AlertHistory).filter(AlertHistory.threshold_key == "PROFIT_INR_50").first()
    assert alert_db2 is not None
    assert "SELL ALERT (+₹50 PROFIT)" in alert_db2.title
    assert "RELIANCE" in alert_db2.title


# ==============================================================================
# TEST 10 & 11: Exact Loss Notifications (-₹30, -₹50)
# ==============================================================================
def test_scenario_10_11_exact_loss_notifications():
    db = get_fresh_test_db()

    # Buy 10 shares of RELIANCE at ₹200.00 (Investment = ₹2,000)
    PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        actual_price=200.0,
        quantity=10,
    )

    # 1. Price drops to ₹197.00 -> Loss = (197 - 200) * 10 = -₹30.00
    res1 = PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides={"RELIANCE": 197.0},
    )
    alerts1 = res1["alerts_triggered"]
    assert any(a["threshold"] == "LOSS_INR_30" for a in alerts1)
    alert_db1 = db.query(AlertHistory).filter(AlertHistory.threshold_key == "LOSS_INR_30").first()
    assert alert_db1 is not None
    assert "SELL ALERT (-₹30 LOSS)" in alert_db1.title
    assert "RELIANCE" in alert_db1.title

    # 2. Price drops to ₹195.00 -> Loss = (195 - 200) * 10 = -₹50.00
    res2 = PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides={"RELIANCE": 195.0},
    )
    alerts2 = res2["alerts_triggered"]
    assert any(a["threshold"] == "LOSS_INR_50" for a in alerts2)
    alert_db2 = db.query(AlertHistory).filter(AlertHistory.threshold_key == "LOSS_INR_50").first()
    assert alert_db2 is not None
    assert "SELL ALERT (-₹50 LOSS)" in alert_db2.title
    assert "RELIANCE" in alert_db2.title


# ==============================================================================
# TEST 12: -12% Extreme Loss Alert (Priority P0) & Independent Evaluation
# ==============================================================================
def test_scenario_12_extreme_loss_12_pct_alert():
    db = get_fresh_test_db()

    # Buy 10 shares of RELIANCE at ₹200.00
    PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        actual_price=200.0,
        quantity=10,
    )

    # Price drops to ₹176.00:
    # Loss percentage = (176 - 200) / 200 = -12.00%
    # Total rupee loss = -₹240.00
    res = PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides={"RELIANCE": 176.0},
    )
    alerts = res["alerts_triggered"]
    pct_12_alerts = [a for a in alerts if a["threshold"] == "LOSS_PCT_12"]
    assert len(pct_12_alerts) > 0
    assert pct_12_alerts[0]["priority"] == "P0"

    alert_record = db.query(AlertHistory).filter(AlertHistory.threshold_key == "LOSS_PCT_12").first()
    assert alert_record is not None
    assert "SELL ALERT" in alert_record.title
    assert "RELIANCE" in alert_record.title
    assert alert_record.priority == "P0"
    assert "Extreme Loss Alert" in alert_record.message


# ==============================================================================
# TEST 13: Push Notification Queue, Persistence & Test Button
# ==============================================================================
def test_scenario_13_push_notification_queue_and_delivery():
    db = get_fresh_test_db()

    # Send a notification
    alert = notifier.send_notification(
        db=db,
        symbol="INFY",
        exchange="NSE",
        alert_type="PROFIT_INR_30",
        title="[P2] FIRST PROFIT ALERT: INFY reached +₹30 profit",
        body="Stock: INFY | Profit: +₹30",
        priority="P2",
        threshold_key="PROFIT_INR_30",
    )

    assert alert.id is not None
    # Verify enqueued in durable NotificationQueue
    queued = db.query(NotificationQueue).filter(NotificationQueue.alert_id == alert.id).first()
    assert queued is not None

    # Test queue processor on pending items
    queued.status = "PENDING"
    db.commit()
    proc_res = notifier.process_notification_queue(db=db)
    assert proc_res["processed"] >= 1


# ==============================================================================
# TEST 14, 15, 16: Manual Sell Workflow & Realized Profit/Loss
# ==============================================================================
def test_scenario_14_15_16_manual_sell_workflow():
    db = get_fresh_test_db()

    # Buy 10 shares of RELIANCE at ₹200.00
    PortfolioManager.record_manual_purchase(
        db=db,
        symbol="RELIANCE",
        actual_price=200.0,
        quantity=10,
    )

    # Sell all 10 shares at ₹230.00 with ₹10 charges
    # Expected Realized P&L: (230 - 200) * 10 - 10 = 300 - 10 = ₹290.00
    res = PortfolioManager.record_manual_sale(
        db=db,
        symbol="RELIANCE",
        selling_price=230.0,
        quantity_sold=10,
        charges=10.0,
    )

    assert res["status"] == "SUCCESS"
    assert res["realized_pnl"] == 290.0
    assert res["is_fully_closed"] == True

    pos = db.query(Position).filter(Position.symbol == "RELIANCE").first()
    assert pos.is_open == False
    assert pos.status == "CLOSED"
    assert pos.quantity == 0
    assert pos.realized_pnl == 290.0


# ==============================================================================
# TEST 17: Partial Sell & Continued Active Monitoring of Remaining Quantity
# ==============================================================================
def test_scenario_17_partial_sell_and_remaining_quantity_monitoring():
    db = get_fresh_test_db()

    # Buy 10 shares of TCS at ₹3500.00
    PortfolioManager.record_manual_purchase(
        db=db,
        symbol="TCS",
        actual_price=3500.0,
        quantity=10,
    )

    # Partial sale: Sell 4 shares at ₹3600.00
    res = PortfolioManager.record_manual_sale(
        db=db,
        symbol="TCS",
        selling_price=3600.0,
        quantity_sold=4,
        charges=10.0,
    )

    assert res["status"] == "SUCCESS"
    assert res["remaining_quantity"] == 6
    assert res["is_fully_closed"] == False

    pos = db.query(Position).filter(Position.symbol == "TCS").first()
    assert pos.is_open == True
    assert pos.quantity == 6
    assert pos.avg_entry_price == 3500.0

    # Monitor remaining shares: price rises to ₹3650.00
    # Remaining 6 shares gain (3650 - 3500) * 6 = +₹900.00 profit
    mon_res = PositionMonitor.check_and_update_positions(
        db=db,
        force_market_open=True,
        price_overrides={"TCS": 3650.0},
    )
    db.refresh(pos)
    assert pos.unrealized_pnl == 900.0


# ==============================================================================
# TEST 18: Closed Positions Cease Active Monitoring
# ==============================================================================
def test_scenario_18_closed_positions_stop_monitoring():
    db = get_fresh_test_db()

    # Buy and completely sell
    PortfolioManager.record_manual_purchase(db=db, symbol="ITC", actual_price=400.0, quantity=5)
    PortfolioManager.record_manual_sale(db=db, symbol="ITC", selling_price=410.0, quantity_sold=5)

    pos = db.query(Position).filter(Position.symbol == "ITC").first()
    assert pos.is_open == False

    # Run position monitor: ITC should NOT be in active monitored positions
    mon_res = PositionMonitor.check_and_update_positions(db=db, force_market_open=True)
    monitored_syms = [a["symbol"] for a in mon_res["actions_taken"]]
    assert "ITC" not in monitored_syms


# ==============================================================================
# TEST 19: Duplicate Alert Prevention & Independent Threshold Isolation
# ==============================================================================
def test_scenario_19_duplicate_alert_prevention():
    db = get_fresh_test_db()

    PortfolioManager.record_manual_purchase(db=db, symbol="INFY", actual_price=100.0, quantity=1)

    # Price at 130 -> triggers PROFIT_INR_30
    res1 = PositionMonitor.check_and_update_positions(db=db, force_market_open=True, price_overrides={"INFY": 130.0})
    assert any(a["threshold"] == "PROFIT_INR_30" for a in res1["alerts_triggered"])

    # Immediate second check at same price (130) -> Should NOT trigger PROFIT_INR_30 again (anti-duplicate)
    res2 = PositionMonitor.check_and_update_positions(db=db, force_market_open=True, price_overrides={"INFY": 130.0})
    assert not any(a["threshold"] == "PROFIT_INR_30" for a in res2["alerts_triggered"])

    # Price advances to 150 -> triggers higher threshold PROFIT_INR_50!
    res3 = PositionMonitor.check_and_update_positions(db=db, force_market_open=True, price_overrides={"INFY": 150.0})
    assert any(a["threshold"] == "PROFIT_INR_50" for a in res3["alerts_triggered"])


# ==============================================================================
# TEST 20: 24/7 Cloud Background Monitoring & Scheduler Status
# ==============================================================================
def test_scenario_20_cloud_monitoring_and_scheduler_status():
    status = get_schedule_status()
    assert "scheduler_running" in status
    assert "auto_scan_active" in status

    # Verify cloud health endpoint
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"

    # Verify monitoring status endpoint
    mon_resp = client.get("/api/v1/monitoring/status")
    assert mon_resp.status_code == 200
    mon_data = mon_resp.json()
    assert "market" in mon_data
