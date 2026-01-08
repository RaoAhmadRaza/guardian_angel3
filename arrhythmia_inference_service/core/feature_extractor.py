"""
HRV Feature Extractor for Inference Service

Consolidated feature extraction (time-domain, frequency-domain, non-linear)
ported from the training codebase. No modifications to the computation logic.

Total features: 15
- Time-domain: 8 (mean_rr, sdnn, rmssd, pnn50, pnn20, mean_hr, std_hr, cv_rr)
- Frequency-domain: 6 (lf_power, hf_power, lf_hf_ratio, total_power, lf_nu, hf_nu)
- Non-linear: 1 (sample_entropy)
"""

from dataclasses import dataclass, field
from typing import Dict, List, Tuple

import numpy as np
from scipy import signal, interpolate


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class TimeDomainFeatures:
    """Time-domain HRV features."""
    mean_rr: float      # Mean RR interval (ms)
    sdnn: float         # Standard deviation of NN intervals (ms)
    rmssd: float        # Root mean square of successive differences (ms)
    pnn50: float        # % of successive differences > 50ms (0-100)
    pnn20: float        # % of successive differences > 20ms (0-100)
    mean_hr: float      # Mean heart rate (BPM)
    std_hr: float       # Standard deviation of heart rate (BPM)
    cv_rr: float        # Coefficient of variation (SDNN/mean_rr * 100)
    num_intervals: int
    is_valid: bool
    
    def to_dict(self) -> Dict[str, float]:
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
        return np.array([
            self.mean_rr, self.sdnn, self.rmssd, self.pnn50,
            self.pnn20, self.mean_hr, self.std_hr, self.cv_rr,
        ])


@dataclass
class FrequencyDomainFeatures:
    """Frequency-domain HRV features."""
    lf_power: float       # Low frequency power (0.04-0.15 Hz) in ms^2
    hf_power: float       # High frequency power (0.15-0.4 Hz) in ms^2
    lf_hf_ratio: float    # LF/HF ratio
    total_power: float    # Total power (LF + HF) in ms^2
    lf_nu: float          # LF in normalized units (0-100)
    hf_nu: float          # HF in normalized units (0-100)
    num_intervals: int
    is_valid: bool
    
    def to_dict(self) -> Dict[str, float]:
        return {
            "lf_power": self.lf_power,
            "hf_power": self.hf_power,
            "lf_hf_ratio": self.lf_hf_ratio,
            "total_power": self.total_power,
            "lf_nu": self.lf_nu,
            "hf_nu": self.hf_nu,
        }
    
    def to_array(self) -> np.ndarray:
        return np.array([
            self.lf_power, self.hf_power, self.lf_hf_ratio,
            self.total_power, self.lf_nu, self.hf_nu,
        ])


@dataclass
class NonlinearFeatures:
    """Non-linear HRV features."""
    sample_entropy: float
    num_intervals: int
    is_valid: bool
    
    def to_dict(self) -> Dict[str, float]:
        return {"sample_entropy": self.sample_entropy}
    
    def to_array(self) -> np.ndarray:
        return np.array([self.sample_entropy])


@dataclass
class HRVFeatures:
    """Combined HRV features from all domains."""
    time_domain: TimeDomainFeatures
    frequency_domain: FrequencyDomainFeatures
    nonlinear: NonlinearFeatures
    num_intervals: int
    is_valid: bool
    invalid_domains: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, float]:
        result = {}
        result.update(self.time_domain.to_dict())
        result.update(self.frequency_domain.to_dict())
        result.update(self.nonlinear.to_dict())
        return result
    
    def to_array(self) -> np.ndarray:
        return np.concatenate([
            self.time_domain.to_array(),
            self.frequency_domain.to_array(),
            self.nonlinear.to_array()
        ])
    
    @property
    def feature_names(self) -> List[str]:
        return HRVFeatureExtractor.FEATURE_NAMES


# =============================================================================
# MAIN EXTRACTOR CLASS
# =============================================================================

class HRVFeatureExtractor:
    """
    Unified HRV feature extractor.
    
    Extracts 15 features from RR intervals:
    - 8 time-domain
    - 6 frequency-domain
    - 1 non-linear (sample entropy)
    """
    
    FEATURE_NAMES = [
        # Time-domain (8)
        "mean_rr", "sdnn", "rmssd", "pnn50", 
        "pnn20", "mean_hr", "std_hr", "cv_rr",
        # Frequency-domain (6)
        "lf_power", "hf_power", "lf_hf_ratio", 
        "total_power", "lf_nu", "hf_nu",
        # Non-linear (1)
        "sample_entropy"
    ]
    
    # Frequency bands (Hz)
    LF_BAND = (0.04, 0.15)
    HF_BAND = (0.15, 0.40)
    
    def __init__(
        self,
        td_min_intervals: int = 10,
        fd_resample_rate: float = 4.0,
        fd_min_intervals: int = 20,
        nl_m: int = 2,
        nl_r_factor: float = 0.2,
        nl_min_intervals: int = 30,
    ):
        """
        Initialize unified HRV extractor.
        
        Args:
            td_min_intervals: Min intervals for time-domain
            fd_resample_rate: Resampling rate for frequency analysis
            fd_min_intervals: Min intervals for frequency-domain
            nl_m: Embedding dimension for sample entropy
            nl_r_factor: Tolerance factor for sample entropy
            nl_min_intervals: Min intervals for non-linear
        """
        self.td_min_intervals = td_min_intervals
        self.fd_resample_rate = fd_resample_rate
        self.fd_min_intervals = fd_min_intervals
        self.nl_m = nl_m
        self.nl_r_factor = nl_r_factor
        self.nl_min_intervals = nl_min_intervals
    
    def extract(self, rr_ms: np.ndarray) -> HRVFeatures:
        """
        Extract all HRV features from RR intervals.
        
        Args:
            rr_ms: Array of RR intervals in milliseconds
            
        Returns:
            HRVFeatures with all domain features
        """
        n = len(rr_ms)
        invalid_domains = []
        
        # Extract time-domain features
        td_features = self._extract_time_domain(rr_ms)
        if not td_features.is_valid:
            invalid_domains.append("time_domain")
        
        # Extract frequency-domain features
        fd_features = self._extract_frequency_domain(rr_ms)
        if not fd_features.is_valid:
            invalid_domains.append("frequency_domain")
        
        # Extract non-linear features
        nl_features = self._extract_nonlinear(rr_ms)
        if not nl_features.is_valid:
            invalid_domains.append("nonlinear")
        
        # Overall validity: time-domain must be valid
        is_valid = td_features.is_valid
        
        return HRVFeatures(
            time_domain=td_features,
            frequency_domain=fd_features,
            nonlinear=nl_features,
            num_intervals=n,
            is_valid=is_valid,
            invalid_domains=invalid_domains
        )
    
    # =========================================================================
    # TIME-DOMAIN FEATURES
    # =========================================================================
    
    def _extract_time_domain(self, rr_ms: np.ndarray) -> TimeDomainFeatures:
        """Extract 8 time-domain features."""
        n = len(rr_ms)
        
        if n < self.td_min_intervals:
            return self._invalid_time_domain(n)
        
        try:
            mean_rr = float(np.mean(rr_ms))
            sdnn = float(np.std(rr_ms, ddof=1))
            
            # Successive differences
            diff = np.diff(rr_ms)
            rmssd = float(np.sqrt(np.mean(diff ** 2)))
            
            # pNNx
            abs_diff = np.abs(diff)
            pnn50 = float(np.sum(abs_diff > 50) / len(diff) * 100) if len(diff) > 0 else 0.0
            pnn20 = float(np.sum(abs_diff > 20) / len(diff) * 100) if len(diff) > 0 else 0.0
            
            # Heart rate
            hr_bpm = 60000.0 / rr_ms
            mean_hr = float(np.mean(hr_bpm))
            std_hr = float(np.std(hr_bpm, ddof=1))
            
            # Coefficient of variation
            cv_rr = float(sdnn / mean_rr * 100) if mean_rr > 0 else 0.0
            
            features = TimeDomainFeatures(
                mean_rr=mean_rr,
                sdnn=sdnn,
                rmssd=rmssd,
                pnn50=pnn50,
                pnn20=pnn20,
                mean_hr=mean_hr,
                std_hr=std_hr,
                cv_rr=cv_rr,
                num_intervals=n,
                is_valid=True
            )
            
            # Validate
            if not self._validate_time_domain(features):
                features = TimeDomainFeatures(
                    mean_rr=features.mean_rr,
                    sdnn=features.sdnn,
                    rmssd=features.rmssd,
                    pnn50=features.pnn50,
                    pnn20=features.pnn20,
                    mean_hr=features.mean_hr,
                    std_hr=features.std_hr,
                    cv_rr=features.cv_rr,
                    num_intervals=n,
                    is_valid=False
                )
            
            return features
            
        except Exception:
            return self._invalid_time_domain(n)
    
    def _validate_time_domain(self, f: TimeDomainFeatures) -> bool:
        """Check if time-domain features are valid."""
        values = f.to_array()
        if np.any(~np.isfinite(values)):
            return False
        if f.mean_rr <= 0 or f.mean_rr > 3000:
            return False
        if f.mean_hr <= 0 or f.mean_hr > 300:
            return False
        if f.sdnn < 0 or f.rmssd < 0:
            return False
        if f.pnn50 < 0 or f.pnn50 > 100:
            return False
        return True
    
    def _invalid_time_domain(self, n: int) -> TimeDomainFeatures:
        """Create invalid time-domain features."""
        return TimeDomainFeatures(
            mean_rr=np.nan, sdnn=np.nan, rmssd=np.nan,
            pnn50=np.nan, pnn20=np.nan, mean_hr=np.nan,
            std_hr=np.nan, cv_rr=np.nan,
            num_intervals=n, is_valid=False
        )
    
    # =========================================================================
    # FREQUENCY-DOMAIN FEATURES
    # =========================================================================
    
    def _extract_frequency_domain(self, rr_ms: np.ndarray) -> FrequencyDomainFeatures:
        """Extract 6 frequency-domain features using Welch's method."""
        n = len(rr_ms)
        
        if n < self.fd_min_intervals:
            return self._invalid_frequency_domain(n)
        
        try:
            # Create time axis
            time_ms = np.cumsum(rr_ms)
            time_sec = time_ms / 1000.0
            time_sec = np.insert(time_sec, 0, 0)[:-1]
            
            # Interpolate to uniform sampling
            rr_interp, _ = self._interpolate_rr(rr_ms, time_sec)
            
            if len(rr_interp) < 10:
                return self._invalid_frequency_domain(n)
            
            # Compute PSD
            freqs, psd = self._compute_psd(rr_interp)
            
            # Band powers
            lf_power = self._band_power(freqs, psd, self.LF_BAND)
            hf_power = self._band_power(freqs, psd, self.HF_BAND)
            
            total_power = lf_power + hf_power
            lf_hf_ratio = lf_power / hf_power if hf_power > 0 else np.nan
            lf_nu = (lf_power / total_power) * 100 if total_power > 0 else np.nan
            hf_nu = (hf_power / total_power) * 100 if total_power > 0 else np.nan
            
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
            
            if not self._validate_frequency_domain(features):
                features = FrequencyDomainFeatures(
                    lf_power=features.lf_power,
                    hf_power=features.hf_power,
                    lf_hf_ratio=features.lf_hf_ratio,
                    total_power=features.total_power,
                    lf_nu=features.lf_nu,
                    hf_nu=features.hf_nu,
                    num_intervals=n,
                    is_valid=False
                )
            
            return features
            
        except Exception:
            return self._invalid_frequency_domain(n)
    
    def _interpolate_rr(
        self, 
        rr_ms: np.ndarray, 
        time_sec: np.ndarray
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Interpolate RR intervals to uniform sampling."""
        f_interp = interpolate.interp1d(
            time_sec, rr_ms,
            kind='cubic',
            fill_value='extrapolate'
        )
        
        duration = time_sec[-1]
        n_samples = int(duration * self.fd_resample_rate)
        t_uniform = np.linspace(0, duration, n_samples)
        rr_uniform = f_interp(t_uniform)
        
        return rr_uniform, t_uniform
    
    def _compute_psd(self, rr_interp: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """Compute PSD using Welch's method."""
        nperseg = max(16, len(rr_interp) // 2)
        
        freqs, psd = signal.welch(
            rr_interp,
            fs=self.fd_resample_rate,
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
        """Calculate power in a frequency band."""
        idx = np.logical_and(freqs >= band[0], freqs <= band[1])
        if not np.any(idx):
            return 0.0
        
        try:
            power = np.trapezoid(psd[idx], freqs[idx])
        except AttributeError:
            power = np.trapz(psd[idx], freqs[idx])
        
        return float(power)
    
    def _validate_frequency_domain(self, f: FrequencyDomainFeatures) -> bool:
        """Check if frequency-domain features are valid."""
        if not np.isfinite(f.lf_power) or not np.isfinite(f.hf_power):
            return False
        if f.lf_power < 0 or f.hf_power < 0:
            return False
        return True
    
    def _invalid_frequency_domain(self, n: int) -> FrequencyDomainFeatures:
        """Create invalid frequency-domain features."""
        return FrequencyDomainFeatures(
            lf_power=np.nan, hf_power=np.nan, lf_hf_ratio=np.nan,
            total_power=np.nan, lf_nu=np.nan, hf_nu=np.nan,
            num_intervals=n, is_valid=False
        )
    
    # =========================================================================
    # NON-LINEAR FEATURES
    # =========================================================================
    
    def _extract_nonlinear(self, rr_ms: np.ndarray) -> NonlinearFeatures:
        """Extract sample entropy."""
        n = len(rr_ms)
        
        if n < self.nl_min_intervals:
            return self._invalid_nonlinear(n)
        
        try:
            sampen = self._sample_entropy(rr_ms, self.nl_m, self.nl_r_factor)
            
            features = NonlinearFeatures(
                sample_entropy=sampen,
                num_intervals=n,
                is_valid=True
            )
            
            if not self._validate_nonlinear(features):
                features = NonlinearFeatures(
                    sample_entropy=features.sample_entropy,
                    num_intervals=n,
                    is_valid=False
                )
            
            return features
            
        except Exception:
            return self._invalid_nonlinear(n)
    
    def _sample_entropy(
        self, 
        signal_data: np.ndarray, 
        m: int, 
        r_factor: float
    ) -> float:
        """
        Calculate Sample Entropy.
        
        SampEn(m, r, N) = -ln(A/B)
        """
        N = len(signal_data)
        r = r_factor * np.std(signal_data, ddof=1)
        
        if r == 0:
            return 0.0
        
        B = self._count_matches(signal_data, m, r)
        A = self._count_matches(signal_data, m + 1, r)
        
        if A == 0 or B == 0:
            return np.nan
        
        return -np.log(A / B)
    
    def _count_matches(
        self, 
        signal_data: np.ndarray, 
        m: int, 
        r: float
    ) -> int:
        """Count template matches of length m."""
        N = len(signal_data)
        count = 0
        
        templates = np.array([signal_data[i:i+m] for i in range(N - m)])
        
        for i in range(len(templates)):
            for j in range(i + 1, len(templates)):
                dist = np.max(np.abs(templates[i] - templates[j]))
                if dist <= r:
                    count += 1
        
        return count
    
    def _validate_nonlinear(self, f: NonlinearFeatures) -> bool:
        """Check if non-linear features are valid."""
        if not np.isfinite(f.sample_entropy):
            return False
        if f.sample_entropy < 0:
            return False
        return True
    
    def _invalid_nonlinear(self, n: int) -> NonlinearFeatures:
        """Create invalid non-linear features."""
        return NonlinearFeatures(
            sample_entropy=np.nan,
            num_intervals=n,
            is_valid=False
        )
