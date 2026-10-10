"""Base strategy class."""

from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Dict, Any, Optional
import pandas as pd
from app.models.signal import StockSignal


class BaseStrategy(ABC):
    """Abstract base class for rule-based transparent trading strategies."""

    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description

    @abstractmethod
    def evaluate(
        self,
        df: pd.DataFrame,
        symbol: str,
        exchange: str = "NSE",
        is_live: bool = False,
        is_delayed: bool = False,
    ) -> StockSignal:
        """
        Evaluates the enriched OHLCV DataFrame and produces a StockSignal model.
        Must determine:
        - signal_type: BUY WATCH, HOLD, SELL/EXIT WATCH, NO TRADE
        - stop_loss, target, risk_reward
        - strength (0-100 score based on rule confluence)
        - entry_condition
        - invalidation_condition
        - explanation
        """
        pass
