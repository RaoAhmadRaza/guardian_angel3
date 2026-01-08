"""
Frequency-Domain HRV Features

Computes spectral HRV metrics using Welch's method.

Features computed (wearable-safe for 60s windows):
1. lf_power:    Low frequency power (0.04-0.15 Hz) - sympathetic + parasympathetic
2. hf_power:    High frequency power (0.15-0.4 Hz) - parasympathetic (respiratory)
3. lf_hf_ratio: LF/HF ratio - autonomic balance indicator

NOTE: VLF (0.003-0.04 Hz) is NOT included - unstable in 60s windows.
      Requires 5+ minute recordings for reliable estimation.

Clinical significance:
- LF power: Mixed sympathetic/parasympathetic, blood pressure regulation
- HF power: Vagal (parasympathetic) activity, respiratory sinus arrhythmia
- LF/HF ratio: Sympathovagal balance (controversial but widely used)
"""

from dataclasses import dataclass
from typing import Dict, Optional, Tuple
import numpy as np
from scipy import signal
from scipy import interpolate


@dataclass
class FrequencyDomainFeatures:
    """
    Container for frequency-domain HRV features.
    
    All power values are in ms^2 (absolute power).
    """
    lf_power: float       # Low frequency power (0.04-0.15 Hz) in ms^2
    hf_power: float       # High frequency power (0.15-0.4 Hz) in ms^2
    lf_hf_ratio: float    # LF/HF ratio (dimensionless)
    total_power: float    # Total power (LF + HF) in ms^2
    
    # Normalized units (% of LF+HF)
    lf_nu: float          # LF in normalized units (0-100)
    hf_nu: float          # HF in normalized units (0-100)
    
    # Metadata
    num_intervals: int
    is_valid: bool
    
    def to_dict(self) -> Dict[str, float]:
        """Convert to dictionary for model input."""
        return {
            "lf_power": self.lf_power,
            "hf_power": self.hf_power,
            "lf_hf_ratio": self.lf_hf_ratio,
            "total_power": self.total_power,
            "lf_nu": self.lf_nu,
            "hf_nu": self.hf_nu,
        }
    
    def to_array(self) -> np.ndarray:
        """Convert to numpy array for model input."""
        return np.array([
            self.lf_power,
            self.hf_power,
            self.lf_hf_ratio,
            self.total_power,
            self.lf_nu,
            self.hf_nu,
        ])


class FrequencyDomainExtractor:
    """
    Extracts frequency-domain HRV features using Welch's method.
    
    The RR interval series is first interpolated to create a uniformly
    sampled signal, then PSD is estimated using Welch's periodogram.
    
    Frequency bands (wearable-safe):
    - LF: 0.04 - 0.15 Hz
    - HF: 0.15 - 0.40 Hz
    
    VLF is intentionally excluded for 60s window stability.
    """
    
    # Feature names in order (matches to_array output)
    FEATURE_NAMES = [
        "lf_power", "hf_power", "lf_hf_ratio", 
        "total_power", "lf_nu", "hf_nu"
    ]
    
    # Frequency bands (Hz)
    LF_BAND = (0.04, 0.15)
    HF_BAND = (0.15, 0.40)
    
    def __init__(
        self,
        resample_rate: float = 4.0,  # Hz - standard for HRV
        min_intervals: int = 20,     # Minimum for reliable PSD
        nperseg: Optional[int] = None,  # Welch segment length
    ):
        """
        Initialize frequency-domain extractor.
        
        Args:
            resample_rate: Resampling frequency for interpolation (Hz)
            min_intervals: Minimum RR intervals required
            nperseg: Segment length for Welch's method (None = auto)
        """
        self.resample_rate = resample_rate
        self.min_intervals = min_intervals
        self.nperseg = nperseg
    
    def extract(self, rr_ms: np.ndarray) -> FrequencyDomainFeatures:
        """
        Extract frequency-domain features from RR intervals.
        
        Args:
            rr_ms: Array of RR intervals in milliseconds
            
        Returns:
            FrequencyDomainFeatures dataclass
        """
        n = len(rr_ms)
        
        # Check minimum data requirement
        if n < self.min_intervals:
            return self._create_invalid_features(n, f"Too few intervals: {n}")
        
        try:
            # Step 1: Create time axis (cumulative sum of RR)
            # RR[i] is the time BETWEEN beat i and beat i+1
            time_ms = np.cumsum(rr_ms)
            time_sec = time_ms / 1000.0
            
            # Shift to start at 0
            time_sec = np.insert(time_sec, 0, 0)[:-1]
            
            # Step 2: Interpolate to uniform sampling
            rr_interp, t_interp = self._interpolate_rr(rr_ms, time_sec)
            
            if len(rr_interp) < 10:
                return self._create_invalid_features(n, "Interpolation failed")
            
            # Step 3: Compute PSD using Welch's method
            freqs, psd = self._compute_psd(rr_interp)
            
            # Step 4: Calculate band powers
            lf_power = self._band_power(freqs, psd, self.LF_BAND)
            hf_power = self._band_power(freqs, psd, self.HF_BAND)
            
            # Step 5: Compute derived metrics
            total_power = lf_power + hf_power
            
            # LF/HF ratio (handle edge cases)
            if hf_power > 0:
                lf_hf_ratio = lf_power / hf_power
            else:
                lf_hf_ratio = np.nan
            
            # Normalized units (as percentage of LF+HF)
            if total_power > 0:
                lf_nu = (lf_power / total_power) * 100
                hf_nu = (hf_power / total_power) * 100
            else:
                lf_nu = np.nan
                hf_nu = np.nan
            
            features = FrequencyDomainFeatures(
                lf_power=lf_power,
                hf_power=hf_power,
                lf_hf_ratio=lf_hf_ratio,
                total_power=total_power,
                lf_nu=lf_nu,
                hf_nu=hf_nu,
                num_intervals=n,
                is_valid=True
            )
            
            # Validate
            if not self._validate_features(features):
                features.is_valid = False
            
            return features
            
        except Exception as e:
            return self._create_invalid_features(n, str(e))
    
    def _interpolate_rr(
        self, 
        rr_ms: np.ndarray, 
        time_sec: np.ndarray
    ) -> Tuple[np.ndarray, np.ndarray]:
        """
        Interpolate RR intervals to uniform sampling.
        
        Uses cubic spline interpolation.
        """
        # Create interpolation function
        # Use RR values at each beat time
        f_interp = interpolate.interp1d(
            time_sec, 
            rr_ms,
            kind='cubic',
            fill_value='extrapolate'
        )
        
        # Generate uniform time grid
        duration = time_sec[-1]
        n_samples = int(duration * self.resample_rate)
        t_uniform = np.linspace(0, duration, n_samples)
        
        # Interpolate
        rr_uniform = f_interp(t_uniform)
        
        return rr_uniform, t_uniform
    
    def _compute_psd(self, rr_interp: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Compute Power Spectral Density using Welch's method.
        
        Returns:
            (frequencies, psd) arrays
        """
        # Determine segment length
        if self.nperseg is None:
            # Use ~50% of signal length, minimum 16
            nperseg = max(16, len(rr_interp) // 2)
        else:
            nperseg = min(self.nperseg, len(rr_interp))
        
        # Welch's periodogram
        freqs, psd = signal.welch(
            rr_interp,
            fs=self.resample_rate,
            nperseg=nperseg,
            noverlap=nperseg // 2,
            detrend='linear',
            scaling='density'
        )
        
        return freqs, psd
    
    def _band_power(
        self, 
        freqs: np.ndarray, 
        psd: np.ndarray, 
        band: Tuple[float, float]
    ) -> float:
        """
        Calculate power in a frequency band.
        
        Uses trapezoidal integration.
        """
        # Find indices within band
        idx = np.logical_and(freqs >= band[0], freqs <= band[1])
        
        if not np.any(idx):
            return 0.0
        
        # Integrate using trapezoid rule
        # Use np.trapezoid (NumPy 2.0+) or scipy.integrate.trapezoid
        try:
            power = np.trapezoid(psd[idx], freqs[idx])
        except AttributeError:
            # Fallback for older NumPy versions
            power = np.trapz(psd[idx], freqs[idx])
        
        return float(power)
    
    def _validate_features(self, features: FrequencyDomainFeatures) -> bool:
        """Check if features are valid."""
        # Check for NaN/Inf in main features
        if not np.isfinite(features.lf_power):
            return False
        if not np.isfinite(features.hf_power):
            return False
        
        # Power should be non-negative
        if features.lf_power < 0 or features.hf_power < 0:
            return False
        
        return True
    
    def _create_invalid_features(
        self, 
        n: int, 
        reason: str
    ) -> FrequencyDomainFeatures:
        """Create invalid feature set with NaN values."""
        return FrequencyDomainFeatures(
            lf_power=np.nan,
            hf_power=np.nan,
            lf_hf_ratio=np.nan,
            total_power=np.nan,
            lf_nu=np.nan,
            hf_nu=np.nan,
            num_intervals=n,
            is_valid=False
        )
    
    @staticmethod
    def get_feature_descriptions() -> Dict[str, str]:
        """Get human-readable descriptions of each feature."""
        return {
            "lf_power": "Low frequency power (0.04-0.15 Hz) in ms² - sympathetic + parasympathetic",
            "hf_power": "High frequency power (0.15-0.4 Hz) in ms² - parasympathetic/vagal",
            "lf_hf_ratio": "LF/HF ratio - sympathovagal balance indicator",
            "total_power": "Total spectral power (LF + HF) in ms²",
            "lf_nu": "LF in normalized units (% of total)",
            "hf_nu": "HF in normalized units (% of total)",
        }
