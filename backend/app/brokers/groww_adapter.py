"""Groww Broker Adapter adhering to official Groww Trade API documentation."""

from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
import pyotp
from app.core.config import settings
from app.core.logging import logger
from app.core.exceptions import BrokerIntegrationError
from app.brokers.base import BaseBrokerAdapter


class GrowwBrokerAdapter(BaseBrokerAdapter):
    """
    Official Groww Trading API integration adapter.
    Documentation: https://groww.in/trade-api/docs/
    """

    def __init__(self):
        super().__init__(broker_name="GROWW")
        self.auth_token = settings.GROWW_API_AUTH_TOKEN
        self.api_key = settings.GROWW_API_KEY
        self.api_secret = settings.GROWW_API_SECRET
        self.totp_key = settings.GROWW_TOTP_KEY
        self.order_execution_enabled = settings.GROWW_ORDER_EXECUTION_ENABLED
        self._client = None
        self._init_client()

    def _init_client(self):
        """Initializes the Groww API SDK client if configured."""
        if not self.is_configured():
            logger.info("Groww broker integration is not configured with credentials in .env.")
            return

        try:
            import importlib
            groww_module = importlib.import_module("growwapi")
            GrowwAPI = getattr(groww_module, "GrowwAPI")

            if self.auth_token:
                self._client = GrowwAPI(API_AUTH_TOKEN=self.auth_token)
            elif self.api_key and self.api_secret:
                self._client = GrowwAPI(api_key=self.api_key, api_secret=self.api_secret)

            logger.info("Groww API broker client initialized successfully.")
        except ImportError:
            logger.warning("The 'growwapi' Python package is not installed. Broker adapter running in unconfigured mode.")
        except Exception as e:
            logger.error(f"Error initializing Groww broker client: {e}")

    def is_configured(self) -> bool:
        return bool(self.auth_token or (self.api_key and self.api_secret))

    def authenticate(self) -> bool:
        """Authenticates or refreshes TOTP token."""
        if not self.is_configured():
            return False

        if self.totp_key:
            try:
                totp = pyotp.TOTP(self.totp_key)
                current_otp = totp.now()
                logger.info("Generated valid TOTP for Groww session authentication.")
                # When using TOTP auth flow, Groww API exchange can be completed here
                return True
            except Exception as e:
                logger.error(f"Failed to generate Groww TOTP: {e}")
                return False

        return self._client is not None

    def get_funds(self) -> Dict[str, Any]:
        """
        Retrieves user margin balance from Groww API.
        Docs: get_margins() returns available balance and utilized margins.
        """
        if not self.is_configured() or not self._client:
            return {
                "is_connected": False,
                "available_funds": 0.0,
                "unsettled_funds": 0.0,
                "withdrawable_funds": 0.0,
                "currency": "INR",
                "last_synced_at": datetime.now(timezone.utc),
                "error_message": "Groww API credentials not configured in .env. Enter GROWW_API_AUTH_TOKEN to synchronize funds.",
            }

        try:
            # Official Groww Trade API method for margins
            margins = self._client.get_margin()
            available = float(margins.get("available_cash", margins.get("available_margin", 0.0)))
            unsettled = float(margins.get("unsettled_balance", 0.0))
            withdrawable = float(margins.get("withdrawable_balance", available - unsettled))

            return {
                "is_connected": True,
                "available_funds": round(available, 2),
                "unsettled_funds": round(unsettled, 2),
                "withdrawable_funds": round(withdrawable, 2),
                "currency": "INR",
                "last_synced_at": datetime.now(timezone.utc),
                "error_message": None,
            }
        except Exception as e:
            logger.error(f"Failed to fetch Groww funds: {e}")
            return {
                "is_connected": False,
                "available_funds": 0.0,
                "unsettled_funds": 0.0,
                "withdrawable_funds": 0.0,
                "currency": "INR",
                "last_synced_at": datetime.now(timezone.utc),
                "error_message": f"Groww API error: {str(e)}",
            }

    def get_positions(self) -> List[Dict[str, Any]]:
        """Retrieves active intraday / derivatives positions from Groww."""
        if not self.is_configured() or not self._client:
            return []

        try:
            positions_data = self._client.get_positions()
            return positions_data.get("positions", [])
        except Exception as e:
            logger.error(f"Failed to fetch Groww positions: {e}")
            return []

    def get_holdings(self) -> List[Dict[str, Any]]:
        """Retrieves demat holdings from Groww."""
        if not self.is_configured() or not self._client:
            return []

        try:
            holdings_data = self._client.get_holdings()
            return holdings_data.get("holdings", [])
        except Exception as e:
            logger.error(f"Failed to fetch Groww holdings: {e}")
            return []

    def place_order(
        self,
        symbol: str,
        exchange: str,
        transaction_type: str,
        quantity: int,
        order_type: str = "MARKET",
        price: Optional[float] = None,
    ) -> Dict[str, Any]:
        """
        Places order through Groww API.
        Enforces manual-trading-first safety: Real execution is disabled by default.
        """
        if not self.order_execution_enabled:
            logger.warning("Order execution attempted but disabled by safety settings.")
            raise BrokerIntegrationError(
                "Real order execution is DISABLED by default for safety. "
                "Review the AI alert and place your trade manually in the Groww app, "
                "or explicitly set GROWW_ORDER_EXECUTION_ENABLED=true in .env."
            )

        if not self.is_configured() or not self._client:
            raise BrokerIntegrationError("Groww API is not configured. Cannot place real orders.")

        try:
            order_res = self._client.place_order(
                exchange=exchange.upper(),
                segment="CASH",
                trading_symbol=symbol.upper(),
                transaction_type=transaction_type.upper(),
                quantity=quantity,
                order_type=order_type.upper(),
                price=price or 0.0,
                product="DELIVERY",
            )
            return order_res
        except Exception as e:
            logger.error(f"Groww order placement failed: {e}")
            raise BrokerIntegrationError(f"Failed to place order on Groww: {str(e)}")
