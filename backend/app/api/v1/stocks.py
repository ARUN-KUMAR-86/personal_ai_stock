"""Stock universe, quote, dynamic search, and Gemini AI prediction endpoints."""

from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.logging import logger
from app.database.session import get_db
from app.models.stock import Stock
from app.models.signal import StockSignal
from app.models.prediction import StockPrediction
from app.schemas.stock import StockRead, StockSummary
from app.schemas.candle import QuoteRead
from app.schemas.prediction import PredictionRead, PredictionRequest
from app.providers.factory import get_market_data_provider
from app.providers.indian_market_service import IndianMarketDataService
from app.providers.us_market_service import USMarketDataService
from app.analysis.complete_analyzer import CompleteStockAnalyzer
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
    time_horizon: str = "1-DAY",
    db: Session = Depends(get_db),
):
    """Retrieves supported stock universe enriched with real-time quotes, signals, and Gemini AI predictions."""
    is_month = "MONTH" in (time_horizon or "1-DAY").upper()
    horizon_clean = "1-MONTH" if is_month else "1-DAY"
    horizon_pattern = "%MONTH%" if is_month else "%1-DAY%"

    query = db.query(Stock).filter(Stock.is_active == True)
    if exchange != "ALL":
        if exchange.upper() in ("US", "NASDAQ", "NYSE"):
            query = query.filter(Stock.exchange.in_(["US", "NASDAQ", "NYSE"]))
        elif exchange.upper() in ("NSE", "BSE", "INDIA"):
            query = query.filter(Stock.exchange.in_(["NSE", "BSE"]))
        else:
            query = query.filter(Stock.exchange == exchange)
    if sector:
        query = query.filter(Stock.sector == sector)
    stocks = query.all()

    # If empty, auto-seed
    if not stocks:
        scanner_engine.sync_universe(db, exchange=exchange)
        query = db.query(Stock).filter(Stock.is_active == True)
        if exchange != "ALL":
            if exchange.upper() in ("US", "NASDAQ", "NYSE"):
                query = query.filter(Stock.exchange.in_(["US", "NASDAQ", "NYSE"]))
            elif exchange.upper() in ("NSE", "BSE", "INDIA"):
                query = query.filter(Stock.exchange.in_(["NSE", "BSE"]))
            else:
                query = query.filter(Stock.exchange == exchange)
        if sector:
            query = query.filter(Stock.sector == sector)
        stocks = query.all()

    provider = get_market_data_provider()
    symbols = [s.symbol for s in stocks]
    
    # Bulk fetch live quotes segmented by respective market exchange
    nse_symbols = [s.symbol for s in stocks if s.exchange.upper() in ("NSE", "BSE", "INDIA")]
    us_symbols = [s.symbol for s in stocks if s.exchange.upper() in ("US", "NASDAQ", "NYSE")]
    other_symbols = [s.symbol for s in stocks if s.symbol not in nse_symbols and s.symbol not in us_symbols]

    bulk_quotes = {}
    if nse_symbols:
        bulk_quotes.update(provider.get_bulk_quotes(symbols=nse_symbols, exchange="NSE"))
    if us_symbols:
        bulk_quotes.update(provider.get_bulk_quotes(symbols=us_symbols, exchange="US"))
    if other_symbols:
        bulk_quotes.update(provider.get_bulk_quotes(symbols=other_symbols, exchange=exchange))

    summaries = []
    for stock in stocks:
        # Latest signal
        latest_signal = (
            db.query(StockSignal)
            .filter(StockSignal.symbol == stock.symbol, StockSignal.exchange == stock.exchange)
            .order_by(StockSignal.timestamp.desc())
            .first()
        )

        # Latest Gemini prediction matching the requested horizon
        latest_pred = (
            db.query(StockPrediction)
            .filter(
                StockPrediction.symbol == stock.symbol,
                StockPrediction.exchange == stock.exchange,
                StockPrediction.time_horizon.like(horizon_pattern),
            )
            .order_by(StockPrediction.created_at.desc())
            .first()
        )
        if not latest_pred:
            latest_pred = (
                db.query(StockPrediction)
                .filter(
                    StockPrediction.symbol == stock.symbol,
                    StockPrediction.exchange == stock.exchange,
                )
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

        # Calibrate target based on horizon if needed
        pred_target = None
        if latest_pred and latest_pred.target_price:
            pred_target = latest_pred.target_price
            if is_month and "DAY" in (latest_pred.time_horizon or "").upper() and current_price:
                pred_target = round(current_price * 1.12 if pred_dir == "BULLISH" else current_price * 0.90, 2)
            elif not is_month and "MONTH" in (latest_pred.time_horizon or "").upper() and current_price:
                pred_target = round(current_price * 1.035 if pred_dir == "BULLISH" else current_price * 0.97, 2)
        elif latest_signal and latest_signal.target:
            pred_target = latest_signal.target
            if is_month and current_price:
                pred_target = round(current_price * 1.12 if pred_dir == "BULLISH" else current_price * 0.90, 2)
        elif current_price:
            pred_target = round(current_price * (1.12 if is_month else 1.035) if pred_dir == "BULLISH" else current_price * (0.90 if is_month else 0.97), 2)

        pred_conf = latest_pred.confidence_score if latest_pred else (
            latest_signal.strength if latest_signal else 50.0
        )

        # Standard Institutional Priority Classification: P0 to P4
        raw_pri = (latest_signal.priority if latest_signal else None) or ""
        if raw_pri.upper() in ("P0", "P1", "P2", "P3", "P4"):
            sig_priority = raw_pri.upper()
        elif "CRITICAL" in raw_pri.upper() or pred_conf >= 90.0:
            sig_priority = "P0"
        elif raw_pri.upper() in ("VERY HIGH", "HIGH") or pred_conf >= 80.0:
            sig_priority = "P1"
        elif pred_conf >= 70.0:
            sig_priority = "P2"
        elif pred_conf >= 55.0:
            sig_priority = "P3"
        else:
            sig_priority = "P4"

        # Calculate entry zone
        cur_sym = "$" if stock.exchange.upper() in ("US", "NASDAQ", "NYSE") else "₹"
        entry_zone_str = None
        if latest_signal and latest_signal.entry_range_low and latest_signal.entry_range_high:
            entry_zone_str = f"{cur_sym}{latest_signal.entry_range_low:.2f} - {cur_sym}{latest_signal.entry_range_high:.2f}"
        elif current_price:
            entry_zone_str = f"{cur_sym}{current_price * 0.995:.2f} - {cur_sym}{current_price * 1.005:.2f}"

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
                signal_strength=latest_signal.strength if latest_signal else pred_conf,
                change=price_change,
                percent_change=pct_change,
                day_high=quote.high if quote else None,
                day_low=quote.low if quote else None,
                volume=quote.volume if quote else None,
                predicted_direction=pred_dir,
                predicted_target=pred_target,
                predicted_confidence=pred_conf,
                time_horizon=horizon_clean,
                priority=sig_priority,
                entry_zone=entry_zone_str,
                stop_loss=latest_signal.stop_loss if latest_signal else (current_price * 0.97 if current_price else None),
                target_price=pred_target,
                risk_reward=latest_signal.risk_reward if latest_signal else 2.0,
                supporting_indicators=latest_signal.indicator_summary if latest_signal else {},
                main_reasons=latest_signal.explanation if latest_signal else "Multi-indicator quantitative confluence baseline.",
                data_freshness="Verified Real-Time Feed" if is_live_quote else "End of Day Market Data",
                data_available=bool(current_price and current_price > 0),
            )
        )

    # Enforce strict institutional priority sorting: P0 -> P1 -> P2 -> P3 -> P4
    # Within each category, rank by research score and signal strength descending
    priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3, "P4": 4}
    summaries.sort(
        key=lambda s: (
            priority_order.get(s.priority or "P4", 9),
            -(s.predicted_confidence or s.signal_strength or 0.0),
            -(abs(s.percent_change or 0.0)),
        )
    )

    return summaries


@router.get("/search")
def search_stocks(
    q: str = Query(..., description="Stock symbol or company name"),
    exchange: str = "NSE",
    market: Optional[str] = Query(None, description="Optional market filter: INDIA or US"),
    db: Session = Depends(get_db),
):
    """
    Dynamically searches stocks strictly within the selected market (India or US).
    Never mixes Indian and US stocks.
    """
    m = (market or "").upper().strip()
    if m == "US" or exchange.upper() in ("US", "NASDAQ", "NYSE"):
        found = USMarketDataService.search_stocks(query=q)
        active_exchange = "US"
    elif m in ("INDIA", "NSE", "BSE") or exchange.upper() in ("NSE", "BSE"):
        found = IndianMarketDataService.search_stocks(query=q)
        active_exchange = "NSE"
    else:
        provider = get_market_data_provider()
        found = provider.search_stocks(query=q, exchange=exchange)
        active_exchange = exchange

    # Check which ones are already in local DB
    existing_symbols = {
        s.symbol.upper(): s for s in db.query(Stock).filter(Stock.is_active == True).all()
    }

    provider = get_market_data_provider()
    results = []
    symbols_to_quote = [item["symbol"] for item in found[:10]]
    quotes_map = provider.get_bulk_quotes(symbols_to_quote, exchange=active_exchange)

    for item in found:
        sym = item["symbol"].upper()
        in_db = sym in existing_symbols
        quote = quotes_map.get(sym)

        results.append({
            "symbol": sym,
            "name": item.get("name", sym),
            "exchange": item.get("exchange", active_exchange),
            "sector": item.get("sector", "General"),
            "market": item.get("market", "US" if active_exchange == "US" else "INDIA"),
            "currency": item.get("currency", "USD" if active_exchange == "US" else "INR"),
            "currency_symbol": item.get("currency_symbol", "$" if active_exchange == "US" else "₹"),
            "price": quote.price if quote else None,
            "change": quote.change if quote else 0.0,
            "percent_change": quote.percent_change if quote else 0.0,
            "is_in_universe": in_db,
        })

    return results


@router.get("/{symbol}/complete-analysis")
def get_complete_stock_analysis(
    symbol: str,
    market: str = Query("INDIA", description="Market code: INDIA or US"),
    exchange: Optional[str] = Query(None, description="Optional exchange: NSE, BSE, NASDAQ, NYSE, US"),
    time_horizon: str = Query("1-DAY", description="1-DAY or 1-MONTH horizon"),
    db: Session = Depends(get_db),
):
    """
    Performs complete independent 15-dimension research for the selected stock.
    Does not mix Indian and US market data or predictions.
    Stores and updates prediction history in database.
    """
    analysis = CompleteStockAnalyzer.analyze_stock(
        symbol=symbol,
        market=market,
        exchange=exchange,
        time_horizon=time_horizon,
    )

    # Persist or update in StockPrediction table
    try:
        sym = symbol.upper().strip()
        ex = analysis["exchange"]
        existing = (
            db.query(StockPrediction)
            .filter(StockPrediction.symbol == sym, StockPrediction.exchange == ex)
            .first()
        )
        if not existing:
            existing = StockPrediction(
                symbol=sym,
                exchange=ex,
                company_name=analysis["company_name"],
                price_at_prediction=analysis["current_price"],
                predicted_direction=analysis["expected_price_movement"]["direction"],
                predicted_action=analysis["signal"],
                target_price=analysis["target_1"],
                expected_gain_pct=analysis["expected_price_movement"]["change_pct"],
                stop_loss=analysis["stop_loss"],
                confidence_score=analysis["confidence_score"],
                time_horizon=time_horizon,
                algorithm_name="Dual-Market Complete AI Analyzer",
                working_algorithm="\n".join(analysis["reasons_supporting_prediction"]),
                algorithm_metrics=analysis["technical_indicators"],
                ai_prediction_summary=analysis["short_term_prediction"],
                key_catalysts=analysis["reasons_supporting_prediction"],
                risk_assessment=analysis["risk_factors"],
                invalidation_trigger=analysis["invalidation_condition"],
                created_at=datetime.now(timezone.utc),
            )
            db.add(existing)
        else:
            existing.price_at_prediction = analysis["current_price"]
            existing.predicted_direction = analysis["expected_price_movement"]["direction"]
            existing.predicted_action = analysis["signal"]
            existing.target_price = analysis["target_1"]
            existing.expected_gain_pct = analysis["expected_price_movement"]["change_pct"]
            existing.stop_loss = analysis["stop_loss"]
            existing.confidence_score = analysis["confidence_score"]
            existing.working_algorithm = "\n".join(analysis["reasons_supporting_prediction"])
            existing.algorithm_metrics = analysis["technical_indicators"]
            existing.ai_prediction_summary = analysis["short_term_prediction"]
            existing.key_catalysts = analysis["reasons_supporting_prediction"]
            existing.risk_assessment = analysis["risk_factors"]
            existing.invalidation_trigger = analysis["invalidation_condition"]
            existing.updated_at = datetime.now(timezone.utc)
        db.commit()
    except Exception as save_err:
        logger.warning(f"Note: Could not save prediction to db: {save_err}")
        db.rollback()

    return analysis


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
    query = db.query(Stock).filter(Stock.is_active == True)
    if exchange.upper() in ("US", "NASDAQ", "NYSE"):
        stocks = query.filter(Stock.exchange.in_(["US", "NASDAQ", "NYSE"])).all()
        target_ex = "US"
    elif exchange.upper() in ("NSE", "BSE", "INDIA"):
        stocks = query.filter(Stock.exchange.in_(["NSE", "BSE", "INDIA"])).all()
        target_ex = "NSE"
    else:
        stocks = query.all()
        target_ex = exchange

    # Bulk fetch segmented by proper exchange so US symbols don't get queried as .NS and vice-versa
    nse_symbols = [s.symbol for s in stocks if s.exchange.upper() in ("NSE", "BSE", "INDIA")]
    us_symbols = [s.symbol for s in stocks if s.exchange.upper() in ("US", "NASDAQ", "NYSE")]
    other_symbols = [s.symbol for s in stocks if s.symbol not in nse_symbols and s.symbol not in us_symbols]

    quotes = {}
    provider = get_market_data_provider()
    if nse_symbols:
        quotes.update(provider.get_bulk_quotes(nse_symbols, exchange="NSE"))
    if us_symbols:
        quotes.update(provider.get_bulk_quotes(us_symbols, exchange="US"))
    if other_symbols:
        quotes.update(provider.get_bulk_quotes(other_symbols, exchange=target_ex))

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

        # Store in StockPrediction table with full continuous validation metadata
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
            prob_up=pred_dict.get("prob_up"),
            prob_down=pred_dict.get("prob_down"),
            prob_sideways=pred_dict.get("prob_sideways"),
            market_regime=pred_dict.get("market_regime"),
            candlestick_patterns=pred_dict.get("candlestick_patterns"),
            dimension_scores=pred_dict.get("dimension_scores"),
            approval_status=pred_dict.get("approval_status", "APPROVED"),
            outcome_status=pred_dict.get("outcome_status", "PENDING"),
            model_version=pred_dict.get("model_version", "v2.0-ensemble"),
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


@router.get("/predictions/accuracy")
def get_prediction_accuracy(db: Session = Depends(get_db)):
    """Returns actual empirical accuracy metrics recalculated against verified market outcomes."""
    from app.analysis.prediction_validator import PredictionValidator
    return PredictionValidator.get_accuracy_report(db)


@router.post("/predictions/validate")
def validate_predictions(force_all: bool = False, db: Session = Depends(get_db)):
    """Triggers validation pass checking pending predictions against actual post-event market bars."""
    from app.analysis.prediction_validator import PredictionValidator
    result = PredictionValidator.validate_pending_predictions(db, force_all=force_all)
    return {"message": "Prediction validation complete", **result}


@router.get("/predictions/history", response_model=List[PredictionRead])
def get_prediction_history(limit: int = 50, db: Session = Depends(get_db)):
    """Retrieves prediction history with actual outcomes and verification results."""
    records = (
        db.query(StockPrediction)
        .order_by(StockPrediction.created_at.desc())
        .limit(limit)
        .all()
    )
    return records


@router.get("/predictions/top", response_model=List[PredictionRead])
def get_top_predictions(
    limit: int = 10,
    exchange: Optional[str] = None,
    time_horizon: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Retrieves top real-time AI predictions sorted by highest confidence."""
    query = db.query(StockPrediction)
    if exchange and exchange != "ALL":
        if exchange.upper() in ("US", "NASDAQ", "NYSE"):
            query = query.filter(StockPrediction.exchange.in_(["US", "NASDAQ", "NYSE"]))
        elif exchange.upper() in ("NSE", "BSE", "INDIA"):
            query = query.filter(StockPrediction.exchange.in_(["NSE", "BSE"]))
        else:
            query = query.filter(StockPrediction.exchange == exchange.upper())
    if time_horizon:
        is_month = "MONTH" in time_horizon.upper()
        pat = "%MONTH%" if is_month else "%1-DAY%"
        query = query.filter(StockPrediction.time_horizon.like(pat))
    preds = (
        query
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
        thesis = dict(latest_sig.ai_thesis)
        if "catalysts" not in thesis:
            thesis["catalysts"] = [
                f"Multi-indicator confluence support for {latest_sig.symbol}",
                "Elevated trading volume confirming price action",
                f"Holding period: {latest_sig.holding_period_hours} hours",
            ]
        if "risk_factors" not in thesis:
            thesis["risk_factors"] = [
                f"Stop-loss level: ₹{latest_sig.stop_loss}" if latest_sig.stop_loss else "Protective stop-loss advised",
                "Market volatility and sector-wide sentiment shifts",
                "Execution risk requiring manual trade confirmation",
            ]
        return thesis

    provider = get_market_data_provider()
    df = provider.get_historical_ohlcv(symbol=symbol.upper(), exchange=exchange.upper())
    if df.empty or len(df) < 10:
        raise HTTPException(status_code=404, detail=f"Insufficient history to generate thesis for {symbol}")

    strat = strategy_registry.get("GeminiPredictiveAI") or strategy_registry.get("MomentumBreakout") or strategy_registry.get_all()[0]
    sig = strat.evaluate(df=df, symbol=symbol.upper(), exchange=exchange.upper())
    return sig.ai_thesis
