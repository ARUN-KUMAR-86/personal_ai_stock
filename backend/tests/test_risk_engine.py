"""Unit tests for Risk Management Engine."""

import pytest
from app.risk.engine import RiskEngine
from app.core.exceptions import RiskCheckFailedError


def test_position_sizing_calculation():
    # Capital: 1,00,000 INR, Entry: 1000, Stop Loss: 950 (Risk = 50 per share)
    # 2% Risk = 2000 INR -> 2000 / 50 = 40 shares
    res = RiskEngine.calculate_position_size(
        total_capital=100000.0,
        entry_price=1000.0,
        stop_loss=950.0,
        risk_per_trade_pct=2.0,
    )

    assert res["quantity"] > 0
    assert res["entry_price"] == 1000.0
    assert res["stop_loss"] == 950.0
    assert res["risk_amount"] <= 2000.0


def test_invalid_stop_loss_raises_error():
    with pytest.raises(RiskCheckFailedError):
        # Stop loss above entry should fail
        RiskEngine.calculate_position_size(
            total_capital=100000.0,
            entry_price=1000.0,
            stop_loss=1050.0,
        )


def test_risk_reward_validation():
    # Valid 2:1 RR
    valid, rr, msg = RiskEngine.validate_risk_reward(
        entry_price=100.0,
        stop_loss=90.0,
        target=120.0,
    )
    assert valid is True
    assert rr == 2.0

    # Invalid poor RR (0.5:1)
    invalid, rr_poor, _ = RiskEngine.validate_risk_reward(
        entry_price=100.0,
        stop_loss=90.0,
        target=105.0,
    )
    assert invalid is False
    assert rr_poor == 0.5
