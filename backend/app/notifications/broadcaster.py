"""Real-time Server-Sent Events (SSE) and In-Memory Broadcaster for AI Stock Notifications."""

import asyncio
from typing import Set, Dict, Any, Optional
from app.core.logging import logger


class AlertBroadcaster:
    """Manages active SSE client connections and broadcasts real-time notifications safely across threads."""

    def __init__(self):
        self._subscribers: Set[asyncio.Queue] = set()
        self._loop: Optional[asyncio.AbstractEventLoop] = None

    def set_loop(self, loop: asyncio.AbstractEventLoop):
        self._loop = loop

    def subscribe(self) -> asyncio.Queue:
        q = asyncio.Queue()
        self._subscribers.add(q)
        try:
            self._loop = asyncio.get_running_loop()
        except RuntimeError:
            pass
        logger.info(f"New SSE client connected. Total clients: {len(self._subscribers)}")
        return q

    def unsubscribe(self, q: asyncio.Queue):
        self._subscribers.discard(q)
        logger.info(f"SSE client disconnected. Total clients: {len(self._subscribers)}")

    def broadcast(self, alert_data: Dict[str, Any]):
        """Dispatches alert immediately to all active SSE queues across any thread."""
        dead_queues = []
        for q in list(self._subscribers):
            try:
                if self._loop and self._loop.is_running():
                    self._loop.call_soon_threadsafe(q.put_nowait, alert_data)
                else:
                    q.put_nowait(alert_data)
            except Exception as e:
                logger.warning(f"Error putting to SSE queue: {e}")
                dead_queues.append(q)
        for dq in dead_queues:
            self._subscribers.discard(dq)


broadcaster = AlertBroadcaster()
