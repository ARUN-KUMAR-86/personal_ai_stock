"""Broker Adapter Factory."""

from functools import lru_cache
from app.brokers.base import BaseBrokerAdapter
from app.brokers.groww_adapter import GrowwBrokerAdapter


@lru_cache()
def get_broker_adapter() -> BaseBrokerAdapter:
    """Returns singleton instance of configured broker adapter."""
    return GrowwBrokerAdapter()
