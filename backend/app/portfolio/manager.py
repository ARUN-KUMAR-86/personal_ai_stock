"""Portfolio execution and independent Groww manual tracking manager."""

from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.portfolio import Position, PaperTrade
from app.providers.factory import get_market_data_provider


class PortfolioManager:
    """Manages manually purchased stock positions, weighted average pricing, and P&L ledger."""

    @staticmethod
    def calculate_transaction_costs(trade_value: float) -> float:
        """Standard Indian equity delivery estimated charges (~0.15%)."""
        brokerage = min(20.0, trade_value * 0.0003)
        stt_and_taxes = trade_value * 0.0012
        return round(brokerage + stt_and_taxes, 2)

    @classmethod
    def record_manual_purchase(
        cls,
        db: Session,
        symbol: str,
        exchange: str = "NSE",
        actual_price: float = 0.0,
        quantity: int = 1,
        purchase_date: Optional[str] = None,
        purchase_time: Optional[str] = None,
        charges: float = 0.0,
        custom_target: Optional[float] = None,
        custom_stop_loss: Optional[float] = None,
        custom_thresholds: Optional[Dict[str, Any]] = None,
        company_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Records a stock manually purchased through Groww.
        - Calculates correct weighted average buy price on multiple purchases.
        - Initializes profit and loss monitoring.
        - Adds to transaction ledger.
        """
        sym = symbol.upper().strip()
        ex = (exchange or "NSE").upper().strip()

        if actual_price <= 0:
            raise ValueError("Actual purchase price must be greater than zero.")
        if quantity <= 0:
            raise ValueError("Quantity purchased must be at least 1.")

        # Parse purchase timestamp
        now_utc = datetime.now(timezone.utc)
        purchase_dt = now_utc
        if purchase_date:
            try:
                time_str = purchase_time or "09:15:00"
                combined_str = f"{purchase_date.strip()} {time_str.strip()}"
                purchase_dt = datetime.fromisoformat(combined_str.replace("Z", ""))
                if purchase_dt.tzinfo is None:
                    purchase_dt = purchase_dt.replace(tzinfo=timezone.utc)
            except Exception:
                purchase_dt = now_utc

        # Check existing open position for this symbol
        pos = (
            db.query(Position)
            .filter(
                Position.symbol == sym,
                Position.exchange == ex,
                Position.is_open == True,
            )
            .first()
        )

        trade_val = round(actual_price * quantity, 2)

        if pos:
            # Multi-purchase weighted average buy price calculation:
            old_qty = pos.quantity
            old_avg = pos.avg_entry_price
            total_shares = old_qty + quantity
            total_invested = (old_avg * old_qty) + trade_val
            weighted_avg_price = round(total_invested / total_shares, 2)

            pos.avg_entry_price = weighted_avg_price
            pos.quantity = total_shares
            pos.charges = round((pos.charges or 0.0) + charges, 2)
            pos.fees = round((pos.fees or 0.0) + charges, 2)
            pos.current_price = actual_price
            pos.unrealized_pnl = round((actual_price - weighted_avg_price) * total_shares, 2)

            if custom_target:
                pos.target = custom_target
            if custom_stop_loss:
                pos.stop_loss = custom_stop_loss
            if custom_thresholds:
                pos.custom_thresholds = custom_thresholds
            if company_name and not pos.company_name:
                pos.company_name = company_name

            # Reset triggered thresholds on position averaging
            pos.triggered_thresholds = []
            pos.monitored_at = now_utc
            db.commit()
            db.refresh(pos)

        else:
            # Create new open position
            pos = Position(
                symbol=sym,
                exchange=ex,
                company_name=company_name or sym,
                quantity=quantity,
                avg_entry_price=actual_price,
                current_price=actual_price,
                stop_loss=custom_stop_loss,
                target=custom_target,
                unrealized_pnl=0.0,
                realized_pnl=0.0,
                charges=charges,
                fees=charges,
                is_open=True,
                status="ACTIVE",
                priority="P2",
                triggered_thresholds=[],
                custom_thresholds=custom_thresholds,
                mode="GROWW_MANUAL",
                purchase_date=purchase_dt,
                opened_at=purchase_dt,
                monitored_at=now_utc,
            )
            db.add(pos)
            db.commit()
            db.refresh(pos)

        # Record in transaction ledger
        trade_record = PaperTrade(
            symbol=sym,
            exchange=ex,
            action="MANUAL_BUY",
            quantity=quantity,
            price=actual_price,
            fees=charges,
            total_amount=trade_val,
            pnl=0.0,
            reason="Manual Groww Purchase",
            timestamp=purchase_dt,
        )
        db.add(trade_record)
        db.commit()

        # Immediately fetch fresh quote to update unrealized P/L
        try:
            provider = get_market_data_provider()
            q = provider.get_quote(sym, ex)
            if q and q.price and q.price > 0:
                pos.current_price = q.price
                pos.unrealized_pnl = round((q.price - pos.avg_entry_price) * pos.quantity, 2)
                db.commit()
        except Exception:
            pass

        return {
            "status": "SUCCESS",
            "message": f"Successfully added {quantity} shares of {sym} at ₹{actual_price:.2f} to your portfolio.",
            "position": {
                "id": pos.id,
                "symbol": pos.symbol,
                "exchange": pos.exchange,
                "quantity": pos.quantity,
                "avg_entry_price": pos.avg_entry_price,
                "current_price": pos.current_price,
                "total_invested": round(pos.avg_entry_price * pos.quantity, 2),
                "unrealized_pnl": pos.unrealized_pnl,
                "priority": pos.priority,
                "target": pos.target,
                "stop_loss": pos.stop_loss,
            },
        }

    @classmethod
    def record_manual_sale(
        cls,
        db: Session,
        symbol: str,
        exchange: str = "NSE",
        selling_price: float = 0.0,
        quantity_sold: int = 1,
        selling_date: Optional[str] = None,
        selling_time: Optional[str] = None,
        charges: float = 0.0,
        notes: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Records a stock sale manually executed in Groww.
        - Calculates exact realized profit/loss.
        - Updates remaining stock quantity.
        - Stops monitoring if completely closed.
        - Preserves complete transaction history.
        """
        sym = symbol.upper().strip()
        ex = (exchange or "NSE").upper().strip()

        if selling_price <= 0:
            raise ValueError("Selling price must be greater than zero.")
        if quantity_sold <= 0:
            raise ValueError("Quantity sold must be at least 1.")

        pos = (
            db.query(Position)
            .filter(
                Position.symbol == sym,
                Position.exchange == ex,
                Position.is_open == True,
            )
            .first()
        )

        if not pos:
            raise ValueError(f"No active open holding found for {sym} to sell.")

        if quantity_sold > pos.quantity:
            raise ValueError(
                f"Cannot sell {quantity_sold} shares. You currently hold {pos.quantity} shares of {sym}."
            )

        now_utc = datetime.now(timezone.utc)
        sale_dt = now_utc
        if selling_date:
            try:
                time_str = selling_time or "15:30:00"
                combined_str = f"{selling_date.strip()} {time_str.strip()}"
                sale_dt = datetime.fromisoformat(combined_str.replace("Z", ""))
                if sale_dt.tzinfo is None:
                    sale_dt = sale_dt.replace(tzinfo=timezone.utc)
            except Exception:
                sale_dt = now_utc

        # Calculate realized P&L on sold quantity:
        realized_profit = round(((selling_price - pos.avg_entry_price) * quantity_sold) - charges, 2)

        pos.realized_pnl = round((pos.realized_pnl or 0.0) + realized_profit, 2)
        pos.quantity -= quantity_sold
        pos.charges = round((pos.charges or 0.0) + charges, 2)
        pos.fees = round((pos.fees or 0.0) + charges, 2)
        pos.current_price = selling_price

        is_fully_closed = (pos.quantity == 0)
        if is_fully_closed:
            pos.is_open = False
            pos.status = "CLOSED"
            pos.closed_at = sale_dt
            pos.unrealized_pnl = 0.0
            pos.exit_reason = f"Manual Groww Sale ({quantity_sold} shares @ ₹{selling_price:.2f})"
        else:
            # Partial sale: continue monitoring remaining shares
            pos.unrealized_pnl = round((selling_price - pos.avg_entry_price) * pos.quantity, 2)

        # Audit ledger record
        trade_record = PaperTrade(
            symbol=sym,
            exchange=ex,
            action="MANUAL_SELL",
            quantity=quantity_sold,
            price=selling_price,
            fees=charges,
            total_amount=round(selling_price * quantity_sold, 2),
            pnl=realized_profit,
            reason=notes or f"Manual Groww Sale ({'Full Exit' if is_fully_closed else 'Partial Exit'})",
            timestamp=sale_dt,
        )
        db.add(trade_record)
        db.commit()
        db.refresh(pos)

        return {
            "status": "SUCCESS",
            "message": f"Successfully recorded sale of {quantity_sold} shares of {sym} @ ₹{selling_price:.2f}.",
            "realized_pnl": realized_profit,
            "remaining_quantity": pos.quantity,
            "is_fully_closed": is_fully_closed,
            "position": {
                "id": pos.id,
                "symbol": pos.symbol,
                "exchange": pos.exchange,
                "quantity": pos.quantity,
                "status": pos.status,
                "avg_entry_price": pos.avg_entry_price,
                "current_price": pos.current_price,
                "realized_pnl": pos.realized_pnl,
                "unrealized_pnl": pos.unrealized_pnl,
            },
        }

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
        """Paper trading simulator execution method kept for tests and simulation."""
        action = action.upper().strip()
        if action not in ("BUY", "SELL"):
            raise ValueError("Action must be either BUY or SELL.")
        if quantity <= 0:
            raise ValueError("Quantity must be greater than zero.")

        if price is None or price <= 0:
            provider = get_market_data_provider()
            quote = provider.get_quote(symbol=symbol, exchange=exchange)
            price = quote.price if quote else 100.0

        trade_value = round(price * quantity, 2)
        fees = cls.calculate_transaction_costs(trade_value)

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
        now_utc = datetime.now(timezone.utc)

        if action == "BUY":
            if pos:
                total_shares = pos.quantity + quantity
                total_cost = (pos.avg_entry_price * pos.quantity) + trade_value
                pos.avg_entry_price = round(total_cost / total_shares, 2)
                pos.quantity = total_shares
                pos.current_price = price
                pos.fees += fees
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
                    fees=fees,
                    is_open=True,
                    status="ACTIVE",
                    opened_at=now_utc,
                    mode=mode,
                    order_id=order_id,
                )
                db.add(pos)

        elif action == "SELL":
            if not pos or pos.quantity < quantity:
                raise ValueError(f"Insufficient position quantity ({pos.quantity if pos else 0}) to sell {quantity} shares.")

            realized_profit = (price - pos.avg_entry_price) * quantity - fees
            pnl = round(realized_profit, 2)

            pos.realized_pnl += pnl
            pos.quantity -= quantity
            pos.fees += fees
            pos.current_price = price

            if pos.quantity == 0:
                pos.is_open = False
                pos.status = "CLOSED"
                pos.closed_at = now_utc
                pos.unrealized_pnl = 0.0
            else:
                pos.unrealized_pnl = round((pos.current_price - pos.avg_entry_price) * pos.quantity, 2)

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
            timestamp=now_utc,
        )
        db.add(paper_trade)
        db.commit()
        db.refresh(paper_trade)
        return paper_trade

    @classmethod
    def get_portfolio_summary(cls, db: Session) -> Dict[str, Any]:
        """Calculates current portfolio summary metrics with live price mark-to-market."""
        open_positions = db.query(Position).filter(Position.is_open == True).all()
        closed_positions = db.query(Position).filter(Position.is_open == False).all()
        provider = get_market_data_provider()

        total_invested = 0.0
        total_market_val = 0.0
        total_unrealized = 0.0
        total_realized = sum(p.realized_pnl or 0.0 for p in closed_positions) + sum(p.realized_pnl or 0.0 for p in open_positions)

        formatted_open = []
        for p in open_positions:
            try:
                quote = provider.get_quote(p.symbol, p.exchange)
                if quote and quote.price:
                    p.current_price = quote.price
                    p.unrealized_pnl = round((p.current_price - p.avg_entry_price) * p.quantity, 2)
            except Exception:
                pass

            invested = round(p.avg_entry_price * p.quantity, 2)
            current_val = round(p.current_price * p.quantity, 2)
            pnl_pct = round(((p.current_price - p.avg_entry_price) / p.avg_entry_price) * 100.0, 2) if p.avg_entry_price > 0 else 0.0

            total_invested += invested
            total_market_val += current_val
            total_unrealized += p.unrealized_pnl

            # Assign priority if not set
            if not p.priority:
                p.priority = "P0" if pnl_pct <= -10 or p.unrealized_pnl <= -200 else ("P1" if pnl_pct <= -5 else "P2")

            formatted_open.append({
                "id": p.id,
                "symbol": p.symbol,
                "exchange": p.exchange,
                "company_name": p.company_name or p.symbol,
                "quantity": p.quantity,
                "avg_entry_price": p.avg_entry_price,
                "current_price": p.current_price,
                "invested": invested,
                "market_value": current_val,
                "pnl_inr": p.unrealized_pnl,
                "pnl_pct": pnl_pct,
                "priority": p.priority,
                "status": "ACTIVE",
                "stop_loss": p.stop_loss,
                "target": p.target,
                "purchase_date": p.purchase_date.isoformat() if p.purchase_date else (p.opened_at.isoformat() if p.opened_at else None),
            })

        db.commit()

        # Priority ordering: P0 first, then P1, P2, P3, P4
        priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3, "P4": 4}
        formatted_open.sort(key=lambda x: (priority_order.get(x["priority"], 9), -x["pnl_inr"]))

        return {
            "total_portfolio_value": round(total_market_val, 2),
            "total_invested_value": round(total_invested, 2),
            "total_unrealized_pnl": round(total_unrealized, 2),
            "total_realized_pnl": round(total_realized, 2),
            "open_positions_count": len(open_positions),
            "closed_positions_count": len(closed_positions),
            "positions": open_positions,
            "active_holdings": formatted_open,
            "closed_holdings": [
                {
                    "id": p.id,
                    "symbol": p.symbol,
                    "exchange": p.exchange,
                    "avg_entry_price": p.avg_entry_price,
                    "final_price": p.current_price,
                    "realized_pnl": p.realized_pnl,
                    "status": "CLOSED",
                    "closed_at": p.closed_at.isoformat() if p.closed_at else None,
                }
                for p in closed_positions
            ],
        }
