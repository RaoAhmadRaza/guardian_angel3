"""
Logging Setup

Configures structured logging using loguru.
"""

import sys
from pathlib import Path

from loguru import logger


def setup_logger(
    log_level: str = "INFO",
    log_file: str | Path = None,
    rotation: str = "10 MB",
    retention: str = "30 days"
) -> None:
    """
    Configure loguru logger for the project.
    
    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR)
        log_file: Optional path to log file
        rotation: Log rotation setting
        retention: Log retention period
    """
    # Remove default handler
    logger.remove()
    
    # Console handler with formatting
    logger.add(
        sys.stderr,
        level=log_level,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
        colorize=True
    )
    
    # File handler if specified
    if log_file:
        log_file = Path(log_file)
        log_file.parent.mkdir(parents=True, exist_ok=True)
        
        logger.add(
            log_file,
            level=log_level,
            format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
            rotation=rotation,
            retention=retention,
            compression="zip"
        )
    
    logger.info(f"Logger initialized with level: {log_level}")


def get_logger(name: str = None):
    """
    Get a logger instance.
    
    Args:
        name: Optional logger name
        
    Returns:
        Logger instance
    """
    if name:
        return logger.bind(name=name)
    return logger
