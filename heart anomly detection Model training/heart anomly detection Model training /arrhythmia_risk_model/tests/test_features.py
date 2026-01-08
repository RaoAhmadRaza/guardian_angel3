"""
Tests for HRV Feature Extraction

These tests validate:
1. Features exist and are finite
2. Zero variance RR → low RMSSD (stable rhythm)
3. Artificial irregular RR → high RMSSD (irregular rhythm)
4. Features fall in expected ranges
"""

import sys
from pathlib import Path
import numpy as np
import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.features.time_domain import TimeDomainExtractor, TimeDomainFeatures


class TestTimeDomainFeatures:
    """Test time-domain HRV feature calculations."""
    
    def test_basic_extraction(self):
        """Test that extraction produces valid features."""
        # Regular RR intervals (800ms = 75 BPM)
        rr_ms = np.array([800.0] * 50)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        assert features.is_valid
        assert features.num_intervals == 50
    
    def test_features_are_finite(self):
        """Test that all features are finite (no NaN/Inf)."""
        # Slightly varied RR to avoid zero division
        rr_ms = np.random.normal(800, 20, 50)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        arr = features.to_array()
        assert np.all(np.isfinite(arr)), "Found NaN or Inf in features"
    
    def test_mean_rr_calculation(self):
        """Test mean RR calculation."""
        rr_ms = np.array([800.0, 850.0, 750.0, 900.0])  # Mean = 825
        
        extractor = TimeDomainExtractor(min_intervals=2)
        features = extractor.extract(rr_ms)
        
        assert features.is_valid, "Features should be valid"
        assert abs(features.mean_rr - 825.0) < 0.01
    
    def test_mean_hr_calculation(self):
        """Test mean HR from RR."""
        # 800ms = 75 BPM
        rr_ms = np.array([800.0] * 20)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        assert abs(features.mean_hr - 75.0) < 0.1
    
    def test_zero_variance_rr_gives_low_rmssd(self):
        """
        Test that perfectly regular RR → RMSSD = 0.
        
        This is crucial: stable rhythm means low beat-to-beat variability.
        """
        # Perfectly regular rhythm
        rr_ms = np.array([800.0] * 50)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        # RMSSD should be 0 (no successive differences)
        assert features.rmssd == 0.0, f"Expected RMSSD=0 for regular rhythm, got {features.rmssd}"
        
        # SDNN should also be 0
        assert features.sdnn == 0.0
        
        # pNN50 should be 0 (no large differences)
        assert features.pnn50 == 0.0
    
    def test_irregular_rr_gives_high_rmssd(self):
        """
        Test that alternating RR → high RMSSD.
        
        This simulates AF or bigeminy pattern.
        """
        # Alternating pattern: 600-1000-600-1000 (simulates bigeminy)
        rr_ms = np.array([600.0, 1000.0] * 25)  # 50 intervals
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        # Successive differences are all 400ms
        # RMSSD = sqrt(mean(400^2)) = 400
        assert features.rmssd > 350, f"Expected high RMSSD for irregular rhythm, got {features.rmssd}"
        
        # pNN50 should be 100% (all differences > 50ms)
        assert features.pnn50 > 95, f"Expected high pNN50, got {features.pnn50}"
    
    def test_rmssd_formula(self):
        """Test RMSSD calculation matches formula."""
        # Known differences: [100, -200, 50]
        rr_ms = np.array([800.0, 900.0, 700.0, 750.0])
        
        extractor = TimeDomainExtractor(min_intervals=2)
        features = extractor.extract(rr_ms)
        
        # Manual calculation
        diff = np.diff(rr_ms)  # [100, -200, 50]
        expected_rmssd = np.sqrt(np.mean(diff ** 2))
        
        assert features.is_valid, "Features should be valid"
        assert abs(features.rmssd - expected_rmssd) < 0.01
    
    def test_pnn50_calculation(self):
        """Test pNN50 percentage calculation."""
        # 3 intervals: differences of [100, 30] → 1/2 = 50% > 50ms
        rr_ms = np.array([800.0, 900.0, 870.0])
        
        extractor = TimeDomainExtractor(min_intervals=2)
        features = extractor.extract(rr_ms)
        
        assert features.is_valid, "Features should be valid"
        assert abs(features.pnn50 - 50.0) < 0.01
    
    def test_insufficient_data_marked_invalid(self):
        """Test that too few intervals produces invalid features."""
        rr_ms = np.array([800.0, 850.0])  # Only 2 intervals
        
        extractor = TimeDomainExtractor(min_intervals=10)
        features = extractor.extract(rr_ms)
        
        assert not features.is_valid
    
    def test_to_dict_and_array(self):
        """Test conversion methods."""
        rr_ms = np.random.normal(800, 30, 50)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        # to_dict should have all keys
        d = features.to_dict()
        assert "mean_rr" in d
        assert "rmssd" in d
        assert "pnn50" in d
        assert len(d) == 8
        
        # to_array should have correct length
        arr = features.to_array()
        assert len(arr) == 8
    
    def test_feature_names_match_order(self):
        """Test that feature names match array order."""
        rr_ms = np.random.normal(800, 30, 50)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        arr = features.to_array()
        d = features.to_dict()
        
        for i, name in enumerate(extractor.FEATURE_NAMES):
            assert abs(arr[i] - d[name]) < 0.001
    
    def test_physiological_ranges_normal(self):
        """Test that features for normal rhythm are in expected ranges."""
        # Simulate normal sinus rhythm with slight variability
        np.random.seed(42)
        rr_ms = np.random.normal(800, 30, 100)  # 75 BPM, ~30ms variation
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        # Expected ranges for normal rhythm
        assert 70 < features.mean_hr < 80, f"HR out of range: {features.mean_hr}"
        assert 20 < features.sdnn < 60, f"SDNN out of range: {features.sdnn}"
        assert 10 < features.rmssd < 100, f"RMSSD out of range: {features.rmssd}"


class TestTimeDomainEdgeCases:
    """Test edge cases and error handling."""
    
    def test_empty_array(self):
        """Test handling of empty input."""
        rr_ms = np.array([])
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        assert not features.is_valid
    
    def test_single_interval(self):
        """Test handling of single interval."""
        rr_ms = np.array([800.0])
        
        extractor = TimeDomainExtractor(min_intervals=10)
        features = extractor.extract(rr_ms)
        
        assert not features.is_valid
    
    def test_extreme_values(self):
        """Test handling of extreme but valid RR values."""
        # Very slow HR (40 BPM = 1500ms)
        rr_ms = np.random.normal(1500, 50, 50)
        
        extractor = TimeDomainExtractor()
        features = extractor.extract(rr_ms)
        
        assert features.is_valid
        assert 35 < features.mean_hr < 45
