#!/usr/bin/env python3
"""Convenience runner for Zed AI Stock Live Terminal Monitor."""

import sys
import os

# Add backend directory to sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.terminal import run_terminal_loop

if __name__ == "__main__":
    interval = 3.0
    once = "--once" in sys.argv
    for arg in sys.argv:
        if arg.startswith("--interval="):
            try:
                interval = float(arg.split("=")[1])
            except ValueError:
                pass
    run_terminal_loop(refresh_seconds=interval, once=once)
