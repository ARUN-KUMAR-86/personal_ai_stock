"""Abstract Base Class for Broker Adapters."""

from abc import ABC, abstractmethod
from typing import Dict, Any, List, Optional


class BaseBrokerAdapter(ABC):
    """Modular broker adapter interface."""

    def __init__(self, broker_name: str):
        self.broker_name = broker_name

    @abstractmethod
    def is_configured(self) -> bool:
        """Returns True if broker API credentials are supplied."""
        pass

    @abstractmethod
    def authenticate(self) -> bool:
        """Validates or generates daily session token."""
        pass

    @abstractmethod
    def get_funds(self) -> Dict[str, Any]:
        """
        Retrieves broker-reported margin and funds details.
        Returns:
          {
            "available_funds": float,
            "unsettled_funds": float,
            "withdrawable_funds": float,
            "currency": "INR",
            "last_synced_at": datetime
          }
        """
        pass

    @abstractmethod
    def get_positions(self) -> List[Dict[str, Any]]:
        """Retrieves currently open positions from broker account."""
        pass

    @abstractmethod
    def get_holdings(self) -> List[Dict[str, Any]]:
        """Retrieves demat holdings from broker account."""
        pass

    @abstractmethod
    def place_order(
        self,
        symbol: str,
        exchange: str,
        transaction_type: str,  # BUY, SELL
        quantity: int,
        order_type: str = "MARKET",
        price: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Places order on exchange through broker (disabled by default)."""
        pass
