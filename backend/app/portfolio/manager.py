"""Portfolio and paper trading execution manager."""

from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import RiskCheckFailedError
from app.models.portfolio import Position, PaperTrade
from app.providers.factory import get_market_data_provider


class PortfolioManager:
    """Manages paper trading positions, simulated balances, and P&L tracking."""

    @staticmethod
    def calculate_transaction_costs(trade_value: float) -> float:
        """
        Simulates standard Indian equity brokerage and regulatory charges:
        Brokerage: min(0.03%, ₹20) + STT (0.1% on delivery) + Exchange turnover + GST
        Roughly ~0.15% total round-trip charges.
        """
        brokerage = min(20.0, trade_value * 0.0003)
        stt_and_taxes = trade_value * 0.0012
        return round(brokerage + stt_and_taxes, 2)

    @classmethod
    def execute_paper_trade(
        cls,
        db: Session,
        symbol: str,
        exchange: str,
        action: str,  # "BUY" or "SELL"
        quantity: int,
        price: Optional[float] = None,
        reason: Optional[str] = None,
        stop_loss: Optional[float] = None,
        target: Optional[float] = None,
        holding_period_hours: int = 48,
        auto_sell_enabled: bool = False,
        mode: str = "PAPER",
        order_id: Optional[str] = None,
    ) -> PaperTrade:
        """Executes a simulated paper trade and updates position and ledger."""
        action = action.upper().strip()
        if action not in ("BUY", "SELL"):
            raise ValueError("Action must be either BUY or SELL.")

        if quantity <= 0:
            raise ValueError("Quantity must be greater than zero.")

        # Determine price if not explicitly provided
        if price is None or price <= 0:
            provider = get_market_data_provider()
            quote = provider.get_quote(symbol=symbol, exchange=exchange)
            price = quote.price

        trade_value = round(price * quantity, 2)
        fees = cls.calculate_transaction_costs(trade_value)

        # Retrieve existing position
        pos = (
            db.query(Position)
            .filter(
                Position.symbol == symbol.upper(),
                Position.exchange == exchange.upper(),
                Position.is_open == True,
            )
            .first()
        )

        pnl = 0.0

        if action == "BUY":
            now_utc = datetime.now(timezone.utc)
            exit_deadline = now_utc + timedelta(hours=holding_period_hours)
            if pos:
                # Average up or down
                total_shares = pos.quantity + quantity
                total_cost = (pos.avg_entry_price * pos.quantity) + trade_value
                pos.avg_entry_price = round(total_cost / total_shares, 2)
                pos.quantity = total_shares
                pos.current_price = price
                pos.fees += fees
                pos.holding_period_hours = holding_period_hours
                pos.exit_deadline = exit_deadline
                pos.auto_sell_enabled = auto_sell_enabled
                if stop_loss:
                    pos.stop_loss = stop_loss
                if target:
                    pos.target = target
            else:
                pos = Position(
                    symbol=symbol.upper(),
                    exchange=exchange.upper(),
                    quantity=quantity,
                    avg_entry_price=price,
                    current_price=price,
                    stop_loss=stop_loss,
                    target=target,
                    holding_period_hours=holding_period_hours,
                    exit_deadline=exit_deadline,
                    auto_sell_enabled=auto_sell_enabled,
                    mode=mode,
                    order_id=order_id,
                    unrealized_pnl=0.0,
                    realized_pnl=0.0,
                    fees=fees,
                    is_open=True,
                    opened_at=now_utc,
                )
                db.add(pos)

        elif action == "SELL":
            if not pos or pos.quantity < quantity:
                raise ValueError(
                    f"Insufficient position quantity ({pos.quantity if pos else 0}) to sell {quantity} shares."
                )

            # Calculate realized P&L on exited shares
            realized_profit = (price - pos.avg_entry_price) * quantity - fees
            pnl = round(realized_profit, 2)

            pos.realized_pnl += pnl
            pos.quantity -= quantity
            pos.fees += fees
            pos.current_price = price

            if pos.quantity == 0:
                pos.is_open = False
                pos.closed_at = datetime.now(timezone.utc)
                pos.unrealized_pnl = 0.0
            else:
                pos.unrealized_pnl = round((pos.current_price - pos.avg_entry_price) * pos.quantity, 2)

        # Create paper trade audit record
        paper_trade = PaperTrade(
            symbol=symbol.upper(),
            exchange=exchange.upper(),
            action=action,
            quantity=quantity,
            price=price,
            fees=fees,
            total_amount=trade_value,
            pnl=pnl,
            reason=reason or f"Paper trade {action}",
            timestamp=datetime.now(timezone.utc),
        )
        db.add(paper_trade)
        db.commit()
        db.refresh(paper_trade)
        return paper_trade

    @classmethod
    def get_portfolio_summary(cls, db: Session) -> Dict[str, Any]:
        """Calculates current portfolio summary metrics with live price mark-to-market."""
        positions = db.query(Position).filter(Position.is_open == True).all()
        provider = get_market_data_provider()

        total_invested = 0.0
        total_market_val = 0.0
        total_unrealized = 0.0
        total_realized = 0.0

        for p in positions:
            try:
                quote = provider.get_quote(p.symbol, p.exchange)
                p.current_price = quote.price
                p.unrealized_pnl = round((p.current_price - p.avg_entry_price) * p.quantity, 2)
            except Exception:
                pass  # Keep previous price if provider fails

            invested = p.avg_entry_price * p.quantity
            current_val = p.current_price * p.quantity

            total_invested += invested
            total_market_val += current_val
            total_unrealized += p.unrealized_pnl
            total_realized += p.realized_pnl

        db.commit()

        base_capital = 500000.0  # Assumed default starting paper capital (5 Lakhs INR)
        exposure_pct = (total_invested / base_capital) * 100.0 if base_capital else 0.0

        return {
            "total_portfolio_value": round(total_market_val, 2),
            "total_invested_value": round(total_invested, 2),
            "total_unrealized_pnl": round(total_unrealized, 2),
            "total_realized_pnl": round(total_realized, 2),
            "open_positions_count": len(positions),
            "portfolio_exposure_pct": round(exposure_pct, 1),
            "positions": positions,
        }
