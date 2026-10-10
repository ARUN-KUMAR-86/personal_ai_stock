"""Custom logging configuration with credential and secret redaction."""

import logging
import re
import sys
from typing import List


SENSITIVE_PATTERNS = [
    re.compile(r"(Bearer\s+)[A-Za-z0-9\-\._~\+\/]+=*", re.IGNORECASE),
    re.compile(r"((?:token|secret|password|api_key|auth_token|totp)\s*[:=]\s*['\"]?)([^'\";\s]+)(['\"]?)", re.IGNORECASE),
    re.compile(r"((?:Authorization:\s*Bearer\s+))([^\s]+)", re.IGNORECASE),
]


class RedactingFormatter(logging.Formatter):
    """Formatter that masks sensitive tokens and secrets from log records."""

    def format(self, record: logging.LogRecord) -> str:
        original = super().format(record)
        redacted = original
        for pattern in SENSITIVE_PATTERNS:
            redacted = pattern.sub(r"\1***REDACTED***\3" if r"\3" in pattern.pattern else r"\1***REDACTED***", redacted)
        return redacted


def setup_logging(level: int = logging.INFO) -> logging.Logger:
    """Configures root and application loggers with redacting formatter."""
    logger = logging.getLogger("stock_intel")
    logger.setLevel(level)

    # Avoid duplicate handlers
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(level)
        formatter = RedactingFormatter(
            fmt="[%(asctime)s] [%(levelname)s] [%(name)s:%(funcName)s:%(lineno)d] - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    # Configure uvicorn loggers as well
    for uvicorn_name in ("uvicorn", "uvicorn.access", "uvicorn.error"):
        u_logger = logging.getLogger(uvicorn_name)
        for h in u_logger.handlers:
            h.setFormatter(
                RedactingFormatter(
                    fmt="[%(asctime)s] [%(levelname)s] [%(name)s] - %(message)s",
                    datefmt="%Y-%m-%d %H:%M:%S",
                )
            )

    return logger


logger = setup_logging()
