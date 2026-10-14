"""Automatic Position Monitoring & Exit Management Service."""

from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.models.portfolio import Position
from app.models.order import Order
from app.models.broker import BrokerAccount
from app.providers.factory import get_market_data_provider
from app.brokers.factory import get_broker_adapter
from app.notifications.notifier import notifier
from app.portfolio.manager import PortfolioManager


class PositionMonitor:
    """
    Monitors all open positions against:
    - Stop-loss price
    - Target profit price (Take Money)
    - Maximum intended holding period deadline (24 or 48 hours)
    - Outside-market-hours exit policies (real broker) vs instant execution (paper simulation)
    - Automatic selling and profit-taking
    """

    @classmethod
    def check_and_update_positions(cls, db: Session, force_market_open: bool = False) -> Dict[str, Any]:
        """
        Executes a monitoring pass over all open positions.
        """
        positions: List[Position] = db.query(Position).filter(Position.is_open == True).all()
        if not positions:
            return {"monitored_count": 0, "actions_taken": []}

        provider = get_market_data_provider()
        broker = get_broker_adapter()
        actions = []
        now = datetime.now(timezone.utc)

        for pos in positions:
            try:
                # 1. Fetch current verified quote
                curr_price = pos.current_price or pos.avg_entry_price or 100.0
                try:
                    quote = provider.get_quote(symbol=pos.symbol, exchange=pos.exchange)
                    if quote and quote.price and quote.price > 0:
                        curr_price = quote.price
                except Exception as quote_err:
                    logger.warning(f"Could not refresh quote for {pos.symbol}: {quote_err}. Using price ₹{curr_price:.2f}.")

                pos.current_price = curr_price
                pos.unrealized_pnl = round((curr_price - pos.avg_entry_price) * pos.quantity, 2)
                pos.monitored_at = now

                # 2. Check exit conditions
                condition_triggered = False
                trigger_reason = None

                # Check Stop-Loss
                if pos.stop_loss and curr_price <= pos.stop_loss:
                    condition_triggered = True
                    trigger_reason = f"STOP_LOSS_HIT (Price ₹{curr_price:.2f} <= SL ₹{pos.stop_loss:.2f})"

                # Check Target Profit (Take Money automatically)
                elif pos.target and curr_price >= pos.target:
                    condition_triggered = True
                    trigger_reason = f"TARGET_HIT (Price ₹{curr_price:.2f} >= Target ₹{pos.target:.2f} - Taking Money)"

                # Check Maximum Holding Period
                deadline = pos.exit_deadline
                if deadline and deadline.tzinfo is None:
                    deadline = deadline.replace(tzinfo=timezone.utc)

                if deadline and now >= deadline:
                    condition_triggered = True
                    trigger_reason = f"HOLDING_PERIOD_EXPIRED ({pos.holding_period_hours}h maximum intended holding period reached)"

                if not condition_triggered:
                    continue

                logger.info(f"Position exit condition triggered for {pos.symbol}: {trigger_reason}")

                # 3. Check Market Status
                market_status = provider.get_market_status(exchange=pos.exchange)
                is_market_open = force_market_open or market_status.get("is_open", False)

                # Check broker account settings to check trading mode
                account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
                is_hybrid_guard = account and ("Hybrid Guard" in (account.trading_mode or "") or "Option B" in (account.trading_mode or ""))

                # Auto-sell policies:
                is_stop_loss = trigger_reason.startswith("STOP_LOSS")
                is_target = trigger_reason.startswith("TARGET_HIT")
                is_paper = (pos.mode or "PAPER").upper() == "PAPER"
                
                # In paper simulation, auto-sell is ALWAYS active so users see instant execution
                # For live, auto-sell is active if pos.auto_sell_enabled or Option B / hybrid guard or settings
                auto_sell = (
                    is_paper
                    or pos.auto_sell_enabled
                    or settings.AUTO_SELL_ENABLED
                    or (is_hybrid_guard and is_stop_loss)
                    or (is_target and (pos.auto_sell_enabled or getattr(account, "auto_take_profit", True)))
                )

                # 4. Handle exit outside market hours:
                # IMPORTANT: In PAPER SIMULATION mode, we execute immediately regardless of market hours!
                # Only REAL live broker orders are queued for 09:15 IST opening.
                if not is_market_open and not is_paper:
                    if not pos.exit_triggered:
                        pos.exit_triggered = True
                        pos.exit_reason = f"{trigger_reason} (Market closed. Exit queued for 09:15 IST opening)"
                        db.commit()

                        notifier.send_notification(
                            db=db,
                            symbol=pos.symbol,
                            exchange=pos.exchange,
                            alert_type="EXIT_QUEUED_OFFHOURS",
                            title=f"EXIT QUEUED: {pos.symbol} ({trigger_reason})",
                            body=(
                                f"Position for {pos.symbol} met exit condition outside trading hours.\n"
                                f"Condition: {trigger_reason}\n"
                                f"Latest verified price: ₹{curr_price:.2f}\n"
                                f"Policy: Exit attempt will occur at next regular market session (09:15 IST)."
                            ),
                            price=curr_price,
                        )
                        actions.append({"symbol": pos.symbol, "action": "QUEUED_OFFHOURS", "reason": trigger_reason})
                    continue

                # 5. Execute Exit / Auto-Sell:
                if auto_sell:
                    logger.info(f"Executing automatic sell for {pos.symbol} ({pos.quantity} shares, mode: {pos.mode})...")
                    try:
                        # Close position in ledger
                        PortfolioManager.execute_paper_trade(
                            db=db,
                            symbol=pos.symbol,
                            exchange=pos.exchange,
                            action="SELL",
                            quantity=pos.quantity,
                            price=curr_price,
                            reason=f"Auto-Sell: {trigger_reason}",
                        )
                        pos.is_open = False
                        pos.closed_at = now
                        pos.exit_triggered = True
                        pos.exit_reason = trigger_reason
                        pnl = pos.realized_pnl

                        # Credit money back to user account balance (Taking Money Automatically)
                        if account:
                            sale_proceeds = round(curr_price * pos.quantity, 2)
                            account.account_balance = round(account.account_balance + sale_proceeds, 2)
                            account.available_funds = round(account.available_funds + sale_proceeds, 2)

                        db.commit()

                        alert_title = (
                            f"AUTO TAKE PROFIT EXECUTED: {pos.symbol} (+₹{pnl:.2f})"
                            if is_target
                            else f"AUTO-SELL EXECUTED: {pos.symbol} (P&L: ₹{pnl:+.2f})"
                        )
                        notifier.send_notification(
                            db=db,
                            symbol=pos.symbol,
                            exchange=pos.exchange,
                            alert_type="AUTO_SELL_EXECUTED",
                            title=alert_title,
                            body=(
                                f"Automatic sell order for {pos.symbol} ({pos.quantity} shares) successfully executed.\n"
                                f"Trigger: {trigger_reason}\n"
                                f"Execution Price: ₹{curr_price:.2f}\n"
                                f"Realized P&L: ₹{pnl:+.2f}\n"
                                f"Status: Money credited back to Available Funds."
                            ),
                            price=curr_price,
                        )
                        actions.append({"symbol": pos.symbol, "action": "AUTO_SOLD", "price": curr_price, "pnl": pnl, "mode": pos.mode})

                    except Exception as e:
                        logger.error(f"Error during auto-sell execution for {pos.symbol}: {e}")
                        notifier.send_notification(
                            db=db,
                            symbol=pos.symbol,
                            exchange=pos.exchange,
                            alert_type="AUTO_SELL_ERROR",
                            title=f"AUTO-SELL ERROR: {pos.symbol}",
                            body=(
                                f"Failed to submit sell order for {pos.symbol}.\n"
                                f"Error: {str(e)}\n"
                                f"Position remains OPEN. Manual exit required."
                            ),
                            price=curr_price,
                        )
                        actions.append({"symbol": pos.symbol, "action": "ERROR", "error": str(e)})

                else:
                    # Auto-selling NOT enabled -> Notification-First Workflow
                    if not pos.exit_triggered:
                        pos.exit_triggered = True
                        pos.exit_reason = trigger_reason
                        db.commit()

                        notifier.send_trade_alert(
                            db=db,
                            symbol=pos.symbol,
                            exchange=pos.exchange,
                            action="SELL",
                            suggested_investment=float(pos.avg_entry_price * pos.quantity),
                            estimated_quantity=pos.quantity,
                            estimated_order_value=float(curr_price * pos.quantity),
                            reason=trigger_reason,
                            risk_level="Medium",
                            stop_loss=pos.stop_loss,
                            target=pos.target,
                        )
                        actions.append({"symbol": pos.symbol, "action": "NOTIFIED_TRADE_ALERT_SELL", "reason": trigger_reason})

            except Exception as e:
                logger.error(f"Error monitoring position {pos.symbol}: {e}")

        db.commit()
        return {"monitored_count": len(positions), "actions_taken": actions}
