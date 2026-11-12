"""Automatic Position Monitoring & Profit/Loss Threshold Alert Engine."""

from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.models.portfolio import Position
from app.providers.factory import get_market_data_provider
from app.notifications.notifier import notifier

# Standard Institutional Profit Notification Thresholds
DEFAULT_PROFIT_THRESHOLDS = [
    {"key": "PROFIT_INR_30", "type": "INR", "threshold": 30.0, "name": "First Profit Alert", "priority": "P2"},
    {"key": "PROFIT_INR_50", "type": "INR", "threshold": 50.0, "name": "Second Profit Alert", "priority": "P2"},
    {"key": "PROFIT_INR_100", "type": "INR", "threshold": 100.0, "name": "High Priority Profit Alert", "priority": "P1"},
    {"key": "PROFIT_INR_200", "type": "INR", "threshold": 200.0, "name": "Critical Profit Alert", "priority": "P0"},
    {"key": "PROFIT_INR_500", "type": "INR", "threshold": 500.0, "name": "Major Profit Alert", "priority": "P0"},
    {"key": "PROFIT_INR_1000", "type": "INR", "threshold": 1000.0, "name": "Extreme Profit Alert", "priority": "P0"},
]

# Standard Institutional Loss Notification Thresholds (Rupee & Percentage Independent)
DEFAULT_LOSS_THRESHOLDS = [
    # Rupee Loss Thresholds
    {"key": "LOSS_INR_30", "type": "INR", "threshold": -30.0, "name": "First Loss Alert", "priority": "P2"},
    {"key": "LOSS_INR_50", "type": "INR", "threshold": -50.0, "name": "Second Loss Alert", "priority": "P2"},
    {"key": "LOSS_INR_100", "type": "INR", "threshold": -100.0, "name": "High Priority Loss Alert", "priority": "P1"},
    {"key": "LOSS_INR_200", "type": "INR", "threshold": -200.0, "name": "Critical Loss Alert", "priority": "P0"},
    {"key": "LOSS_INR_500", "type": "INR", "threshold": -500.0, "name": "Major Loss Alert", "priority": "P0"},
    {"key": "LOSS_INR_1000", "type": "INR", "threshold": -1000.0, "name": "Extreme Loss Alert", "priority": "P0"},
    # Percentage Loss Thresholds (Independent conditions!)
    {"key": "LOSS_PCT_5", "type": "PCT", "threshold": -5.0, "name": "High Risk Warning", "priority": "P1"},
    {"key": "LOSS_PCT_8", "type": "PCT", "threshold": -8.0, "name": "Very High Risk Warning", "priority": "P1"},
    {"key": "LOSS_PCT_10", "type": "PCT", "threshold": -10.0, "name": "Critical Loss Warning", "priority": "P0"},
    {"key": "LOSS_PCT_12", "type": "PCT", "threshold": -12.0, "name": "Extreme Loss Alert", "priority": "P0"},
]


class PositionMonitor:
    """
    Continuous 24/7 Monitor for Manually Purchased Stocks.
    - Tracks live unrealized profit/loss.
    - Automatically checks rupee & percentage thresholds independently.
    - Dispatches alerts immediately when thresholds are crossed.
    - Preserves position state: NO automatic buying or selling.
    - Prevents duplicate alerts for the same threshold on the same position.
    """

    @classmethod
    def get_effective_thresholds(cls, pos: Position) -> Dict[str, List[Dict[str, Any]]]:
        """Combines global defaults with per-stock custom thresholds if configured."""
        profit_cfg = list(DEFAULT_PROFIT_THRESHOLDS)
        loss_cfg = list(DEFAULT_LOSS_THRESHOLDS)

        custom = getattr(pos, "custom_thresholds", None)
        if isinstance(custom, dict):
            # Allow custom profit thresholds: e.g. {"profit_inr": [30, 60], "loss_inr": [-40], "loss_pct": [-6, -12]}
            if "profit_inr" in custom and isinstance(custom["profit_inr"], list):
                custom_profits = []
                for val in sorted(custom["profit_inr"]):
                    k = f"PROFIT_INR_{int(abs(val))}"
                    p = "P0" if val >= 200 else ("P1" if val >= 100 else "P2")
                    custom_profits.append({"key": k, "type": "INR", "threshold": float(val), "name": f"Custom +₹{val} Profit Alert", "priority": p})
                if custom_profits:
                    profit_cfg = custom_profits

            if "loss_inr" in custom and isinstance(custom["loss_inr"], list):
                custom_losses = []
                for val in sorted(custom["loss_inr"], reverse=True):  # e.g. -30, -50, -100
                    k = f"LOSS_INR_{int(abs(val))}"
                    p = "P0" if abs(val) >= 200 else ("P1" if abs(val) >= 100 else "P2")
                    custom_losses.append({"key": k, "type": "INR", "threshold": -float(abs(val)), "name": f"Custom -₹{abs(val)} Loss Alert", "priority": p})
                if custom_losses:
                    # Keep existing PCT but replace INR
                    loss_cfg = [t for t in loss_cfg if t["type"] != "INR"] + custom_losses

            if "loss_pct" in custom and isinstance(custom["loss_pct"], list):
                custom_pct = []
                for val in sorted(custom["loss_pct"], reverse=True):
                    k = f"LOSS_PCT_{int(abs(val))}"
                    p = "P0" if abs(val) >= 10 else "P1"
                    custom_pct.append({"key": k, "type": "PCT", "threshold": -float(abs(val)), "name": f"Custom -{abs(val)}% Loss Alert", "priority": p})
                if custom_pct:
                    loss_cfg = [t for t in loss_cfg if t["type"] != "PCT"] + custom_pct

        return {"profit": profit_cfg, "loss": loss_cfg}

    @classmethod
    def check_and_update_positions(
        cls,
        db: Session,
        force_market_open: bool = False,
        price_overrides: Optional[Dict[str, float]] = None,
    ) -> Dict[str, Any]:
        """
        Executes a monitoring pass over all open positions:
        1. Refreshes live prices and calculates unrealized P&L in INR and %.
        2. Evaluates profit and loss thresholds independently.
        3. Dispatches notifications for any newly crossed threshold.
        4. Updates database records without closing positions.
        """
        positions: List[Position] = db.query(Position).filter(Position.is_open == True).all()
        if not positions:
            return {"monitored_count": 0, "actions_taken": [], "alerts_triggered": []}

        provider = get_market_data_provider()
        actions = []
        alerts_triggered = []
        now = datetime.now(timezone.utc)

        for pos in positions:
            try:
                sym = pos.symbol.upper()
                ex = pos.exchange or "NSE"

                # 1. Fetch current price (using override if provided for testing/instant sync)
                curr_price = pos.current_price or pos.avg_entry_price or 100.0
                if price_overrides and sym in price_overrides:
                    curr_price = float(price_overrides[sym])
                else:
                    try:
                        quote = provider.get_quote(symbol=sym, exchange=ex)
                        if quote and quote.price and quote.price > 0:
                            curr_price = quote.price
                    except Exception as quote_err:
                        logger.warning(f"Could not refresh quote for {sym}: {quote_err}. Using last price ₹{curr_price:.2f}.")

                # 2. Mark-to-market calculations
                pos.current_price = curr_price
                buy_price = pos.avg_entry_price
                qty = pos.quantity
                unrealized_inr = round((curr_price - buy_price) * qty, 2)
                unrealized_pct = round(((curr_price - buy_price) / buy_price) * 100.0, 2) if buy_price > 0 else 0.0

                pos.unrealized_pnl = unrealized_inr
                pos.monitored_at = now

                # Dynamic priority calculation for position
                if unrealized_pct <= -10.0 or unrealized_inr <= -200.0 or unrealized_inr >= 500.0:
                    pos.priority = "P0"
                elif unrealized_pct <= -5.0 or unrealized_inr <= -100.0 or unrealized_inr >= 100.0:
                    pos.priority = "P1"
                else:
                    pos.priority = "P2"

                # Initialize triggered thresholds set
                triggered_list = getattr(pos, "triggered_thresholds", None)
                if not isinstance(triggered_list, list):
                    triggered_list = []
                triggered_set = set(triggered_list)

                threshold_cfgs = cls.get_effective_thresholds(pos)

                # 3. Check Profit Thresholds (when in profit)
                if unrealized_inr > 0:
                    # Prune any previous loss thresholds if position swung back to profit
                    triggered_set = {k for k in triggered_set if not k.startswith("LOSS_")}

                    # Stepping logic: Every +₹30 profit milestone (+30, +60, +90, +120...)
                    step_profit = int((unrealized_inr // 30) * 30)
                    if step_profit >= 30:
                        for milestone in range(30, step_profit + 1, 30):
                            t_key = f"PROFIT_INR_{milestone}"
                            if t_key not in triggered_set:
                                triggered_set.add(t_key)
                                t_name = f"+₹{milestone} Profit Sell Target Reached"
                                p = "P0" if milestone >= 210 else ("P1" if milestone >= 90 else "P2")
                                alert = notifier.send_threshold_alert(
                                    db=db,
                                    position=pos,
                                    current_price=curr_price,
                                    threshold_key=t_key,
                                    threshold_name=t_name,
                                    pnl_inr=unrealized_inr,
                                    pnl_pct=unrealized_pct,
                                    priority=p,
                                )
                                alerts_triggered.append({
                                    "symbol": sym,
                                    "threshold": t_key,
                                    "pnl_inr": unrealized_inr,
                                    "pnl_pct": unrealized_pct,
                                    "priority": p,
                                    "alert_id": alert.id,
                                })
                                logger.info(f"PROFIT ALERT TRIGGERED for {sym}: {t_name} (+₹{unrealized_inr:.2f} / +{unrealized_pct:.2f}%)")

                    # Check additional custom profit thresholds
                    for t in threshold_cfgs["profit"]:
                        t_key = t["key"]
                        t_val = t["threshold"]
                        t_name = t["name"]
                        t_pri = t["priority"]
                        if unrealized_inr >= t_val and t_key not in triggered_set:
                            triggered_set.add(t_key)
                            alert = notifier.send_threshold_alert(
                                db=db,
                                position=pos,
                                current_price=curr_price,
                                threshold_key=t_key,
                                threshold_name=t_name,
                                pnl_inr=unrealized_inr,
                                pnl_pct=unrealized_pct,
                                priority=t_pri,
                            )
                            alerts_triggered.append({
                                "symbol": sym,
                                "threshold": t_key,
                                "pnl_inr": unrealized_inr,
                                "pnl_pct": unrealized_pct,
                                "priority": t_pri,
                                "alert_id": alert.id,
                            })

                # 4. Check Loss Thresholds (when in loss)
                elif unrealized_inr < 0:
                    # Prune any previous profit thresholds if position dropped back into loss
                    triggered_set = {k for k in triggered_set if not k.startswith("PROFIT_")}

                    # Stepping logic: Every -₹30 loss milestone (-30, -60, -90, -120...)
                    abs_loss = abs(unrealized_inr)
                    step_loss = int((abs_loss // 30) * 30)
                    if step_loss >= 30:
                        for milestone in range(30, step_loss + 1, 30):
                            t_key = f"LOSS_INR_{milestone}"
                            if t_key not in triggered_set:
                                triggered_set.add(t_key)
                                t_name = f"-₹{milestone} Loss Stop-Loss Alert"
                                p = "P0" if milestone >= 210 else ("P1" if milestone >= 90 else "P2")
                                alert = notifier.send_threshold_alert(
                                    db=db,
                                    position=pos,
                                    current_price=curr_price,
                                    threshold_key=t_key,
                                    threshold_name=t_name,
                                    pnl_inr=unrealized_inr,
                                    pnl_pct=unrealized_pct,
                                    priority=p,
                                )
                                alerts_triggered.append({
                                    "symbol": sym,
                                    "threshold": t_key,
                                    "pnl_inr": unrealized_inr,
                                    "pnl_pct": unrealized_pct,
                                    "priority": p,
                                    "alert_id": alert.id,
                                })
                                logger.info(f"LOSS ALERT TRIGGERED for {sym}: {t_name} (₹{unrealized_inr:.2f} / {unrealized_pct:.2f}%)")

                    # Check percentage loss thresholds (-5%, -8%, -10%, -12%)
                    for t in threshold_cfgs["loss"]:
                        t_key = t["key"]
                        t_val = t["threshold"]
                        t_type = t["type"]
                        t_name = t["name"]
                        t_pri = t["priority"]

                        condition_met = False
                        if t_type == "INR" and unrealized_inr <= t_val:
                            condition_met = True
                        elif t_type == "PCT" and unrealized_pct <= t_val:
                            condition_met = True

                        if condition_met and t_key not in triggered_set:
                            triggered_set.add(t_key)
                            alert = notifier.send_threshold_alert(
                                db=db,
                                position=pos,
                                current_price=curr_price,
                                threshold_key=t_key,
                                threshold_name=t_name,
                                pnl_inr=unrealized_inr,
                                pnl_pct=unrealized_pct,
                                priority=t_pri,
                            )
                            alerts_triggered.append({
                                "symbol": sym,
                                "threshold": t_key,
                                "pnl_inr": unrealized_inr,
                                "pnl_pct": unrealized_pct,
                                "priority": t_pri,
                                "alert_id": alert.id,
                            })
                            logger.info(f"LOSS ALERT TRIGGERED for {sym}: {t_name} (₹{unrealized_inr:.2f} / {unrealized_pct:.2f}%)")

                # 5. Check Custom Stop-Loss Breached
                if pos.stop_loss and curr_price <= pos.stop_loss and "CUSTOM_STOP_LOSS" not in triggered_set:
                    triggered_set.add("CUSTOM_STOP_LOSS")
                    alert = notifier.send_threshold_alert(
                        db=db,
                        position=pos,
                        current_price=curr_price,
                        threshold_key="CUSTOM_STOP_LOSS",
                        threshold_name="Custom Stop-Loss Breached",
                        pnl_inr=unrealized_inr,
                        pnl_pct=unrealized_pct,
                        priority="P0",
                    )
                    alerts_triggered.append({"symbol": sym, "threshold": "CUSTOM_STOP_LOSS", "priority": "P0"})

                # 6. Check Custom Target Reached
                if pos.target and curr_price >= pos.target and "CUSTOM_TARGET" not in triggered_set:
                    triggered_set.add("CUSTOM_TARGET")
                    alert = notifier.send_threshold_alert(
                        db=db,
                        position=pos,
                        current_price=curr_price,
                        threshold_key="CUSTOM_TARGET",
                        threshold_name="Custom Target Price Reached",
                        pnl_inr=unrealized_inr,
                        pnl_pct=unrealized_pct,
                        priority="P1",
                    )
                    alerts_triggered.append({"symbol": sym, "threshold": "CUSTOM_TARGET", "priority": "P1"})

                # 7. Check Holding Period Expiry or Stop Loss Exit Trigger Policies
                condition_triggered = False
                trigger_reason = None

                deadline = pos.exit_deadline
                if deadline and deadline.tzinfo is None:
                    deadline = deadline.replace(tzinfo=timezone.utc)

                if deadline and now >= deadline:
                    condition_triggered = True
                    trigger_reason = f"HOLDING_PERIOD_EXPIRED ({pos.holding_period_hours}h maximum intended holding period reached)"
                elif pos.stop_loss and curr_price <= pos.stop_loss:
                    condition_triggered = True
                    trigger_reason = f"STOP_LOSS_HIT (Price ₹{curr_price:.2f} <= SL ₹{pos.stop_loss:.2f})"
                elif pos.target and curr_price >= pos.target:
                    condition_triggered = True
                    trigger_reason = f"TARGET_HIT (Price ₹{curr_price:.2f} >= Target ₹{pos.target:.2f})"

                if condition_triggered:
                    pos.exit_triggered = True
                    pos.exit_reason = trigger_reason
                    auto_sell = pos.auto_sell_enabled or settings.AUTO_SELL_ENABLED
                    if auto_sell:
                        pos.is_open = False
                        pos.status = "CLOSED"
                        pos.closed_at = now
                        pos.realized_pnl = round((curr_price - pos.avg_entry_price) * pos.quantity, 2)
                        pos.unrealized_pnl = 0.0

                # Save updated triggered thresholds list on position
                pos.triggered_thresholds = list(triggered_set)
                actions.append({
                    "symbol": sym,
                    "price": curr_price,
                    "unrealized_inr": unrealized_inr,
                    "unrealized_pct": unrealized_pct,
                    "priority": pos.priority,
                })

            except Exception as e:
                logger.error(f"Error monitoring position {pos.symbol}: {e}")

        db.commit()
        return {
            "monitored_count": len(positions),
            "actions_taken": actions,
            "alerts_triggered": alerts_triggered,
        }

    @classmethod
    def monitor_and_cancel_invalidated_signals(cls, db: Session) -> List[Dict[str, Any]]:
        """Checks active signals and marks setups invalidated if structure collapses."""
        from app.models.signal import StockSignal
        from app.analysis.market_structure import MarketStructureAnalyzer
        from app.notifications.broadcaster import broadcaster

        cutoff = datetime.now(timezone.utc) - timedelta(hours=48)
        active_signals = (
            db.query(StockSignal)
            .filter(
                StockSignal.signal_type.in_(["BUY", "BUY WATCH"]),
                StockSignal.timestamp >= cutoff,
            )
            .all()
        )

        invalidations = []
        provider = get_market_data_provider()

        for sig in active_signals:
            try:
                df = provider.get_historical_ohlcv(symbol=sig.symbol, exchange=sig.exchange, timeframe="1d", period="1mo")
                if df.empty or len(df) < 10:
                    continue

                curr_price = float(df["close"].iloc[-1])
                struct_res = MarketStructureAnalyzer.analyze_structure(df)

                is_sl_breached = sig.stop_loss and curr_price <= sig.stop_loss
                is_structure_reversed = struct_res.get("structure_bias") == "BEARISH" or struct_res.get("choch_detected")

                if is_sl_breached or is_structure_reversed:
                    reason = (
                        f"Stop-loss breached (Price ₹{curr_price:.2f} <= SL ₹{sig.stop_loss:.2f})"
                        if is_sl_breached
                        else f"Market structure flipped to {struct_res.get('trend_state')}"
                    )

                    sig.signal_type = "CANCELLED"
                    sig.explanation = f"SIGNAL CANCELLED: Setup invalidated. {reason}."
                    db.commit()

                    invalidations.append({"symbol": sig.symbol, "reason": reason, "cancelled_price": curr_price})
                    logger.info(f"Signal cancelled for {sig.symbol}: {reason}")

                    try:
                        broadcaster.broadcast({
                            "type": "SIGNAL_CANCELLED",
                            "signal_id": sig.id,
                            "symbol": sig.symbol,
                            "exchange": sig.exchange,
                            "reason": reason,
                            "price": curr_price,
                        })
                    except Exception:
                        pass

            except Exception as err:
                logger.debug(f"Signal monitoring note for {sig.symbol}: {err}")

        return invalidations
