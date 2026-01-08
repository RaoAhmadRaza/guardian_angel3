"""
Pipeline Integration Tests

Tests the full end-to-end pipeline:
    Record → RR Extraction → Preprocessing → Features

This ensures all components work together correctly.
"""

import sys
from pathlib import Path
import pytest
import numpy as np

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.data.loader import MITBIHLoader
from src.data.rr_extraction import RRIntervalExtractor
from src.data.preprocessing import RRPreprocessor
from src.features.time_domain import TimeDomainExtractor


# Test data directory
DATA_DIR = PROJECT_ROOT / "dataset" / "mit-bih-arrhythmia-database-1.0.0"
SKIP_IF_NO_DATA = pytest.mark.skipif(
    not DATA_DIR.exists(),
    reason="MIT-BIH dataset not found"
)


class TestPipelineIntegration:
    """Test full pipeline from record to features."""
    
    @SKIP_IF_NO_DATA
    def test_full_pipeline_single_record(self):
        """Test complete pipeline on record 100."""
        # Load
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        # Extract RR
        rr_extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = rr_extractor.extract(record)
        
        # Preprocess
        preprocessor = RRPreprocessor(
            min_rr_ms=300.0,
            max_rr_ms=2000.0,
            window_size_sec=60.0,
            window_step_sec=30.0,
            min_beats_per_window=40
        )
        windows, stats = preprocessor.process_record(rr_data)
        
        # Extract features
        feature_extractor = TimeDomainExtractor()
        
        valid_windows = [w for w in windows if w.is_valid]
        assert len(valid_windows) > 0, "No valid windows produced"
        
        for window in valid_windows[:5]:  # Test first 5
            features = feature_extractor.extract(window.rr_intervals_ms)
            
            # All features should be valid
            assert features.is_valid, f"Invalid features for window {window.window_index}"
            
            # Features should be finite
            arr = features.to_array()
            assert np.all(np.isfinite(arr)), "Found NaN/Inf in features"
            
            # Basic sanity checks
            assert 30 < features.mean_hr < 200, f"Implausible HR: {features.mean_hr}"
            assert features.sdnn >= 0, f"Negative SDNN: {features.sdnn}"
            assert features.rmssd >= 0, f"Negative RMSSD: {features.rmssd}"
    
    @SKIP_IF_NO_DATA
    def test_pipeline_runs_without_crash(self):
        """Test that pipeline completes without errors."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        rr_extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = rr_extractor.extract(record)
        
        preprocessor = RRPreprocessor()
        windows, stats = preprocessor.process_record(rr_data)
        
        feature_extractor = TimeDomainExtractor()
        
        # Process all windows
        all_features = []
        for window in windows:
            if window.is_valid:
                features = feature_extractor.extract(window.rr_intervals_ms)
                all_features.append(features)
        
        # Should have produced features
        assert len(all_features) > 0
    
    @SKIP_IF_NO_DATA
    def test_normal_vs_abnormal_record_contrast(self):
        """
        Test that normal and abnormal records produce different feature patterns.
        
        Record 100: Mostly normal sinus rhythm
        Record 207: High ventricular ectopy
        """
        loader = MITBIHLoader(DATA_DIR)
        rr_extractor = RRIntervalExtractor()
        preprocessor = RRPreprocessor()
        feature_extractor = TimeDomainExtractor()
        
        def get_mean_features(record_id: str):
            """Get mean features across all windows of a record."""
            record = loader.load_record(record_id)
            rr_data = rr_extractor.extract(record)
            windows, _ = preprocessor.process_record(rr_data)
            
            rmssd_values = []
            pnn50_values = []
            
            for window in windows:
                if window.is_valid:
                    features = feature_extractor.extract(window.rr_intervals_ms)
                    if features.is_valid:
                        rmssd_values.append(features.rmssd)
                        pnn50_values.append(features.pnn50)
            
            return np.mean(rmssd_values), np.mean(pnn50_values)
        
        # Get features for both records
        rmssd_100, pnn50_100 = get_mean_features("100")  # Normal
        rmssd_207, pnn50_207 = get_mean_features("207")  # Abnormal
        
        # Record 207 should have MUCH higher variability markers
        assert rmssd_207 > rmssd_100, f"Expected higher RMSSD in abnormal record: {rmssd_207} vs {rmssd_100}"
        assert pnn50_207 > pnn50_100, f"Expected higher pNN50 in abnormal record: {pnn50_207} vs {pnn50_100}"


class TestDataQuality:
    """Test data quality throughout pipeline."""
    
    @SKIP_IF_NO_DATA
    def test_no_data_leakage_in_windows(self):
        """Test that windows don't share data inappropriately."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        rr_extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = rr_extractor.extract(record)
        
        # With 30s step, consecutive windows should overlap ~50%
        preprocessor = RRPreprocessor(
            window_size_sec=60.0,
            window_step_sec=30.0,
            min_beats_per_window=40
        )
        windows, _ = preprocessor.process_record(rr_data)
        
        valid_windows = [w for w in windows if w.is_valid]
        
        if len(valid_windows) >= 2:
            w1 = valid_windows[0]
            w2 = valid_windows[1]
            
            # Windows should have different start samples
            assert w1.start_sample != w2.start_sample
    
    @SKIP_IF_NO_DATA
    def test_feature_consistency(self):
        """Test that same data produces same features."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        rr_extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        preprocessor = RRPreprocessor()
        feature_extractor = TimeDomainExtractor()
        
        # Run twice
        rr_data1 = rr_extractor.extract(record)
        windows1, _ = preprocessor.process_record(rr_data1)
        
        rr_data2 = rr_extractor.extract(record)
        windows2, _ = preprocessor.process_record(rr_data2)
        
        # Get first valid window from each
        valid1 = [w for w in windows1 if w.is_valid][0]
        valid2 = [w for w in windows2 if w.is_valid][0]
        
        f1 = feature_extractor.extract(valid1.rr_intervals_ms)
        f2 = feature_extractor.extract(valid2.rr_intervals_ms)
        
        # Features should be identical
        assert np.allclose(f1.to_array(), f2.to_array())
