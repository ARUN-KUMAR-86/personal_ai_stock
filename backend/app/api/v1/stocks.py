"""Stock universe, quote, and candlestick data endpoints."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.stock import Stock
from app.models.signal import StockSignal
from app.schemas.stock import StockRead, StockSummary
from app.schemas.candle import QuoteRead
from app.providers.factory import get_market_data_provider
from app.scanner.engine import scanner_engine

router = APIRouter(prefix="/stocks", tags=["Stocks & Quotes"])


@router.get("/universe", response_model=List[StockSummary])
def get_stock_universe(
    exchange: str = "NSE",
    sector: Optional[str] = None,
    signal_type: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Retrieves supported stock universe enriched with latest signals and prices."""
    query = db.query(Stock).filter(Stock.exchange == exchange, Stock.is_active == True)
    if sector:
        query = query.filter(Stock.sector == sector)
    stocks = query.all()

    # If empty, auto-seed
    if not stocks:
        scanner_engine.sync_universe(db, exchange=exchange)
        stocks = query.all()

    provider = get_market_data_provider()
    summaries = []

    for stock in stocks:
        # Latest signal
        latest_signal = (
            db.query(StockSignal)
            .filter(StockSignal.symbol == stock.symbol, StockSignal.exchange == exchange)
            .order_by(StockSignal.timestamp.desc())
            .first()
        )

        # Filter by signal_type if requested
        if signal_type and (not latest_signal or latest_signal.signal_type != signal_type):
            continue

        summaries.append(
            StockSummary(
                symbol=stock.symbol,
                exchange=stock.exchange,
                name=stock.name,
                sector=stock.sector,
                latest_price=latest_signal.price if latest_signal else None,
                latest_timestamp=latest_signal.timestamp if latest_signal else None,
                is_live=provider.name.lower() != "yahoo",
                latest_signal=latest_signal.signal_type if latest_signal else "NO TRADE",
                signal_strength=latest_signal.strength if latest_signal else 0.0,
            )
        )

    return summaries


@router.get("/{symbol}/quote", response_model=QuoteRead)
def get_stock_quote(symbol: str, exchange: str = "NSE"):
    """Fetches real-time or delayed quote for a specific stock."""
    provider = get_market_data_provider()
    try:
        return provider.get_quote(symbol=symbol.upper(), exchange=exchange.upper())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{symbol}/candles")
def get_stock_candles(
    symbol: str,
    exchange: str = "NSE",
    timeframe: str = "1d",
    period: str = "6mo",
):
    """Fetches historical OHLCV candlestick data for price charting."""
    provider = get_market_data_provider()
    try:
        df = provider.get_historical_ohlcv(
            symbol=symbol.upper(),
            exchange=exchange.upper(),
            timeframe=timeframe,
            period=period,
        )
        # Convert timestamp to ISO string for JSON serialization
        df["timestamp"] = df["timestamp"].astype(str)
        return df.to_dict(orient="records")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sync")
def sync_stocks(exchange: str = "NSE", db: Session = Depends(get_db)):
    """Triggers discovery and synchronization of the stock universe."""
    added = scanner_engine.sync_universe(db, exchange=exchange)
    return {"message": f"Universe synchronized. Added {added} new instruments.", "exchange": exchange}
