"""Backtesting and strategy simulation endpoints."""

from typing import List
from fastapi import APIRouter, HTTPException

from app.schemas.backtest import BacktestRequest, BacktestResult
from app.backtesting.engine import BacktestEngine
from app.strategies.registry import strategy_registry

router = APIRouter(prefix="/backtest", tags=["Backtesting & Simulation"])


@router.get("/strategies")
def get_available_strategies():
    """Lists registered algorithmic strategies available for scanning and backtesting."""
    return [
        {"name": s.name, "description": s.description}
        for s in strategy_registry.get_all()
    ]


@router.post("/run", response_model=BacktestResult)
def run_backtest(request: BacktestRequest):
    """Executes historical backtest without lookahead bias and returns performance metrics."""
    try:
        return BacktestEngine.run(request)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
