"""Real-Time Live Monitoring API Endpoints for Zed."""

import time
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database.session import get_db, SessionLocal
from app.models.stock import Stock
from app.models.watchlist import WatchlistItem
from app.models.signal import StockSignal
from app.models.prediction import StockPrediction
from app.providers.factory import get_market_data_provider
from app.scanner.scheduler import scheduler, get_schedule_status
from app.scanner.engine import scanner_engine

router = APIRouter(prefix="/monitoring", tags=["Live Monitoring"])

# In-memory quote cache with tick history for ultra-fast low-latency live ticks
_live_quote_cache: Dict[str, Dict[str, Any]] = {}
_last_monitoring_tick: Optional[str] = None


class LiveMonitorToggleRequest(BaseModel):
    enabled: bool
    interval_seconds: Optional[int] = 30


@router.get("/status")
def get_monitoring_status(exchange: str = "NSE", db: Session = Depends(get_db)):
    """Returns 24/7 background live monitoring engine status, latency, and market pulse."""
    t0 = time.time()
    provider = get_market_data_provider()
    market_info = provider.get_market_status(exchange=exchange)
    latency_ms = int((time.time() - t0) * 1000)

    monitored_count = db.query(Stock).filter(Stock.is_active == True).count()
    watch_count = db.query(WatchlistItem).count()

    job = scheduler.get_job("realtime_fulltime_monitor") if scheduler.running else None
    is_active = scheduler.running and job is not None

    return {
        "is_live_monitoring_active": is_active,
        "scheduler_running": scheduler.running,
        "total_monitored_stocks": monitored_count,
        "watchlist_stocks": watch_count,
        "market": market_info,
        "last_tick_time": _last_monitoring_tick or datetime.now(timezone.utc).isoformat(),
        "sync_latency_ms": max(latency_ms, 8),
        "server_time_ist": market_info.get("server_time_ist", ""),
        "app_name": "Zed",
    }


@router.get("/live-feed")
def get_live_monitoring_feed(
    exchange: str = "ALL",
    priority_only: bool = False,
    db: Session = Depends(get_db),
):
    """
    Returns real-time streaming feed of all actively monitored stocks,
    including live price ticks, tick direction (UP/DOWN/FLAT), day range,
    confluence indicators, and target/stop-loss distances.
    """
    global _last_monitoring_tick
    _last_monitoring_tick = datetime.now(timezone.utc).isoformat()

    provider = get_market_data_provider()

    # Query active stocks
    query = db.query(Stock).filter(Stock.is_active == True)
    if exchange != "ALL":
        query = query.filter(Stock.exchange == exchange)
    active_stocks = query.all()

    # Auto seed if empty
    if not active_stocks:
        scanner_engine.sync_universe(db, exchange=exchange)
        active_stocks = query.all()

    symbols = [s.symbol for s in active_stocks]
    # Fetch real-time quotes in bulk
    quotes = provider.get_bulk_quotes(symbols, exchange="NSE" if exchange == "ALL" else exchange)

    # Fetch latest signals in one query
    signals = (
        db.query(StockSignal)
        .order_by(StockSignal.timestamp.desc())
        .limit(100)
        .all()
    )
    sig_map: Dict[str, StockSignal] = {}
    for sig in signals:
        k = sig.symbol.upper()
        if k not in sig_map:
            sig_map[k] = sig

    feed_items = []
    for stock in active_stocks:
        sym = stock.symbol.upper()
        q = quotes.get(sym)
        sig = sig_map.get(sym)

        prev_cache = _live_quote_cache.get(sym, {})
        prev_price = prev_cache.get("price")

        current_price = q.price if q and q.price else (prev_price or 0.0)
        
        # Determine dynamic tick direction
        if prev_price and current_price:
            if current_price > prev_price:
                tick_dir = "UP"
            elif current_price < prev_price:
                tick_dir = "DOWN"
            else:
                tick_dir = prev_cache.get("tick_direction", "FLAT")
        else:
            tick_dir = "UP" if (q and q.change > 0) else ("DOWN" if (q and q.change < 0) else "FLAT")

        # Update cache
        _live_quote_cache[sym] = {
            "price": current_price,
            "tick_direction": tick_dir,
            "timestamp": _last_monitoring_tick,
        }

        # Target and SL calculations
        target = sig.target if sig else None
        stop_loss = sig.stop_loss if sig else None
        target_dist_pct = None
        sl_dist_pct = None

        if current_price and target:
            target_dist_pct = round(((target - current_price) / current_price) * 100, 2)
        if current_price and stop_loss:
            sl_dist_pct = round(((current_price - stop_loss) / current_price) * 100, 2)

        # Confluence metrics
        metrics = sig.indicator_summary if (sig and sig.indicator_summary) else {}
        rsi = metrics.get("rsi_14")
        st_dir = metrics.get("supertrend_dir", 1)
        adx = metrics.get("adx_14")

        is_high_pri = (sig and sig.priority == "HIGH") or (target_dist_pct and target_dist_pct > 5.0)

        if priority_only and not is_high_pri:
            continue

        feed_items.append({
            "symbol": sym,
            "name": stock.name or sym,
            "exchange": stock.exchange,
            "sector": stock.sector or "General",
            "price": current_price,
            "previous_close": q.previous_close if q else None,
            "change": q.change if q else 0.0,
            "percent_change": q.percent_change if q else 0.0,
            "day_high": q.high if q else None,
            "day_low": q.low if q else None,
            "volume": q.volume if q else None,
            "tick_direction": tick_dir,
            "is_live": q.is_live if q else True,
            "timestamp": q.timestamp.isoformat() if (q and q.timestamp) else _last_monitoring_tick,
            "signal_type": sig.signal_type if sig else "NO TRADE",
            "signal_priority": sig.priority if sig else "MEDIUM",
            "signal_strength": sig.strength if sig else 0.0,
            "target_price": target,
            "stop_loss_price": stop_loss,
            "target_distance_pct": target_dist_pct,
            "sl_distance_pct": sl_dist_pct,
            "rsi": rsi,
            "supertrend_direction": "BULLISH" if st_dir == 1 else "BEARISH",
            "adx": adx,
        })

    # Sort so top movers or highest priority appear first
    feed_items.sort(key=lambda x: (x["signal_priority"] == "HIGH", abs(x.get("percent_change") or 0.0)), reverse=True)

    return {
        "status": "SUCCESS",
        "count": len(feed_items),
        "timestamp": _last_monitoring_tick,
        "items": feed_items,
    }


@router.post("/quick-scan")
def trigger_quick_scan(db: Session = Depends(get_db)):
    """Triggers an immediate high-speed live monitoring scan of all priority monitored instruments."""
    from app.scanner.engine import scanner_engine
    if scanner_engine.is_scanning:
        return {"status": "ALREADY_SCANNING", "message": "Live monitor scan currently in progress."}

    # Execute priority scan
    scanner_engine.run_scan(db=db, exchange="NSE", force=True)
    return {"status": "COMPLETED", "message": "Priority live monitor scan finished successfully."}
