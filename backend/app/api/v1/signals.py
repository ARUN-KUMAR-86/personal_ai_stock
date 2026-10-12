"""Stock signal and analysis endpoints."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.signal import StockSignal
from app.schemas.signal import SignalRead

router = APIRouter(prefix="/signals", tags=["Signals & Analysis"])


@router.get("/latest", response_model=List[SignalRead])
def get_latest_signals(
    signal_type: Optional[str] = None,
    exchange: str = "NSE",
    limit: int = 20,
    db: Session = Depends(get_db),
):
    """Retrieves the latest generated signals."""
    query = db.query(StockSignal).filter(StockSignal.exchange == exchange)
    if signal_type:
        query = query.filter(StockSignal.signal_type == signal_type)
    return query.order_by(StockSignal.created_at.desc()).limit(limit).all()


@router.get("/{symbol}", response_model=List[SignalRead])
def get_signals_for_symbol(
    symbol: str,
    exchange: str = "NSE",
    limit: int = 10,
    db: Session = Depends(get_db),
):
    """Retrieves historical signals and analysis rationale for a given symbol."""
    signals = (
        db.query(StockSignal)
        .filter(StockSignal.symbol == symbol.upper(), StockSignal.exchange == exchange.upper())
        .order_by(StockSignal.created_at.desc())
        .limit(limit)
        .all()
    )
    if not signals:
        # If no signal stored yet, generate an on-demand evaluation
        from app.providers.factory import get_market_data_provider
        from app.strategies.registry import strategy_registry
        provider = get_market_data_provider()
        df = provider.get_historical_ohlcv(symbol=symbol.upper(), exchange=exchange.upper())
        if not df.empty and len(df) >= 20:
            strat = strategy_registry.get("MomentumBreakout") or strategy_registry.get_all()[0]
            sig = strat.evaluate(df=df, symbol=symbol.upper(), exchange=exchange.upper())
            db.add(sig)
            db.commit()
            db.refresh(sig)
            return [sig]
        raise HTTPException(status_code=404, detail=f"No signals found for {symbol}")
    return signals


@router.get("/recommendation/{symbol}", response_model=SignalRead)
def get_stock_recommendation(
    symbol: str,
    exchange: str = "NSE",
    db: Session = Depends(get_db),
):
    """
    Returns the latest complete AI recommendation analysis for a symbol,
    including entry levels, SL/TP, holding period, liquidity, news, risks, and scoring.
    """
    sig = (
        db.query(StockSignal)
        .filter(StockSignal.symbol == symbol.upper(), StockSignal.exchange == exchange.upper())
        .order_by(StockSignal.created_at.desc())
        .first()
    )

    if not sig:
        from app.providers.factory import get_market_data_provider
        from app.strategies.registry import strategy_registry
        provider = get_market_data_provider()
        df = provider.get_historical_ohlcv(symbol=symbol.upper(), exchange=exchange.upper())
        if df.empty or len(df) < 20:
            raise HTTPException(status_code=404, detail=f"Insufficient data to generate recommendation for {symbol}")
        strat = strategy_registry.get("MomentumBreakout") or strategy_registry.get_all()[0]
        sig = strat.evaluate(df=df, symbol=symbol.upper(), exchange=exchange.upper())
        db.add(sig)
        db.commit()
        db.refresh(sig)
    elif sig.ai_thesis is None:
        from app.analysis.narrative import ai_narrative_generator
        thesis_data = ai_narrative_generator.generate_thesis(
            symbol=sig.symbol,
            company_name=sig.company_name or sig.symbol,
            exchange=sig.exchange,
            signal_type=sig.signal_type,
            strategy_name=sig.strategy_name,
            price=sig.price,
            stop_loss=sig.stop_loss,
            target=sig.target,
            risk_reward=sig.risk_reward,
            metrics=sig.indicator_summary or {},
            financial_news=sig.financial_news or [],
        )
        sig.ai_thesis = thesis_data
        sig.explanation = thesis_data.get("investment_thesis") or sig.explanation
        if thesis_data.get("risk_factors"):
            sig.risk_factors = thesis_data["risk_factors"]
        if thesis_data.get("invalidation_trigger"):
            sig.invalidation_condition = thesis_data["invalidation_trigger"]
        db.commit()
        db.refresh(sig)

    return sig


@router.post("/{signal_id}/thesis/regenerate", response_model=SignalRead)
def regenerate_signal_thesis(
    signal_id: int,
    db: Session = Depends(get_db),
):
    """Regenerates the AI investment thesis for an existing signal using Gemini or quantitative confluence engine."""
    sig = db.query(StockSignal).filter(StockSignal.id == signal_id).first()
    if not sig:
        raise HTTPException(status_code=404, detail=f"Signal with ID {signal_id} not found")

    from app.analysis.narrative import ai_narrative_generator
    thesis_data = ai_narrative_generator.generate_thesis(
        symbol=sig.symbol,
        company_name=sig.company_name or sig.symbol,
        exchange=sig.exchange,
        signal_type=sig.signal_type,
        strategy_name=sig.strategy_name,
        price=sig.price,
        stop_loss=sig.stop_loss,
        target=sig.target,
        risk_reward=sig.risk_reward,
        metrics=sig.indicator_summary or {},
        financial_news=sig.financial_news or [],
    )
    sig.ai_thesis = thesis_data
    sig.explanation = thesis_data.get("investment_thesis") or sig.explanation
    if thesis_data.get("risk_factors"):
        sig.risk_factors = thesis_data["risk_factors"]
    if thesis_data.get("invalidation_trigger"):
        sig.invalidation_condition = thesis_data["invalidation_trigger"]
    db.commit()
    db.refresh(sig)
    return sig
