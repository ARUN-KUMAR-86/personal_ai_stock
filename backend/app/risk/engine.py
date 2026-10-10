"""Risk Management and Position Sizing Engine."""

from typing import Dict, Any, Tuple
from app.core.config import settings
from app.core.exceptions import RiskCheckFailedError


class RiskEngine:
    """Enforces strict capital preservation and risk sizing rules."""

    @staticmethod
    def calculate_position_size(
        total_capital: float,
        entry_price: float,
        stop_loss: float,
        risk_per_trade_pct: float = settings.MAX_POSITION_RISK_PCT,
    ) -> Dict[str, Any]:
        """
        Calculates recommended position size using fixed-fractional risk sizing.
        Formula:
          Risk Amount = Total Capital * (risk_per_trade_pct / 100)
          Risk Per Share = Entry Price - Stop Loss
          Max Quantity = Risk Amount / Risk Per Share
        """
        if entry_price <= 0 or stop_loss <= 0:
            raise RiskCheckFailedError("Entry price and stop loss must be greater than zero.")

        if stop_loss >= entry_price:
            raise RiskCheckFailedError("Stop loss must be below entry price for long positions.")

        risk_amount = total_capital * (risk_per_trade_pct / 100.0)
        risk_per_share = entry_price - stop_loss
        raw_quantity = risk_amount / risk_per_share
        quantity = max(1, int(raw_quantity))

        total_position_value = quantity * entry_price
        max_allowed_stock_value = total_capital * (settings.MAX_SINGLE_STOCK_PCT / 100.0)

        # Cap by single stock concentration limit
        if total_position_value > max_allowed_stock_value:
            quantity = max(1, int(max_allowed_stock_value / entry_price))
            total_position_value = quantity * entry_price

        actual_risk = quantity * risk_per_share

        return {
            "quantity": quantity,
            "entry_price": round(entry_price, 2),
            "stop_loss": round(stop_loss, 2),
            "risk_amount": round(actual_risk, 2),
            "risk_pct_of_capital": round((actual_risk / total_capital) * 100, 2),
            "total_investment": round(total_position_value, 2),
            "portfolio_allocation_pct": round((total_position_value / total_capital) * 100, 2),
        }

    @staticmethod
    def validate_risk_reward(entry_price: float, stop_loss: float, target: float) -> Tuple[bool, float, str]:
        """Validates if the signal meets the minimum risk/reward ratio threshold."""
        risk = entry_price - stop_loss
        reward = target - entry_price

        if risk <= 0:
            return False, 0.0, "Invalid stop loss level."

        rr_ratio = round(reward / risk, 2)
        if rr_ratio < settings.MIN_RISK_REWARD_RATIO:
            return (
                False,
                rr_ratio,
                f"Risk/reward ratio {rr_ratio} is below required minimum of {settings.MIN_RISK_REWARD_RATIO}",
            )

        return True, rr_ratio, "Risk/reward acceptable."

    @staticmethod
    def check_portfolio_risk(
        total_capital: float,
        current_invested_value: float,
        proposed_investment: float,
    ) -> Tuple[bool, str]:
        """Checks overall portfolio exposure."""
        new_total_invested = current_invested_value + proposed_investment
        exposure_pct = (new_total_invested / total_capital) * 100.0

        if exposure_pct > settings.MAX_PORTFOLIO_EXPOSURE_PCT:
            return (
                False,
                f"Proposed trade would cause total portfolio exposure ({round(exposure_pct, 1)}%) "
                f"to exceed safety limit of {settings.MAX_PORTFOLIO_EXPOSURE_PCT}%.",
            )
        return True, "Portfolio exposure within risk limit."
