"""
Logging Configuration

Sets up structured logging for the application.
"""

import logging
import sys
import re
from typing import Optional, Dict, Any

try:
    from pythonjsonlogger import jsonlogger
    HAS_JSON_LOGGER = True
except ImportError:
    HAS_JSON_LOGGER = False
    
from ordo_backend.config import settings


class SensitiveDataFilter(logging.Filter):
    """Filter to redact sensitive information from logs."""
    
    PATTERNS = [
        (r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[EMAIL]'),
        (r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b', '[CARD]'),
        (r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [TOKEN]'),
        (r'api[_-]?key["\']?\s*[:=]\s*["\']?[A-Za-z0-9]+', 'api_key=[REDACTED]'),
    ]
    
    def filter(self, record: logging.LogRecord) -> bool:
        """Redact sensitive data from log messages."""
        if isinstance(record.msg, str):
            for pattern, replacement in self.PATTERNS:
                record.msg = re.sub(pattern, replacement, record.msg, flags=re.IGNORECASE)
        return True


_logging_configured = False


def setup_logging():
    """
    Configure application logging.
    
    Sets up structured JSON logging for production or
    human-readable logging for development.
    """
    global _logging_configured
    
    # Prevent duplicate configuration
    if _logging_configured:
        return
    
    # Get root logger
    logger = logging.getLogger()
    
    # Validate and set log level
    try:
        log_level = getattr(logging, settings.LOG_LEVEL.upper())
    except AttributeError:
        log_level = logging.INFO
        print(f"Warning: Invalid LOG_LEVEL '{settings.LOG_LEVEL}', defaulting to INFO", file=sys.stderr)
    
    logger.setLevel(log_level)
    
    # Remove existing handlers
    logger.handlers = []
    
    # Create console handler
    handler = logging.StreamHandler(sys.stdout)
    
    # Configure formatter based on LOG_FORMAT
    if settings.LOG_FORMAT == "json" and HAS_JSON_LOGGER:
        # JSON formatter for production
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(name)s %(levelname)s %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%S"
        )
    else:
        # Human-readable formatter for development
        if settings.LOG_FORMAT == "json" and not HAS_JSON_LOGGER:
            print("Warning: python-json-logger not installed, using text format", file=sys.stderr)
        formatter = logging.Formatter(
            fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
    
    handler.setFormatter(formatter)
    
    # Add sensitive data filter
    handler.addFilter(SensitiveDataFilter())
    
    logger.addHandler(handler)
    
    # Set log levels for third-party libraries
    logging.getLogger("uvicorn").setLevel(logging.INFO)
    logging.getLogger("fastapi").setLevel(logging.INFO)
    logging.getLogger("sqlalchemy").setLevel(logging.WARNING)
    
    _logging_configured = True
    logger.info(f"Logging configured: level={settings.LOG_LEVEL}, format={settings.LOG_FORMAT}")


def get_logger(name: str, extra: Optional[Dict[str, Any]] = None) -> logging.LoggerAdapter:
    """
    Get a logger instance for a module with optional context.
    
    Args:
        name: Module name (typically __name__)
        extra: Additional context to include in all log messages
        
    Returns:
        LoggerAdapter instance with context, or plain Logger if no extra context
        
    Example:
        logger = get_logger(__name__, {"user_id": "123", "request_id": "abc"})
        logger.info("Processing request")  # Will include user_id and request_id
    """
    logger = logging.getLogger(name)
    if extra:
        return logging.LoggerAdapter(logger, extra)
    return logger
