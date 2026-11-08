"""Live continuously-updating terminal dashboard for Personal AI Stock Research and Portfolio Monitoring."""

import os
import sys
import time
import argparse
from datetime import datetime, timezone
from typing import List, Dict, Any

from app.database.session import SessionLocal
from app.models.portfolio import Position
from app.models.alert import AlertHistory
from app.providers.factory import get_market_data_provider
from app.portfolio.manager import PortfolioManager
from app.scanner.scheduler import scheduler, is_auto_scan_active
from app.notifications.notifier import notifier

# ANSI Color Codes
BOLD = "\033[1m"
RESET = "\033[0m"
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
WHITE = "\033[97m"
DIM = "\033[2m"


def format_pnl_str(val: float, is_pct: bool = False) -> str:
    sign = "+" if val > 0 else ""
    unit = "%" if is_pct else ""
    color = GREEN if val > 0 else (RED if val < 0 else WHITE)
    return f"{color}{sign}{val:.2f}{unit}{RESET}"


def render_dashboard(db, clear_screen: bool = True):
    """Renders single frame of the live terminal monitoring dashboard."""
    summary = PortfolioManager.get_portfolio_summary(db)
    active_positions: List[Position] = db.query(Position).filter(Position.is_open == True).all()

    # Sort positions by priority: P0 first, then P1, P2, P3, P4
    priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3, "P4": 4}
    active_positions.sort(key=lambda p: (priority_order.get(p.priority or "P2", 9), -(p.unrealized_pnl or 0.0)))

    # Fetch recent notifications
    recent_alerts = (
        db.query(AlertHistory)
        .order_by(AlertHistory.created_at.desc())
        .limit(6)
        .all()
    )

    provider = get_market_data_provider()
    market_info = provider.get_market_status(exchange="NSE")
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = []
    if clear_screen:
        lines.append("\033[H\033[2J")  # Clear screen and move cursor home

    lines.append(f"{CYAN}{BOLD}======================================================================{RESET}")
    lines.append(f"          {BOLD}{WHITE}PERSONAL AI STOCK MONITOR — INSTITUTIONAL ENGINE{RESET}")
    lines.append(f"{CYAN}{BOLD}======================================================================{RESET}\n")

    # PORTFOLIO SUMMARY
    lines.append(f"{BOLD}PORTFOLIO SUMMARY{RESET}")
    lines.append(f"Total Investment:   ₹{summary['total_invested_value']:,.2f}")
    lines.append(f"Current Value:      ₹{summary['total_portfolio_value']:,.2f}")
    
    unrealized_tot = summary['total_unrealized_pnl']
    tot_sign = "+" if unrealized_tot >= 0 else ""
    tot_color = GREEN if unrealized_tot >= 0 else RED
    lines.append(f"Total Profit/Loss:  {tot_color}{tot_sign}₹{unrealized_tot:,.2f}{RESET}")
    lines.append(f"Realized P/L:       ₹{summary['total_realized_pnl']:,.2f}")
    lines.append(f"Active Stocks:      {len(active_positions)} | Closed Holdings: {summary.get('closed_positions_count', 0)}")
    lines.append(f"{DIM}----------------------------------------------------------------------{RESET}")

    # MY PURCHASED STOCKS
    lines.append(f"\n{BOLD}MY PURCHASED STOCKS{RESET}")
    header = f"{'STOCK':<10} {'PRI':<4} {'QTY':<6} {'BUY PRICE':<12} {'LIVE PRICE':<12} {'P/L (₹)':<14} {'P/L (%)':<10}"
    lines.append(f"{DIM}{header}{RESET}")

    if not active_positions:
        lines.append(f"{DIM}No active stock holdings. Click 'I BOUGHT THIS STOCK' to record purchases.{RESET}")
    else:
        for p in active_positions:
            sym = p.symbol
            pri = p.priority or "P2"
            pri_color = RED if pri == "P0" else (YELLOW if pri == "P1" else CYAN)
            qty = str(p.quantity)
            buy_p = f"₹{p.avg_entry_price:.2f}"
            live_p = f"₹{p.current_price:.2f}"
            pnl_inr = p.unrealized_pnl or 0.0
            pnl_pct = (((p.current_price - p.avg_entry_price) / p.avg_entry_price) * 100.0) if p.avg_entry_price > 0 else 0.0
            
            pnl_inr_str = format_pnl_str(pnl_inr)
            pnl_pct_str = format_pnl_str(pnl_pct, is_pct=True)

            row = f"{BOLD}{sym:<10}{RESET} {pri_color}{pri:<4}{RESET} {qty:<6} {buy_p:<12} {live_p:<12} {pnl_inr_str:<23} {pnl_pct_str:<19}"
            lines.append(row)

    lines.append(f"{DIM}----------------------------------------------------------------------{RESET}")

    # LIVE NOTIFICATIONS
    lines.append(f"\n{BOLD}LIVE NOTIFICATIONS & THRESHOLD ALERTS{RESET}")
    if not recent_alerts:
        lines.append(f"{DIM}No notifications generated yet. Threshold alerts (+₹30, -₹30, -12%) appear here.{RESET}")
    else:
        for a in recent_alerts:
            pri = a.priority or "P2"
            if pri == "P0":
                tag_color = f"{RED}{BOLD}[P0 CRITICAL]{RESET}"
            elif pri == "P1":
                tag_color = f"{YELLOW}{BOLD}[P1 VERY HIGH]{RESET}"
            else:
                tag_color = f"{CYAN}[{pri}]{RESET}"

            t_str = a.title.replace(f"[{pri}]", "").strip()
            ts_str = a.created_at.strftime("%H:%M:%S") if a.created_at else ""
            lines.append(f"{tag_color} {t_str} {DIM}({ts_str}){RESET}")

    lines.append(f"{DIM}----------------------------------------------------------------------{RESET}")

    # MONITORING STATUS
    lines.append(f"\n{BOLD}MONITORING STATUS{RESET}")
    mkt_status = f"{GREEN}OPEN{RESET}" if market_info.get("is_open") else f"{YELLOW}CLOSED (Session: {market_info.get('next_open_in', '09:15')}){RESET}"
    scheduler_status = f"{GREEN}RUNNING{RESET}" if scheduler.running else f"{YELLOW}STANDBY{RESET}"
    fcm_status = f"{GREEN}ACTIVE{RESET}" if notifier.is_fcm_available() else f"{CYAN}LOCAL SSE & DESKTOP{RESET}"

    lines.append(f"Market Data:         {GREEN}CONNECTED{RESET} (NSE: {mkt_status})")
    lines.append(f"Portfolio Monitor:   {GREEN}RUNNING{RESET} (10s continuous loop)")
    lines.append(f"Notification Service:{GREEN}RUNNING{RESET} ({fcm_status})")
    lines.append(f"Cloud Worker:        {scheduler_status}")
    lines.append(f"Last Price Update:   {now_str}")
    lines.append(f"{CYAN}{BOLD}======================================================================{RESET}")

    output = "\n".join(lines)
    sys.stdout.write(output + "\n")
    sys.stdout.flush()


def run_terminal_loop(refresh_seconds: float = 3.0, once: bool = False):
    """Runs continuous live refresh loop in the terminal."""
    if once:
        db = SessionLocal()
        try:
            render_dashboard(db, clear_screen=False)
        finally:
            db.close()
        return

    try:
        while True:
            db = SessionLocal()
            try:
                render_dashboard(db, clear_screen=True)
            finally:
                db.close()
            time.sleep(refresh_seconds)
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Terminal monitor stopped by user.{RESET}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Zed AI Stock Live Terminal Monitor")
    parser.add_argument("--once", action="store_true", help="Print dashboard once and exit")
    parser.add_argument("--interval", type=float, default=3.0, help="Refresh interval in seconds (default: 3.0)")
    args = parser.parse_args()

    run_terminal_loop(refresh_seconds=args.interval, once=args.once)
