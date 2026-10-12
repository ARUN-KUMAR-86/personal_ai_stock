"""Indian Equity Delivery Transaction Charges & Tax Calculator.

Accurately models Indian statutory and brokerage levies:
1. Brokerage: min(₹20, 0.05% of turnover)
2. STT (Securities Transaction Tax): 0.1% on Buy & Sell turnover
3. Exchange Transaction Charges (NSE): 0.00297%
4. SEBI Turnover Charges: ₹10 per crore (0.0001%)
5. Stamp Duty: 0.015% (Buy side only)
6. GST: 18% on (Brokerage + Exchange Charges + SEBI Charges)
7. DP Charges: ₹15.93 (₹13.5 + 18% GST) on Sell side only
"""

from typing import Dict, Any, List, Optional
from app.core.config import settings


class IndianTaxCalculator:
    """Calculates granular Indian equity delivery charges, taxes, and trade metrics."""

    @staticmethod
    def calculate_buy_charges(trade_value: float) -> Dict[str, float]:
        if trade_value <= 0:
            return {
                "brokerage": 0.0,
                "stt": 0.0,
                "exchange_charges": 0.0,
                "sebi_charges": 0.0,
                "stamp_duty": 0.0,
                "gst": 0.0,
                "total_charges": 0.0,
            }

        brokerage = round(min(20.0, trade_value * 0.0005), 2)
        stt = round(trade_value * 0.001, 2)  # 0.1%
        exchange_charges = round(trade_value * 0.0000297, 2)
        sebi_charges = round(trade_value * 0.000001, 2)
        stamp_duty = round(trade_value * 0.00015, 2)  # 0.015%
        gst = round((brokerage + exchange_charges + sebi_charges) * 0.18, 2)  # 18%
        total = round(brokerage + stt + exchange_charges + sebi_charges + stamp_duty + gst, 2)

        return {
            "brokerage": brokerage,
            "stt": stt,
            "exchange_charges": exchange_charges,
            "sebi_charges": sebi_charges,
            "stamp_duty": stamp_duty,
            "gst": gst,
            "total_charges": total,
        }

    @staticmethod
    def calculate_sell_charges(trade_value: float) -> Dict[str, float]:
        if trade_value <= 0:
            return {
                "brokerage": 0.0,
                "stt": 0.0,
                "exchange_charges": 0.0,
                "sebi_charges": 0.0,
                "dp_charges": 0.0,
                "gst": 0.0,
                "total_charges": 0.0,
            }

        brokerage = round(min(20.0, trade_value * 0.0005), 2)
        stt = round(trade_value * 0.001, 2)  # 0.1%
        exchange_charges = round(trade_value * 0.0000297, 2)
        sebi_charges = round(trade_value * 0.000001, 2)
        dp_charges = 15.93  # ₹13.5 + 18% GST
        gst = round((brokerage + exchange_charges + sebi_charges) * 0.18, 2)
        total = round(brokerage + stt + exchange_charges + sebi_charges + dp_charges + gst, 2)

        return {
            "brokerage": brokerage,
            "stt": stt,
            "exchange_charges": exchange_charges,
            "sebi_charges": sebi_charges,
            "dp_charges": dp_charges,
            "gst": gst,
            "total_charges": total,
        }

    @classmethod
    def calculate_trade_metrics(
        cls,
        investment_amount: float,
        price: float,
        stop_loss: float,
        target: float,
        holding_period_hours: int = 48,
        available_funds: float = 100000.0,
        total_capital: float = 100000.0,
        current_invested_value: float = 0.0,
    ) -> Dict[str, Any]:
        """
        Dynamically recalculates all trade metrics based on user input.
        Enforces whole-share quantities, verified pricing, and configured risk limits.
        """
        warnings: List[str] = []
        is_valid = True

        if price <= 0:
            return {
                "is_valid": False,
                "error": "Price must be greater than zero.",
                "shares_quantity": 0,
                "estimated_investment": 0.0,
                "total_charges": 0.0,
                "remaining_funds": available_funds,
                "risk_reward_ratio": 0.0,
                "warnings": ["Price must be positive."],
            }

        if investment_amount <= 0:
            return {
                "is_valid": False,
                "error": "Investment amount must be greater than zero.",
                "shares_quantity": 0,
                "estimated_investment": 0.0,
                "total_charges": 0.0,
                "remaining_funds": available_funds,
                "risk_reward_ratio": 0.0,
                "warnings": ["Enter a valid investment amount."],
            }

        # Calculate whole-share quantity
        shares_quantity = int(investment_amount // price)
        if shares_quantity < 1:
            shares_quantity = 1  # Minimum 1 whole share for equity delivery
            if price > investment_amount:
                warnings.append(
                    f"Investment amount ₹{investment_amount:.2f} is below single share price ₹{price:.2f}. "
                    f"Adjusted to 1 whole share (₹{price:.2f})."
                )

        estimated_investment = round(shares_quantity * price, 2)

        # Calculate Buy and Sell charges
        buy_charges = cls.calculate_buy_charges(estimated_investment)
        target_sell_value = round(shares_quantity * target, 2) if target > 0 else estimated_investment
        target_sell_charges = cls.calculate_sell_charges(target_sell_value)

        sl_sell_value = round(shares_quantity * stop_loss, 2) if stop_loss > 0 else estimated_investment
        sl_sell_charges = cls.calculate_sell_charges(sl_sell_value)

        roundtrip_target_charges = round(buy_charges["total_charges"] + target_sell_charges["total_charges"], 2)
        roundtrip_sl_charges = round(buy_charges["total_charges"] + sl_sell_charges["total_charges"], 2)

        # Potential Profit & Loss
        potential_profit_net = round((target_sell_value - estimated_investment) - roundtrip_target_charges, 2)
        potential_profit_pct = round((potential_profit_net / estimated_investment) * 100, 2) if estimated_investment > 0 else 0.0

        potential_loss_net = round((estimated_investment - sl_sell_value) + roundtrip_sl_charges, 2)
        potential_loss_pct = round((potential_loss_net / estimated_investment) * 100, 2) if estimated_investment > 0 else 0.0

        # Risk / Reward ratio
        per_share_risk = price - stop_loss if stop_loss > 0 else 0.0
        per_share_reward = target - price if target > 0 else 0.0
        if per_share_risk > 0 and per_share_reward > 0:
            risk_reward_ratio = round(per_share_reward / per_share_risk, 2)
        else:
            risk_reward_ratio = 0.0

        if stop_loss >= price:
            is_valid = False
            warnings.append(f"Stop-loss (₹{stop_loss:.2f}) must be strictly below current entry price (₹{price:.2f}).")

        if target <= price:
            is_valid = False
            warnings.append(f"Target price (₹{target:.2f}) must be strictly above current entry price (₹{price:.2f}).")

        # Risk Limit validations
        total_outlay = round(estimated_investment + buy_charges["total_charges"], 2)
        remaining_funds = round(available_funds - total_outlay, 2)

        if total_outlay > available_funds:
            warnings.append(
                f"Insufficient available funds! Required ₹{total_outlay:.2f}, but available funds are ₹{available_funds:.2f}."
            )
            is_valid = False

        # Single stock limit check (default 10%)
        max_single_stock_val = total_capital * (settings.MAX_SINGLE_STOCK_PCT / 100.0)
        if estimated_investment > max_single_stock_val:
            warnings.append(
                f"Investment ₹{estimated_investment:.2f} exceeds recommended single stock limit of ₹{max_single_stock_val:.2f} ({settings.MAX_SINGLE_STOCK_PCT}% of capital)."
            )

        # Portfolio exposure cap check (default 25%)
        new_total_invested = current_invested_value + estimated_investment
        if (new_total_invested / total_capital) * 100.0 > settings.MAX_PORTFOLIO_EXPOSURE_PCT:
            warnings.append(
                f"Total portfolio exposure ({round((new_total_invested / total_capital) * 100, 1)}%) would exceed safety limit of {settings.MAX_PORTFOLIO_EXPOSURE_PCT}%."
            )

        return {
            "is_valid": is_valid,
            "shares_quantity": shares_quantity,
            "verified_entry_price": round(price, 2),
            "estimated_investment": estimated_investment,
            "total_outlay": total_outlay,
            "buy_charges": buy_charges,
            "target_sell_charges": target_sell_charges,
            "sl_sell_charges": sl_sell_charges,
            "roundtrip_target_charges": roundtrip_target_charges,
            "roundtrip_sl_charges": roundtrip_sl_charges,
            "potential_profit_net": potential_profit_net,
            "potential_profit_pct": potential_profit_pct,
            "potential_loss_net": potential_loss_net,
            "potential_loss_pct": potential_loss_pct,
            "risk_reward_ratio": risk_reward_ratio,
            "remaining_available_funds": remaining_funds,
            "holding_period_hours": holding_period_hours,
            "warnings": warnings,
        }
