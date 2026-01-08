"""
Unified HRV Feature Extractor

Combines time-domain, frequency-domain, and non-linear features
into a single feature vector for model training.

Total features: 15
- Time-domain: 8 (mean_rr, sdnn, rmssd, pnn50, pnn20, mean_hr, std_hr, cv_rr)
- Frequency-domain: 6 (lf_power, hf_power, lf_hf_ratio, total_power, lf_nu, hf_nu)
- Non-linear: 1 (sample_entropy)
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional
import numpy as np

from .time_domain import TimeDomainExtractor, TimeDomainFeatures
from .frequency_domain import FrequencyDomainExtractor, FrequencyDomainFeatures
from .nonlinear import NonlinearExtractor, NonlinearFeatures


@dataclass
class HRVFeatures:
    """
    Combined HRV features from all domains.
    """
    # Individual domain features
    time_domain: TimeDomainFeatures
    frequency_domain: FrequencyDomainFeatures
    nonlinear: NonlinearFeatures
    
    # Metadata
    num_intervals: int
    is_valid: bool
    invalid_domains: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, float]:
        """Convert all features to a flat dictionary."""
        result = {}
        result.update(self.time_domain.to_dict())
        result.update(self.frequency_domain.to_dict())
        result.update(self.nonlinear.to_dict())
        return result
    
    def to_array(self) -> np.ndarray:
        """Convert all features to a single numpy array."""
        return np.concatenate([
            self.time_domain.to_array(),
            self.frequency_domain.to_array(),
            self.nonlinear.to_array()
        ])
    
    @property
    def feature_names(self) -> List[str]:
        """Get ordered list of all feature names."""
        return (
            TimeDomainExtractor.FEATURE_NAMES +
            FrequencyDomainExtractor.FEATURE_NAMES +
            NonlinearExtractor.FEATURE_NAMES
        )


class HRVFeatureExtractor:
    """
    Unified extractor for all HRV features.
    
    Extracts:
    - 8 time-domain features
    - 6 frequency-domain features  
    - 1 non-linear feature (sample entropy)
    
    Total: 15 features per window
    """
    
    # All feature names in order
    FEATURE_NAMES = (
        TimeDomainExtractor.FEATURE_NAMES +
        FrequencyDomainExtractor.FEATURE_NAMES +
        NonlinearExtractor.FEATURE_NAMES
    )
    
    def __init__(
        self,
        # Time-domain settings
        td_min_intervals: int = 10,
        # Frequency-domain settings
        fd_resample_rate: float = 4.0,
        fd_min_intervals: int = 20,
        # Non-linear settings
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
        self.time_domain = TimeDomainExtractor(min_intervals=td_min_intervals)
        self.frequency_domain = FrequencyDomainExtractor(
            resample_rate=fd_resample_rate,
            min_intervals=fd_min_intervals
        )
        self.nonlinear = NonlinearExtractor(
            m=nl_m,
            r_factor=nl_r_factor,
            min_intervals=nl_min_intervals
        )
    
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
        td_features = self.time_domain.extract(rr_ms)
        if not td_features.is_valid:
            invalid_domains.append("time_domain")
        
        # Extract frequency-domain features
        fd_features = self.frequency_domain.extract(rr_ms)
        if not fd_features.is_valid:
            invalid_domains.append("frequency_domain")
        
        # Extract non-linear features
        nl_features = self.nonlinear.extract(rr_ms)
        if not nl_features.is_valid:
            invalid_domains.append("nonlinear")
        
        # Overall validity: time-domain must be valid (primary features)
        is_valid = td_features.is_valid
        
        return HRVFeatures(
            time_domain=td_features,
            frequency_domain=fd_features,
            nonlinear=nl_features,
            num_intervals=n,
            is_valid=is_valid,
            invalid_domains=invalid_domains
        )
    
    def get_feature_count(self) -> int:
        """Get total number of features."""
        return len(self.FEATURE_NAMES)
    
    @staticmethod
    def get_all_descriptions() -> Dict[str, str]:
        """Get descriptions for all features."""
        descriptions = {}
        descriptions.update(TimeDomainExtractor.get_feature_descriptions())
        descriptions.update(FrequencyDomainExtractor.get_feature_descriptions())
        descriptions.update(NonlinearExtractor.get_feature_descriptions())
        return descriptions
