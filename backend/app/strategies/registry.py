"""Strategy Registry."""

from typing import Dict, List, Optional
from app.strategies.base import BaseStrategy
from app.strategies.highest_gain_maximizer import HighestGainMaximizerStrategy
from app.strategies.momentum_breakout import MomentumBreakoutStrategy
from app.strategies.mean_reversion import MeanReversionStrategy
from app.strategies.macd_crossover import MacdCrossStrategy


class StrategyRegistry:
    """Manages available algorithmic strategies."""

    def __init__(self):
        self._strategies: Dict[str, BaseStrategy] = {}
        # Register Highest Gain Maximizer as primary default algorithm
        self.register(HighestGainMaximizerStrategy())
        self.register(MomentumBreakoutStrategy())
        self.register(MeanReversionStrategy())
        self.register(MacdCrossStrategy())

    def register(self, strategy: BaseStrategy) -> None:
        self._strategies[strategy.name.lower()] = strategy

    def get(self, name: str) -> Optional[BaseStrategy]:
        # Support aliases
        clean = name.lower().replace(" ", "").replace("_", "").replace("-", "")
        for key, strat in self._strategies.items():
            strat_clean = strat.name.lower().replace(" ", "").replace("_", "").replace("-", "")
            if clean in strat_clean or strat_clean in clean:
                return strat
        return self._strategies.get(name.lower())

    def get_all(self) -> List[BaseStrategy]:
        return list(self._strategies.values())

    def list_names(self) -> List[str]:
        return [s.name for s in self._strategies.values()]


strategy_registry = StrategyRegistry()
