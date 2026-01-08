"""
Arrhythmia Inference Service Configuration

Environment variables override defaults (prefix: ARRHYTHMIA_)
"""

from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Service configuration with sensible defaults."""
    
    # Server
    host: str = "127.0.0.1"
    port: int = 8000
    debug: bool = False
    
    # Model paths (relative to service root)
    model_path: str = "models/xgboost_arrhythmia_risk.json"
    meta_path: str = "models/xgboost_arrhythmia_risk_meta.json"
    
    # Input validation
    min_rr_count: int = 40
    max_rr_count: int = 200
    min_rr_value_ms: int = 200
    max_rr_value_ms: int = 2000
    min_window_duration_s: int = 30
    max_window_duration_s: int = 120
    
    # Feature extraction
    interpolation_fs: float = 4.0  # Hz for frequency domain
    lf_band: tuple[float, float] = (0.04, 0.15)
    hf_band: tuple[float, float] = (0.15, 0.40)
    
    # Risk thresholds
    risk_threshold_low: float = 0.30
    risk_threshold_moderate: float = 0.50
    risk_threshold_elevated: float = 0.70
    
    # Logging
    log_level: str = "INFO"
    
    class Config:
        env_prefix = "ARRHYTHMIA_"
        env_file = ".env"
        env_file_encoding = "utf-8"
    
    @property
    def model_file(self) -> Path:
        """Absolute path to model file."""
        return Path(__file__).parent / self.model_path
    
    @property
    def meta_file(self) -> Path:
        """Absolute path to metadata file."""
        return Path(__file__).parent / self.meta_path


# Global settings instance
settings = Settings()
