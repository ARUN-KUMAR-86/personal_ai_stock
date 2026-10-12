"""User-managed persistent watchlist API endpoints."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.watchlist import WatchlistItem
from app.models.stock import Stock
from app.models.signal import StockSignal
from app.schemas.watchlist import WatchlistItemRead, WatchlistItemCreate
from app.schemas.stock import StockSummary
from app.scanner.engine import scanner_engine
from app.providers.factory import get_market_data_provider

router = APIRouter(prefix="/watchlist", tags=["Watchlist"])


@router.get("", response_model=List[WatchlistItemRead])
def get_watchlist(
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """Retrieves all watchlisted stocks enriched with latest prices and AI signals."""
    items = (
        db.query(WatchlistItem)
        .filter(WatchlistItem.exchange == exchange.upper())
        .order_by(WatchlistItem.created_at.desc())
        .all()
    )

    provider = get_market_data_provider()
    results = []

    for item in items:
        stock = (
            db.query(Stock)
            .filter(Stock.symbol == item.symbol, Stock.exchange == item.exchange)
            .first()
        )
        latest_sig = (
            db.query(StockSignal)
            .filter(StockSignal.symbol == item.symbol, StockSignal.exchange == item.exchange)
            .order_by(StockSignal.created_at.desc())
            .first()
        )

        stock_summary = StockSummary(
            symbol=item.symbol,
            exchange=item.exchange,
            name=stock.name if stock else item.symbol,
            sector=stock.sector if stock else None,
            latest_price=latest_sig.price if latest_sig else None,
            latest_timestamp=latest_sig.timestamp if latest_sig else None,
            is_live=provider.name.lower() != "yahoo",
            latest_signal=latest_sig.signal_type if latest_sig else "NO TRADE",
            signal_strength=latest_sig.strength if latest_sig else 0.0,
        )

        read_item = WatchlistItemRead(
            id=item.id,
            symbol=item.symbol,
            exchange=item.exchange,
            notes=item.notes,
            created_at=item.created_at,
            stock=stock_summary,
        )
        results.append(read_item)

    return results


@router.post("/scan")
def scan_watchlist_stocks(
    exchange: str = "NSE",
    force: bool = True,
    db: Session = Depends(get_db),
):
    """Triggers an on-demand scanning pass over all watchlisted stocks."""
    items = (
        db.query(WatchlistItem)
        .filter(WatchlistItem.exchange == exchange.upper())
        .all()
    )
    if not items:
        return {"message": "Watchlist is empty. Add stocks first to run a watchlist scan.", "total_scanned": 0}

    symbols = [it.symbol for it in items]
    job = scanner_engine.run_scan(db=db, symbols=symbols, exchange=exchange, force=force)
    return {
        "message": f"Watchlist scan executed for {len(symbols)} stocks.",
        "job_id": job.id if job else None,
        "scanned_stocks": job.scanned_stocks if job else len(symbols),
        "passed_signals": job.passed_signals if job else 0,
    }


@router.post("/{symbol}", response_model=WatchlistItemRead)
def add_to_watchlist(
    symbol: str,
    exchange: str = "NSE",
    notes: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Adds a stock symbol to the persistent user watchlist."""
    sym = symbol.upper()
    exch = exchange.upper()

    existing = (
        db.query(WatchlistItem)
        .filter(WatchlistItem.symbol == sym, WatchlistItem.exchange == exch)
        .first()
    )
    if existing:
        if notes is not None:
            existing.notes = notes
            db.commit()
            db.refresh(existing)
        return WatchlistItemRead(
            id=existing.id,
            symbol=existing.symbol,
            exchange=existing.exchange,
            notes=existing.notes,
            created_at=existing.created_at,
        )

    # Ensure stock exists in universe or seed it
    stock = db.query(Stock).filter(Stock.symbol == sym, Stock.exchange == exch).first()
    if not stock:
        stock = Stock(symbol=sym, exchange=exch, name=sym, is_active=True)
        db.add(stock)
        db.commit()

    item = WatchlistItem(symbol=sym, exchange=exch, notes=notes)
    db.add(item)
    db.commit()
    db.refresh(item)

    return WatchlistItemRead(
        id=item.id,
        symbol=item.symbol,
        exchange=item.exchange,
        notes=item.notes,
        created_at=item.created_at,
    )


@router.delete("/{symbol}")
def remove_from_watchlist(
    symbol: str,
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """Removes a stock from the user watchlist."""
    sym = symbol.upper()
    exch = exchange.upper()
    item = (
        db.query(WatchlistItem)
        .filter(WatchlistItem.symbol == sym, WatchlistItem.exchange == exch)
        .first()
    )
    if not item:
        return {"message": f"{sym} was not in watchlist", "removed": False}

    db.delete(item)
    db.commit()
    return {"message": f"{sym} removed from watchlist", "removed": True}


@router.get("/check/{symbol}")
def check_is_watchlisted(
    symbol: str,
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """Checks whether a symbol is currently on the watchlist."""
    sym = symbol.upper()
    exch = exchange.upper()
    exists = (
        db.query(WatchlistItem)
        .filter(WatchlistItem.symbol == sym, WatchlistItem.exchange == exch)
        .first()
        is not None
    )
    return {"symbol": sym, "exchange": exch, "is_watchlisted": exists}
