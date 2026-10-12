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
        user_confirmed: bool = False,
    ) -> Dict[str, Any]:
        """Places order on exchange through broker (disabled by default)."""
        pass

    def get_order_status(self, order_id: str) -> Dict[str, Any]:
        """Retrieves verified status of placed broker order."""
        return {"order_id": order_id, "status": "UNKNOWN", "filled_quantity": 0}

    def get_api_availability(self) -> Dict[str, Any]:
        """Checks API availability, permissions, and session health."""
        return {
            "broker": self.broker_name,
            "is_configured": self.is_configured(),
            "is_authenticated": False,
        }
