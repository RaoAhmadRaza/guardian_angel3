"""
Non-Linear HRV Features

Computes complexity/entropy metrics from RR intervals.

Features computed (for Phase 1):
1. sample_entropy: Measures signal complexity/irregularity

Sample Entropy is particularly useful for:
- AF detection (high entropy = irregular rhythm)
- Distinguishing pathological from healthy variability
- Scale-independent complexity measure

NOTE: SD1/SD2 (Poincaré) deferred to Phase 2 - sample entropy
      provides sufficient nonlinear information for initial model.
"""

from dataclasses import dataclass
from typing import Dict, Optional
import numpy as np


@dataclass
class NonlinearFeatures:
    """
    Container for non-linear HRV features.
    
    Phase 1: Sample entropy only
    Phase 2: Will add Poincaré (SD1, SD2)
    """
    sample_entropy: float   # Sample entropy (dimensionless, typically 0-2)
    
    # Metadata
    num_intervals: int
    is_valid: bool
    
    def to_dict(self) -> Dict[str, float]:
        """Convert to dictionary for model input."""
        return {
            "sample_entropy": self.sample_entropy,
        }
    
    def to_array(self) -> np.ndarray:
        """Convert to numpy array for model input."""
        return np.array([
            self.sample_entropy,
        ])


class NonlinearExtractor:
    """
    Extracts non-linear HRV features.
    
    Sample Entropy (SampEn) measures the complexity of a time series.
    - Low SampEn: Regular, predictable rhythm
    - High SampEn: Irregular, complex rhythm (e.g., AF)
    
    Parameters:
    - m: Embedding dimension (pattern length)
    - r: Tolerance (typically 0.1-0.25 * std of signal)
    """
    
    FEATURE_NAMES = ["sample_entropy"]
    
    def __init__(
        self,
        m: int = 2,              # Embedding dimension
        r_factor: float = 0.2,   # Tolerance as fraction of std
        min_intervals: int = 30, # Minimum for reliable entropy
    ):
        """
        Initialize nonlinear extractor.
        
        Args:
            m: Embedding dimension (default 2, standard for HRV)
            r_factor: Tolerance factor (r = r_factor * std(signal))
            min_intervals: Minimum RR intervals required
        """
        self.m = m
        self.r_factor = r_factor
        self.min_intervals = min_intervals
    
    def extract(self, rr_ms: np.ndarray) -> NonlinearFeatures:
        """
        Extract non-linear features from RR intervals.
        
        Args:
            rr_ms: Array of RR intervals in milliseconds
            
        Returns:
            NonlinearFeatures dataclass
        """
        n = len(rr_ms)
        
        # Check minimum data requirement
        if n < self.min_intervals:
            return self._create_invalid_features(n, f"Too few intervals: {n}")
        
        try:
            # Calculate sample entropy
            sampen = self._sample_entropy(rr_ms, self.m, self.r_factor)
            
            features = NonlinearFeatures(
                sample_entropy=sampen,
                num_intervals=n,
                is_valid=True
            )
            
            # Validate
            if not self._validate_features(features):
                features.is_valid = False
            
            return features
            
        except Exception as e:
            return self._create_invalid_features(n, str(e))
    
    def _sample_entropy(
        self, 
        signal: np.ndarray, 
        m: int, 
        r_factor: float
    ) -> float:
        """
        Calculate Sample Entropy.
        
        SampEn(m, r, N) = -ln(A/B)
        where:
        - B = number of template matches of length m
        - A = number of template matches of length m+1
        
        Args:
            signal: Input time series
            m: Embedding dimension
            r_factor: Tolerance as fraction of signal std
            
        Returns:
            Sample entropy value
        """
        N = len(signal)
        r = r_factor * np.std(signal, ddof=1)
        
        if r == 0:
            # Zero variance signal - undefined entropy
            return 0.0
        
        # Count template matches for m and m+1
        B = self._count_matches(signal, m, r)
        A = self._count_matches(signal, m + 1, r)
        
        # Calculate entropy
        if A == 0 or B == 0:
            # Avoid log(0) - return maximum entropy estimate
            return np.nan
        
        return -np.log(A / B)
    
    def _count_matches(
        self, 
        signal: np.ndarray, 
        m: int, 
        r: float
    ) -> int:
        """
        Count the number of template matches of length m.
        
        Two templates match if their Chebyshev distance is <= r.
        """
        N = len(signal)
        count = 0
        
        # Create templates of length m
        templates = np.array([signal[i:i+m] for i in range(N - m)])
        
        # Count matches (excluding self-matches)
        for i in range(len(templates)):
            for j in range(i + 1, len(templates)):
                # Chebyshev distance (max absolute difference)
                dist = np.max(np.abs(templates[i] - templates[j]))
                if dist <= r:
                    count += 1
        
        return count
    
    def _validate_features(self, features: NonlinearFeatures) -> bool:
        """Check if features are valid."""
        # Sample entropy should be finite and reasonable
        if not np.isfinite(features.sample_entropy):
            return False
        
        # Typical range is 0-3 for HRV
        if features.sample_entropy < 0:
            return False
        
        return True
    
    def _create_invalid_features(
        self, 
        n: int, 
        reason: str
    ) -> NonlinearFeatures:
        """Create invalid feature set with NaN values."""
        return NonlinearFeatures(
            sample_entropy=np.nan,
            num_intervals=n,
            is_valid=False
        )
    
    @staticmethod
    def get_feature_descriptions() -> Dict[str, str]:
        """Get human-readable descriptions of each feature."""
        return {
            "sample_entropy": "Sample entropy - measures rhythm complexity/irregularity (high in AF)",
        }
