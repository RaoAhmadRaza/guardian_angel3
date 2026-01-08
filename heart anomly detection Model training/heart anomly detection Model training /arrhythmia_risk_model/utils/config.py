"""
Configuration Loader

Loads and validates YAML configuration files.
"""

from pathlib import Path
from typing import Any, Dict

import yaml


def load_config(config_path: str | Path = None) -> Dict[str, Any]:
    """
    Load configuration from YAML file.
    
    Args:
        config_path: Path to config file. Defaults to config/config.yaml
        
    Returns:
        Configuration dictionary
    """
    if config_path is None:
        config_path = Path(__file__).parent.parent / "config" / "config.yaml"
    
    config_path = Path(config_path)
    
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(config_path, "r") as f:
        config = yaml.safe_load(f)
    
    return config


def load_feature_config(config_path: str | Path = None) -> Dict[str, Any]:
    """
    Load feature definitions from YAML file.
    
    Args:
        config_path: Path to features config. Defaults to config/features.yaml
        
    Returns:
        Feature configuration dictionary
    """
    if config_path is None:
        config_path = Path(__file__).parent.parent / "config" / "features.yaml"
    
    return load_config(config_path)
