"""
Time-Domain HRV Features

Computes standard time-domain HRV metrics from RR intervals.
These are the core features that can detect:
- Atrial fibrillation (high RMSSD, high pNN50)
- Frequent PVCs (irregular rhythm patterns)
- Autonomic dysfunction (abnormal SDNN)

Features computed:
1. mean_rr:  Average RR interval → overall heart rate
2. sdnn:     Standard deviation of RR → global variability
3. rmssd:    Root mean square of successive differences → parasympathetic activity
4. pnn50:    % of RR differences > 50ms → rhythm irregularity
5. pnn20:    % of RR differences > 20ms → finer irregularity
6. mean_hr:  Mean heart rate (BPM) → cardiac output
7. std_hr:   Standard deviation of HR → rate stability
8. cv_rr:    Coefficient of variation → normalized variability
"""

from dataclasses import dataclass
from typing import Dict, Optional
import numpy as np

import sys
sys.path.insert(0, str(__file__).replace('/src/features/time_domain.py', ''))
from src.data.preprocessing import RRWindow


@dataclass
class TimeDomainFeatures:
    """
    Container for time-domain HRV features from a single window.
    
    All features are computed from RR intervals in milliseconds.
    """
    # Basic statistics
    mean_rr: float      # Mean RR interval (ms)
    sdnn: float         # Standard deviation of NN intervals (ms)
    
    # Successive difference features
    rmssd: float        # Root mean square of successive differences (ms)
    pnn50: float        # % of successive differences > 50ms (0-100)
    pnn20: float        # % of successive differences > 20ms (0-100)
    
    # Heart rate features
    mean_hr: float      # Mean heart rate (BPM)
    std_hr: float       # Standard deviation of heart rate (BPM)
    
    # Normalized variability
    cv_rr: float        # Coefficient of variation (SDNN/mean_rr * 100)
    
    # Metadata
    num_intervals: int  # Number of RR intervals used
    is_valid: bool      # Whether features are physiologically valid
    
    def to_dict(self) -> Dict[str, float]:
        """Convert to dictionary for model input."""
        return {
            "mean_rr": self.mean_rr,
            "sdnn": self.sdnn,
            "rmssd": self.rmssd,
            "pnn50": self.pnn50,
            "pnn20": self.pnn20,
            "mean_hr": self.mean_hr,
            "std_hr": self.std_hr,
            "cv_rr": self.cv_rr,
        }
    
    def to_array(self) -> np.ndarray:
        """Convert to numpy array for model input."""
        return np.array([
            self.mean_rr,
            self.sdnn,
            self.rmssd,
            self.pnn50,
            self.pnn20,
            self.mean_hr,
            self.std_hr,
            self.cv_rr,
        ])


class TimeDomainExtractor:
    """
    Extracts time-domain HRV features from RR intervals.
    
    All computations follow standard HRV guidelines.
    No filtering or interpolation - features reflect actual rhythm.
    """
    
    # Feature names in order (matches to_array output)
    FEATURE_NAMES = [
        "mean_rr", "sdnn", "rmssd", "pnn50", 
        "pnn20", "mean_hr", "std_hr", "cv_rr"
    ]
    
    def __init__(self, min_intervals: int = 10):
        """
        Initialize extractor.
        
        Args:
            min_intervals: Minimum RR intervals required for valid features
        """
        self.min_intervals = min_intervals
    
    def extract(self, rr_ms: np.ndarray) -> TimeDomainFeatures:
        """
        Extract time-domain features from RR intervals.
        
        Args:
            rr_ms: Array of RR intervals in milliseconds
            
        Returns:
            TimeDomainFeatures dataclass with all computed features
        """
        n = len(rr_ms)
        
        # Check minimum data requirement
        if n < self.min_intervals:
            return self._create_invalid_features(n, f"Too few intervals: {n}")
        
        # Compute features
        try:
            features = TimeDomainFeatures(
                mean_rr=self._compute_mean_rr(rr_ms),
                sdnn=self._compute_sdnn(rr_ms),
                rmssd=self._compute_rmssd(rr_ms),
                pnn50=self._compute_pnnX(rr_ms, threshold_ms=50),
                pnn20=self._compute_pnnX(rr_ms, threshold_ms=20),
                mean_hr=self._compute_mean_hr(rr_ms),
                std_hr=self._compute_std_hr(rr_ms),
                cv_rr=self._compute_cv_rr(rr_ms),
                num_intervals=n,
                is_valid=True
            )
            
            # Validate physiological plausibility
            if not self._validate_features(features):
                features.is_valid = False
            
            return features
            
        except Exception as e:
            return self._create_invalid_features(n, str(e))
    
    def extract_from_window(self, window: RRWindow) -> TimeDomainFeatures:
        """
        Extract features from a preprocessed RRWindow.
        
        Args:
            window: Preprocessed RRWindow object
            
        Returns:
            TimeDomainFeatures for this window
        """
        return self.extract(window.rr_intervals_ms)
    
    # =========================================================================
    # Feature computation methods
    # =========================================================================
    
    def _compute_mean_rr(self, rr_ms: np.ndarray) -> float:
        """Mean RR interval in milliseconds."""
        return float(np.mean(rr_ms))
    
    def _compute_sdnn(self, rr_ms: np.ndarray) -> float:
        """
        Standard Deviation of NN intervals.
        
        SDNN reflects overall HRV and is influenced by both
        sympathetic and parasympathetic activity.
        
        Normal range: 50-100 ms (short-term)
        Low SDNN: reduced autonomic modulation
        High SDNN: healthy autonomic balance
        """
        return float(np.std(rr_ms, ddof=1))  # Sample std (ddof=1)
    
    def _compute_rmssd(self, rr_ms: np.ndarray) -> float:
        """
        Root Mean Square of Successive Differences.
        
        RMSSD primarily reflects parasympathetic (vagal) activity.
        Very sensitive to beat-to-beat variability.
        
        Normal range: 20-50 ms
        High RMSSD: Can indicate AF (chaotic rhythm)
        Low RMSSD: Reduced vagal tone
        """
        # Successive differences
        diff = np.diff(rr_ms)
        
        # Root mean square
        return float(np.sqrt(np.mean(diff ** 2)))
    
    def _compute_pnnX(self, rr_ms: np.ndarray, threshold_ms: float) -> float:
        """
        Percentage of successive RR differences exceeding threshold.
        
        pNN50: % > 50ms (standard metric)
        pNN20: % > 20ms (more sensitive)
        
        High values indicate irregular rhythm (AF, frequent ectopy)
        Normal pNN50: 5-25%
        """
        diff = np.abs(np.diff(rr_ms))
        
        if len(diff) == 0:
            return 0.0
        
        n_above = np.sum(diff > threshold_ms)
        return float(n_above / len(diff) * 100)
    
    def _compute_mean_hr(self, rr_ms: np.ndarray) -> float:
        """
        Mean heart rate in beats per minute.
        
        HR (BPM) = 60000 / RR (ms)
        """
        # Compute HR for each interval, then average
        hr_bpm = 60000.0 / rr_ms
        return float(np.mean(hr_bpm))
    
    def _compute_std_hr(self, rr_ms: np.ndarray) -> float:
        """
        Standard deviation of heart rate.
        
        Reflects beat-to-beat rate variability.
        High values indicate unstable rate.
        """
        hr_bpm = 60000.0 / rr_ms
        return float(np.std(hr_bpm, ddof=1))
    
    def _compute_cv_rr(self, rr_ms: np.ndarray) -> float:
        """
        Coefficient of Variation of RR intervals.
        
        CV = (SDNN / mean_RR) * 100
        
        Normalized measure of variability.
        Allows comparison across different heart rates.
        """
        mean_rr = np.mean(rr_ms)
        if mean_rr == 0:
            return 0.0
        
        sdnn = np.std(rr_ms, ddof=1)
        return float(sdnn / mean_rr * 100)
    
    # =========================================================================
    # Validation
    # =========================================================================
    
    def _validate_features(self, features: TimeDomainFeatures) -> bool:
        """
        Check if features are physiologically plausible.
        
        Returns False if any feature is NaN, Inf, or clearly wrong.
        """
        values = features.to_array()
        
        # Check for NaN or Inf
        if np.any(~np.isfinite(values)):
            return False
        
        # Basic sanity checks
        if features.mean_rr <= 0 or features.mean_rr > 3000:
            return False
        
        if features.mean_hr <= 0 or features.mean_hr > 300:
            return False
        
        if features.sdnn < 0:
            return False
        
        if features.rmssd < 0:
            return False
        
        if features.pnn50 < 0 or features.pnn50 > 100:
            return False
        
        return True
    
    def _create_invalid_features(
        self, 
        n: int, 
        reason: str
    ) -> TimeDomainFeatures:
        """Create a feature set marked as invalid with NaN values."""
        return TimeDomainFeatures(
            mean_rr=np.nan,
            sdnn=np.nan,
            rmssd=np.nan,
            pnn50=np.nan,
            pnn20=np.nan,
            mean_hr=np.nan,
            std_hr=np.nan,
            cv_rr=np.nan,
            num_intervals=n,
            is_valid=False
        )
    
    @staticmethod
    def get_feature_descriptions() -> Dict[str, str]:
        """Get human-readable descriptions of each feature."""
        return {
            "mean_rr": "Mean RR interval (ms) - inverse of heart rate",
            "sdnn": "Standard deviation of RR (ms) - global variability",
            "rmssd": "Root mean square of successive differences (ms) - vagal activity",
            "pnn50": "% of RR differences > 50ms - rhythm irregularity",
            "pnn20": "% of RR differences > 20ms - fine irregularity",
            "mean_hr": "Mean heart rate (BPM)",
            "std_hr": "Standard deviation of heart rate (BPM) - rate stability",
            "cv_rr": "Coefficient of variation (%) - normalized variability"
        }
