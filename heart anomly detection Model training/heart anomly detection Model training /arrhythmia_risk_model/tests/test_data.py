"""
Tests for Data Loading and RR Processing

These tests validate the foundation of the pipeline:
1. RR extraction produces correct outputs
2. No RR outside physiological bounds after cleaning
3. Pipeline handles edge cases correctly
"""

import sys
from pathlib import Path
import pytest
import numpy as np

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.data.loader import MITBIHLoader, MITBIH_RECORD_IDS, PACED_RECORDS
from src.data.rr_extraction import RRIntervalExtractor, NORMAL_BEATS, VENTRICULAR_BEATS
from src.data.preprocessing import RRPreprocessor


# Test data directory - skip tests if not available
DATA_DIR = PROJECT_ROOT / "dataset" / "mit-bih-arrhythmia-database-1.0.0"
SKIP_IF_NO_DATA = pytest.mark.skipif(
    not DATA_DIR.exists(),
    reason="MIT-BIH dataset not found"
)


class TestMITBIHLoader:
    """Test MIT-BIH data loading functionality."""
    
    @SKIP_IF_NO_DATA
    def test_load_single_record(self):
        """Test loading a single record."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        assert record.record_id == "100"
        assert record.sampling_frequency == 360.0
        assert record.num_beats > 0
        assert len(record.annotation_samples) == len(record.annotation_symbols)
    
    @SKIP_IF_NO_DATA
    def test_record_has_annotations(self):
        """Test that record has beat annotations."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        # Should have at least 1000 beats in 30-min record
        assert record.num_beats > 1000
        
        # Annotations should be positive sample indices
        assert np.all(record.annotation_samples > 0)
        
        # Annotations should be sorted
        assert np.all(np.diff(record.annotation_samples) > 0)
    
    @SKIP_IF_NO_DATA
    def test_exclude_paced_records(self):
        """Test that paced records are excluded by default."""
        records = MITBIHLoader.get_available_records(exclude_paced=True)
        
        for paced_id in PACED_RECORDS:
            assert paced_id not in records
    
    def test_record_id_list(self):
        """Test that record IDs are correctly defined."""
        assert len(MITBIH_RECORD_IDS) == 48
        assert "100" in MITBIH_RECORD_IDS
        assert "234" in MITBIH_RECORD_IDS


class TestRRExtraction:
    """Test RR interval extraction."""
    
    @SKIP_IF_NO_DATA
    def test_extract_rr_intervals(self):
        """Test basic RR interval extraction."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        # Should have intervals
        assert rr_data.num_intervals > 0
        
        # RR should be positive
        assert np.all(rr_data.rr_intervals_ms > 0)
        
        # RR should be finite
        assert np.all(np.isfinite(rr_data.rr_intervals_ms))
    
    @SKIP_IF_NO_DATA
    def test_rr_intervals_in_milliseconds(self):
        """Test that RR intervals are in milliseconds (not samples)."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        # Mean RR should be ~600-1200ms for normal HR of 50-100 BPM
        mean_rr = np.mean(rr_data.rr_intervals_ms)
        assert 300 < mean_rr < 2000, f"Mean RR {mean_rr}ms outside expected range"
    
    @SKIP_IF_NO_DATA
    def test_beat_type_alignment(self):
        """Test that beat types align with RR intervals."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        # One beat type per interval
        assert len(rr_data.beat_types) == len(rr_data.rr_intervals_ms)
        
        # Beat types should be strings
        assert all(isinstance(bt, str) for bt in rr_data.beat_types)
    
    @SKIP_IF_NO_DATA
    def test_no_negative_rr(self):
        """Test that no negative RR intervals exist."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        assert np.all(rr_data.rr_intervals_ms > 0), "Found negative RR intervals"
    
    @SKIP_IF_NO_DATA
    def test_no_zero_rr(self):
        """Test that no zero RR intervals exist."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        assert np.all(rr_data.rr_intervals_ms != 0), "Found zero RR intervals"


class TestPreprocessing:
    """Test RR interval preprocessing."""
    
    @SKIP_IF_NO_DATA
    def test_bounds_filtering(self):
        """Test that physiological bounds are applied."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        preprocessor = RRPreprocessor(
            min_rr_ms=300.0,
            max_rr_ms=2000.0,
            window_size_sec=60.0,
            window_step_sec=30.0,
            min_beats_per_window=40
        )
        
        windows, stats = preprocessor.process_record(rr_data)
        
        # All windows should have RR within bounds
        for window in windows:
            if window.is_valid:
                assert np.all(window.rr_intervals_ms >= 300.0)
                assert np.all(window.rr_intervals_ms <= 2000.0)
    
    @SKIP_IF_NO_DATA
    def test_windowing_produces_valid_windows(self):
        """Test that windowing produces valid 60s windows."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        preprocessor = RRPreprocessor(
            min_rr_ms=300.0,
            max_rr_ms=2000.0,
            window_size_sec=60.0,
            window_step_sec=30.0,
            min_beats_per_window=40
        )
        
        windows, stats = preprocessor.process_record(rr_data)
        
        # Should have multiple windows from 30-min record
        assert stats.total_windows > 0
        assert stats.valid_windows > 0
        
        # Valid windows should meet criteria
        for window in windows:
            if window.is_valid:
                assert window.num_intervals >= 40
                assert 50 <= window.duration_sec <= 70  # ~60s with tolerance
    
    @SKIP_IF_NO_DATA
    def test_preprocessing_stats(self):
        """Test that preprocessing statistics are tracked."""
        loader = MITBIHLoader(DATA_DIR)
        record = loader.load_record("100")
        
        extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
        rr_data = extractor.extract(record)
        
        preprocessor = RRPreprocessor()
        windows, stats = preprocessor.process_record(rr_data)
        
        # Stats should be populated
        assert stats.record_id == "100"
        assert stats.total_intervals > 0
        assert stats.total_windows > 0
        assert stats.removed_too_short >= 0
        assert stats.removed_too_long >= 0
    
    def test_bounds_on_synthetic_data(self):
        """Test bounds filtering on synthetic RR data."""
        # Create synthetic RR with some out-of-bounds values
        rr_ms = np.array([200, 500, 800, 1000, 2500, 900, 100, 750])
        
        # Apply bounds manually (same logic as preprocessor)
        min_rr = 300
        max_rr = 2000
        valid = (rr_ms >= min_rr) & (rr_ms <= max_rr)
        clean_rr = rr_ms[valid]
        
        # Should keep 500, 800, 1000, 900, 750 (all within 300-2000)
        assert len(clean_rr) == 5
        assert np.all(clean_rr >= 300)
        assert np.all(clean_rr <= 2000)
