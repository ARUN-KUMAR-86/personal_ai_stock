"""Stock universe, quote, dynamic search, and Gemini AI prediction endpoints."""

from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.stock import Stock
from app.models.signal import StockSignal
from app.models.prediction import StockPrediction
from app.schemas.stock import StockRead, StockSummary
from app.schemas.candle import QuoteRead
from app.schemas.prediction import PredictionRead, PredictionRequest
from app.providers.factory import get_market_data_provider
from app.scanner.engine import scanner_engine
from app.analysis.gemini_predictor import gemini_stock_predictor

router = APIRouter(prefix="/stocks", tags=["Stocks & Quotes"])


class AddStockRequest(BaseModel):
    symbol: str
    exchange: str = "NSE"
    name: Optional[str] = None
    sector: Optional[str] = None


@router.get("/universe", response_model=List[StockSummary])
def get_stock_universe(
    exchange: str = "NSE",
    sector: Optional[str] = None,
    signal_type: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Retrieves supported stock universe enriched with real-time quotes, signals, and Gemini AI predictions."""
    query = db.query(Stock).filter(Stock.is_active == True)
    if exchange != "ALL":
        query = query.filter(Stock.exchange == exchange)
    if sector:
        query = query.filter(Stock.sector == sector)
    stocks = query.all()

    # If empty, auto-seed
    if not stocks:
        scanner_engine.sync_universe(db, exchange=exchange)
        stocks = query.all()

    provider = get_market_data_provider()
    symbols = [s.symbol for s in stocks]
    
    # Bulk fetch live quotes
    bulk_quotes = provider.get_bulk_quotes(symbols=symbols, exchange=exchange if exchange != "ALL" else "NSE")

    summaries = []
    for stock in stocks:
        # Latest signal
        latest_signal = (
            db.query(StockSignal)
            .filter(StockSignal.symbol == stock.symbol, StockSignal.exchange == stock.exchange)
            .order_by(StockSignal.timestamp.desc())
            .first()
        )

        # Latest Gemini prediction
        latest_pred = (
            db.query(StockPrediction)
            .filter(StockPrediction.symbol == stock.symbol, StockPrediction.exchange == stock.exchange)
            .order_by(StockPrediction.created_at.desc())
            .first()
        )

        # Filter by signal_type if requested
        if signal_type and (not latest_signal or latest_signal.signal_type != signal_type):
            continue

        quote = bulk_quotes.get(stock.symbol.upper())

        # Determine best price and timestamps
        current_price = quote.price if quote else (latest_signal.price if latest_signal else None)
        price_change = quote.change if quote else 0.0
        pct_change = quote.percent_change if quote else 0.0
        is_live_quote = quote.is_live if quote else (provider.name.lower() != "yahoo")
        last_ts = quote.timestamp if quote else (latest_signal.timestamp if latest_signal else None)

        pred_dir = latest_pred.predicted_direction if latest_pred else (
            "BULLISH" if latest_signal and "BUY" in latest_signal.signal_type else None
        )
        pred_target = latest_pred.target_price if latest_pred else (
            latest_signal.target if latest_signal else None
        )
        pred_conf = latest_pred.confidence_score if latest_pred else (
            latest_signal.strength if latest_signal else None
        )
        sig_priority = (
            latest_signal.priority if (latest_signal and latest_signal.priority)
            else ("HIGH" if (pred_conf and pred_conf >= 75) else "MEDIUM")
        )

        summaries.append(
            StockSummary(
                symbol=stock.symbol,
                exchange=stock.exchange,
                name=stock.name,
                sector=stock.sector,
                latest_price=current_price,
                latest_timestamp=last_ts,
                is_live=is_live_quote,
                latest_signal=latest_signal.signal_type if latest_signal else "NO TRADE",
                signal_strength=latest_signal.strength if latest_signal else (pred_conf or 0.0),
                change=price_change,
                percent_change=pct_change,
                day_high=quote.high if quote else None,
                day_low=quote.low if quote else None,
                volume=quote.volume if quote else None,
                predicted_direction=pred_dir,
                predicted_target=pred_target,
                predicted_confidence=pred_conf,
                priority=sig_priority,
            )
        )

    return summaries


@router.get("/search")
def search_stocks(
    q: str = Query(..., description="Stock symbol or company name"),
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """
    Dynamically searches local database and internet / Yahoo Finance for any stock or IPO.
    Returns matched instruments with real-time price and universe inclusion status.
    """
    provider = get_market_data_provider()
    found = provider.search_stocks(query=q, exchange=exchange)

    # Check which ones are already in local DB
    existing_symbols = {
        s.symbol.upper(): s for s in db.query(Stock).filter(Stock.is_active == True).all()
    }

    results = []
    symbols_to_quote = [item["symbol"] for item in found[:10]]
    quotes_map = provider.get_bulk_quotes(symbols_to_quote, exchange=exchange)

    for item in found:
        sym = item["symbol"].upper()
        in_db = sym in existing_symbols
        quote = quotes_map.get(sym)

        results.append({
            "symbol": sym,
            "name": item.get("name", sym),
            "exchange": item.get("exchange", exchange),
            "sector": item.get("sector", "General"),
            "price": quote.price if quote else None,
            "change": quote.change if quote else 0.0,
            "percent_change": quote.percent_change if quote else 0.0,
            "is_in_universe": in_db,
        })

    return results


@router.post("/add", response_model=StockSummary)
def add_stock_to_universe(item: AddStockRequest, db: Session = Depends(get_db)):
    """
    Adds a newly discovered stock (e.g. Jio / JPL / JIOFIN) into the active universe,
    fetches its live quote and initial history, and makes it available for AI prediction and scanning.
    """
    sym = item.symbol.strip().upper()
    ex = item.exchange.strip().upper()

    existing = db.query(Stock).filter(Stock.symbol == sym, Stock.exchange == ex).first()
    if existing:
        existing.is_active = True
        stock = existing
    else:
        provider = get_market_data_provider()
        name = item.name
        sector = item.sector
        if not name:
            search_res = provider.search_stocks(sym, exchange=ex)
            for r in search_res:
                if r["symbol"].upper() == sym:
                    name = r.get("name")
                    sector = sector or r.get("sector")
                    break

        stock = Stock(
            symbol=sym,
            exchange=ex,
            name=name or sym,
            sector=sector or "General",
            is_active=True,
        )
        db.add(stock)

    db.commit()
    db.refresh(stock)

    # Fetch live quote
    provider = get_market_data_provider()
    try:
        quote = provider.get_quote(sym, ex)
    except Exception:
        quote = None

    return StockSummary(
        symbol=stock.symbol,
        exchange=stock.exchange,
        name=stock.name,
        sector=stock.sector,
        latest_price=quote.price if quote else None,
        latest_timestamp=quote.timestamp if quote else datetime.now(timezone.utc),
        is_live=quote.is_live if quote else False,
        latest_signal="NO TRADE",
        signal_strength=0.0,
        change=quote.change if quote else 0.0,
        percent_change=quote.percent_change if quote else 0.0,
        day_high=quote.high if quote else None,
        day_low=quote.low if quote else None,
        volume=quote.volume if quote else None,
        priority="MEDIUM",
    )


@router.get("/live-quotes")
def get_live_quotes(exchange: str = "NSE", db: Session = Depends(get_db)):
    """Returns a consolidated dictionary of real-time quotes for all active universe stocks."""
    stocks = db.query(Stock).filter(Stock.is_active == True).all()
    symbols = [s.symbol for s in stocks]
    provider = get_market_data_provider()
    quotes = provider.get_bulk_quotes(symbols, exchange=exchange)
    return {
        sym: {
            "symbol": q.symbol,
            "exchange": q.exchange,
            "price": q.price,
            "change": q.change,
            "percent_change": q.percent_change,
            "open": q.open,
            "high": q.high,
            "low": q.low,
            "previous_close": q.previous_close,
            "volume": q.volume,
            "is_live": q.is_live,
            "timestamp": q.timestamp.isoformat() if q.timestamp else None,
        }
        for sym, q in quotes.items()
    }


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


@router.post("/{symbol}/predict", response_model=PredictionRead)
def predict_stock(
    symbol: str,
    req: Optional[PredictionRequest] = None,
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """
    Triggers on-demand real-time stock prediction powered by Google Gemini AI
    and the quantitative confluence working algorithm.
    """
    sym = symbol.upper().strip()
    ex = (req.exchange if req else exchange).upper()
    horizon_raw = (req.time_horizon if req else "1-DAY").upper()
    horizon = "1-MONTH" if "MONTH" in horizon_raw else "1-DAY"

    stock = db.query(Stock).filter(Stock.symbol == sym, Stock.exchange == ex).first()
    comp_name = stock.name if stock else sym

    try:
        pred_dict = gemini_stock_predictor.predict_stock(
            symbol=sym,
            company_name=comp_name,
            exchange=ex,
            time_horizon=horizon,
        )

        # Store in StockPrediction table
        record = StockPrediction(
            symbol=sym,
            exchange=ex,
            company_name=comp_name,
            price_at_prediction=pred_dict["price_at_prediction"],
            predicted_direction=pred_dict["predicted_direction"],
            predicted_action=pred_dict["predicted_action"],
            target_price=pred_dict["target_price"],
            expected_gain_pct=pred_dict["expected_gain_pct"],
            stop_loss=pred_dict["stop_loss"],
            confidence_score=pred_dict["confidence_score"],
            time_horizon=pred_dict["time_horizon"],
            algorithm_name=pred_dict["algorithm_name"],
            working_algorithm=pred_dict["working_algorithm"],
            algorithm_metrics=pred_dict["algorithm_metrics"],
            ai_prediction_summary=pred_dict["ai_prediction_summary"],
            key_catalysts=pred_dict["key_catalysts"],
            risk_assessment=pred_dict["risk_assessment"],
            invalidation_trigger=pred_dict["invalidation_trigger"],
            model_used=pred_dict["model_used"],
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        return record
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Prediction error for {sym}: {str(e)}")


@router.get("/{symbol}/prediction", response_model=PredictionRead)
def get_stock_prediction(
    symbol: str,
    exchange: str = "NSE",
    time_horizon: str = "1-DAY",
    db: Session = Depends(get_db),
):
    """Retrieves the latest AI stock prediction or generates a new one on-demand."""
    sym = symbol.upper().strip()
    ex = exchange.upper()
    is_month = "MONTH" in time_horizon.upper()
    horizon_clean = "1-MONTH" if is_month else "1-DAY"
    horizon_pattern = "%MONTH%" if is_month else "%1-DAY%"

    latest = (
        db.query(StockPrediction)
        .filter(
            StockPrediction.symbol == sym,
            StockPrediction.exchange == ex,
            StockPrediction.time_horizon.like(horizon_pattern),
        )
        .order_by(StockPrediction.created_at.desc())
        .first()
    )
    if latest:
        return latest

    # If none exists yet, generate one right away for the requested horizon
    return predict_stock(
        symbol=sym,
        exchange=ex,
        req=PredictionRequest(symbol=sym, exchange=ex, time_horizon=horizon_clean),
        db=db,
    )


@router.get("/predictions/top", response_model=List[PredictionRead])
def get_top_predictions(limit: int = 10, db: Session = Depends(get_db)):
    """Retrieves top real-time AI predictions sorted by highest confidence."""
    preds = (
        db.query(StockPrediction)
        .order_by(StockPrediction.confidence_score.desc(), StockPrediction.created_at.desc())
        .limit(limit)
        .all()
    )
    return preds


@router.get("/{symbol}/thesis")
def get_stock_ai_thesis(
    symbol: str,
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """Fetches or generates an on-demand explainable AI thesis for any stock symbol."""
    from app.strategies.registry import strategy_registry

    # Check if a recent signal already has an AI thesis
    latest_sig = (
        db.query(StockSignal)
        .filter(StockSignal.symbol == symbol.upper(), StockSignal.exchange == exchange.upper())
        .order_by(StockSignal.created_at.desc())
        .first()
    )
    if latest_sig and latest_sig.ai_thesis:
        return latest_sig.ai_thesis

    provider = get_market_data_provider()
    df = provider.get_historical_ohlcv(symbol=symbol.upper(), exchange=exchange.upper())
    if df.empty or len(df) < 10:
        raise HTTPException(status_code=404, detail=f"Insufficient history to generate thesis for {symbol}")

    strat = strategy_registry.get("GeminiPredictiveAI") or strategy_registry.get("MomentumBreakout") or strategy_registry.get_all()[0]
    sig = strat.evaluate(df=df, symbol=symbol.upper(), exchange=exchange.upper())
    return sig.ai_thesis
