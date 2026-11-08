"""Market overview, indices, gainers/losers, trending, and session status endpoints.

Supports dual-market architecture:
- 🇮🇳 Indian Stock Market (NSE, BSE, NIFTY 50, Bank Nifty, Nifty IT, INR ₹)
- 🇺🇸 US Stock Market (NYSE, NASDAQ, S&P 500, NASDAQ 100, Dow Jones, USD $)
"""

from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Query, Depends
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.providers.indian_market_service import IndianMarketDataService
from app.providers.us_market_service import USMarketDataService
from app.providers.factory import get_market_data_provider

router = APIRouter(prefix="/market", tags=["Market Intelligence"])


@router.get("/overview")
def get_market_overview(
    market: str = Query("INDIA", description="Market code: INDIA or US"),
    db: Session = Depends(get_db),
):
    """
    Returns full market overview for the selected market (India or US):
    - Live trading session status (trading hours, open/close countdown)
    - Benchmark and sector indices with real prices & % changes
    - Trending stocks in the market
    - Top gainers and top losers
    - Market currency & symbols
    """
    m = market.upper().strip()
    is_us = (m == "US")
    service = USMarketDataService if is_us else IndianMarketDataService

    session_status = service.get_market_session_status()
    indices = service.get_indices()
    universe = service.get_universe()

    provider = get_market_data_provider()
    symbols = [s["symbol"] for s in universe[:20]]
    ex = "US" if is_us else "NSE"

    # Fetch live quotes for universe to calculate gainers/losers/trending
    quotes = provider.get_bulk_quotes(symbols=symbols, exchange=ex)

    stock_items = []
    for s in universe:
        sym = s["symbol"].upper()
        q = quotes.get(sym)
        price = q.price if q else 100.0
        pct = q.percent_change if q else 0.0
        change = q.change if q else 0.0
        stock_items.append({
            "symbol": sym,
            "name": s["name"],
            "exchange": s["exchange"],
            "sector": s.get("sector", "General"),
            "market": m,
            "currency": service.CURRENCY,
            "currency_symbol": service.CURRENCY_SYMBOL,
            "price": round(price, 2),
            "change": round(change, 2),
            "percent_change": round(pct, 2),
            "is_positive": pct >= 0,
        })

    # Sort gainers & losers
    sorted_stocks = sorted(stock_items, key=lambda x: x["percent_change"], reverse=True)
    gainers = [s for s in sorted_stocks if s["percent_change"] > 0][:8]
    losers = [s for s in reversed(sorted_stocks) if s["percent_change"] < 0][:8]
    trending = sorted_stocks[:12]

    return {
        "market": m,
        "market_name": "US Stock Market" if is_us else "Indian Stock Market",
        "currency": service.CURRENCY,
        "currency_symbol": service.CURRENCY_SYMBOL,
        "session_status": session_status,
        "indices": indices,
        "trending": trending,
        "trending_stocks": trending,
        "gainers": gainers,
        "top_gainers": gainers,
        "losers": losers,
        "top_losers": losers,
        "total_monitored": len(universe),
    }


@router.get("/session-status")
def get_session_status(market: str = Query("INDIA", description="Market code: INDIA or US")):
    """Returns trading session status (hours, countdown to open/close) for selected market."""
    m = market.upper().strip()
    service = USMarketDataService if m == "US" else IndianMarketDataService
    return service.get_market_session_status()


@router.get("/indices")
def get_indices(market: str = Query("INDIA", description="Market code: INDIA or US")):
    """Returns benchmark and sector indices for selected market."""
    m = market.upper().strip()
    service = USMarketDataService if m == "US" else IndianMarketDataService
    return {
        "market": m,
        "indices": service.get_indices(),
    }


@router.get("/trending")
def get_trending_stocks(market: str = Query("INDIA", description="Market code: INDIA or US")):
    """Returns high-momentum trending stocks for the selected market."""
    m = market.upper().strip()
    service = USMarketDataService if m == "US" else IndianMarketDataService
    universe = service.get_universe()
    provider = get_market_data_provider()
    symbols = [s["symbol"] for s in universe[:15]]
    quotes = provider.get_bulk_quotes(symbols, exchange="US" if m == "US" else "NSE")

    trending = []
    for s in universe[:15]:
        sym = s["symbol"].upper()
        q = quotes.get(sym)
        trending.append({
            "symbol": sym,
            "name": s["name"],
            "exchange": s["exchange"],
            "sector": s.get("sector", "General"),
            "market": m,
            "currency": service.CURRENCY,
            "currency_symbol": service.CURRENCY_SYMBOL,
            "price": round(q.price, 2) if q else 100.0,
            "percent_change": round(q.percent_change, 2) if q else 0.0,
        })
    return {"market": m, "trending_stocks": trending}


@router.get("/gainers-losers")
def get_gainers_losers(market: str = Query("INDIA", description="Market code: INDIA or US")):
    """Returns top gainers and losers for the selected market."""
    m = market.upper().strip()
    service = USMarketDataService if m == "US" else IndianMarketDataService
    universe = service.get_universe()
    provider = get_market_data_provider()
    symbols = [s["symbol"] for s in universe[:20]]
    quotes = provider.get_bulk_quotes(symbols, exchange="US" if m == "US" else "NSE")

    items = []
    for s in universe:
        sym = s["symbol"].upper()
        q = quotes.get(sym)
        pct = q.percent_change if q else 0.0
        items.append({
            "symbol": sym,
            "name": s["name"],
            "exchange": s["exchange"],
            "sector": s.get("sector", "General"),
            "market": m,
            "currency": service.CURRENCY,
            "currency_symbol": service.CURRENCY_SYMBOL,
            "price": round(q.price, 2) if q else 100.0,
            "percent_change": round(pct, 2),
        })

    sorted_items = sorted(items, key=lambda x: x["percent_change"], reverse=True)
    return {
        "market": m,
        "gainers": [s for s in sorted_items if s["percent_change"] > 0][:8],
        "losers": [s for s in reversed(sorted_items) if s["percent_change"] < 0][:8],
    }
