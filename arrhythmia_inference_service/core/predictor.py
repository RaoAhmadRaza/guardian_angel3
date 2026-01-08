"""
Arrhythmia Risk Predictor

Wrapper around the trained XGBoost model.
Loads the unchanged model file and performs inference.
"""

import hashlib
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

import numpy as np
import xgboost as xgb

from config import settings
from core.feature_extractor import HRVFeatures


logger = logging.getLogger(__name__)


class ModelLoadError(Exception):
    """Raised when model cannot be loaded."""
    pass


class InferenceError(Exception):
    """Raised when inference fails."""
    pass


class ArrhythmiaPredictor:
    """
    XGBoost-based arrhythmia risk predictor.
    
    Loads the trained model unchanged and performs inference.
    Returns probability of elevated arrhythmia risk.
    """
    
    def __init__(
        self,
        model_path: Optional[Path] = None,
        meta_path: Optional[Path] = None
    ):
        """
        Initialize predictor.
        
        Args:
            model_path: Path to XGBoost model JSON file
            meta_path: Path to model metadata JSON file
        """
        self.model_path = model_path or settings.model_file
        self.meta_path = meta_path or settings.meta_file
        
        self._model: Optional[xgb.Booster] = None
        self._meta: dict = {}
        self._model_hash: str = ""
        self._loaded_at: Optional[datetime] = None
        self._feature_names: list[str] = []
    
    @property
    def is_loaded(self) -> bool:
        """Check if model is loaded."""
        return self._model is not None
    
    @property
    def model_version(self) -> str:
        """Get model version from metadata."""
        return self._meta.get("model_version", "1.0.0")
    
    @property
    def model_hash(self) -> str:
        """Get SHA256 hash of model file."""
        return self._model_hash
    
    @property
    def feature_count(self) -> int:
        """Get number of features expected by model."""
        return len(self._feature_names)
    
    @property
    def trained_at(self) -> str:
        """Get model training timestamp."""
        return self._meta.get("saved_at", "unknown")
    
    def load(self) -> None:
        """
        Load model and metadata from disk.
        
        Raises:
            ModelLoadError: If model files cannot be loaded
        """
        # Check files exist
        if not self.model_path.exists():
            raise ModelLoadError(f"Model file not found: {self.model_path}")
        
        if not self.meta_path.exists():
            raise ModelLoadError(f"Metadata file not found: {self.meta_path}")
        
        try:
            # Load metadata first
            with open(self.meta_path, 'r') as f:
                self._meta = json.load(f)
            
            self._feature_names = self._meta.get("feature_names", [])
            
            if not self._feature_names:
                raise ModelLoadError("No feature names in metadata")
            
            logger.info(f"Loaded metadata: {len(self._feature_names)} features")
            
            # Compute model hash for audit trail
            with open(self.model_path, 'rb') as f:
                model_bytes = f.read()
                self._model_hash = hashlib.sha256(model_bytes).hexdigest()[:16]
            
            # Load XGBoost model
            self._model = xgb.Booster()
            self._model.load_model(str(self.model_path))
            
            self._loaded_at = datetime.utcnow()
            
            logger.info(
                f"Model loaded successfully. "
                f"Version: {self.model_version}, "
                f"Hash: {self._model_hash}, "
                f"Features: {self.feature_count}"
            )
            
        except json.JSONDecodeError as e:
            raise ModelLoadError(f"Invalid metadata JSON: {e}")
        except xgb.core.XGBoostError as e:
            raise ModelLoadError(f"Failed to load XGBoost model: {e}")
        except Exception as e:
            raise ModelLoadError(f"Unexpected error loading model: {e}")
    
    def predict(self, features: HRVFeatures) -> float:
        """
        Predict arrhythmia risk probability.
        
        Args:
            features: Extracted HRV features
            
        Returns:
            Risk probability (0.0 to 1.0)
            
        Raises:
            InferenceError: If prediction fails
        """
        if not self.is_loaded:
            raise InferenceError("Model not loaded. Call load() first.")
        
        if not features.is_valid:
            raise InferenceError(
                f"Invalid features. Invalid domains: {features.invalid_domains}"
            )
        
        try:
            # Convert features to array in correct order
            feature_array = features.to_array()
            
            # Validate feature count
            if len(feature_array) != self.feature_count:
                raise InferenceError(
                    f"Feature count mismatch. "
                    f"Expected {self.feature_count}, got {len(feature_array)}"
                )
            
            # Check for NaN/Inf
            if not np.all(np.isfinite(feature_array)):
                nan_indices = np.where(~np.isfinite(feature_array))[0]
                nan_features = [self._feature_names[i] for i in nan_indices]
                raise InferenceError(f"Invalid values in features: {nan_features}")
            
            # Create DMatrix for XGBoost
            dmatrix = xgb.DMatrix(
                feature_array.reshape(1, -1),
                feature_names=self._feature_names
            )
            
            # Predict
            prediction = self._model.predict(dmatrix)
            
            # XGBoost returns array, get first element
            probability = float(prediction[0])
            
            # Clamp to [0, 1] range
            probability = max(0.0, min(1.0, probability))
            
            logger.debug(f"Prediction: {probability:.4f}")
            
            return probability
            
        except xgb.core.XGBoostError as e:
            raise InferenceError(f"XGBoost prediction error: {e}")
        except Exception as e:
            raise InferenceError(f"Unexpected prediction error: {e}")
    
    def get_model_info(self) -> dict:
        """Get model information for API response."""
        return {
            "model_version": self.model_version,
            "model_hash": f"sha256:{self._model_hash}",
            "feature_count": self.feature_count,
            "trained_at": self.trained_at,
        }


# =============================================================================
# SINGLETON INSTANCE
# =============================================================================

# Global predictor instance (loaded once at startup)
_predictor: Optional[ArrhythmiaPredictor] = None


def get_predictor() -> ArrhythmiaPredictor:
    """Get the global predictor instance."""
    global _predictor
    if _predictor is None:
        _predictor = ArrhythmiaPredictor()
    return _predictor


def load_predictor() -> ArrhythmiaPredictor:
    """Load and return the global predictor."""
    predictor = get_predictor()
    if not predictor.is_loaded:
        predictor.load()
    return predictor
