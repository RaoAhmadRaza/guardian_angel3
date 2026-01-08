"""
RR Interval Extraction

Converts expert-annotated ECG beats into RR intervals.
This is the ONLY signal your model will ever see - timing information.

Key concept:
    RR[i] = time between beat[i] and beat[i+1]
    BeatType[i] = type of beat at START of interval

Example:
    Beat samples: [1000, 1360, 1725] at 360 Hz
    RR (ms):      [1000.0, 1013.9]
    Beat types:   ['N', 'V']  (type of starting beat)
"""

from dataclasses import dataclass
from typing import List, Tuple, Optional
import numpy as np

from .loader import MITBIHRecord


# Beat annotation symbols in MIT-BIH
# Normal beats (use for normal HRV)
NORMAL_BEATS = {'N', 'L', 'R', 'e', 'j'}  # Normal, LBBB, RBBB, atrial escape, junctional escape

# Ventricular ectopic beats (important for arrhythmia detection!)
VENTRICULAR_BEATS = {'V', 'E', 'F'}  # PVC, ventricular escape, fusion

# Supraventricular ectopic beats
SUPRAVENTRICULAR_BEATS = {'A', 'a', 'J', 'S'}  # APB, aberrated APB, junctional premature, supraventricular premature

# Unclassified or artifact (exclude from analysis)
EXCLUDE_BEATS = {'/', 'f', 'Q', '|', '~', '+', 's', 'T', '*', 'D', '=', '"', '@'}


@dataclass
class RRIntervalData:
    """
    Container for extracted RR intervals from a single record.
    
    Each RR interval has:
    - rr_ms: the interval duration in milliseconds
    - beat_type: the symbol of the beat that STARTS the interval
    - sample_start: sample index of the starting beat (for traceability)
    """
    record_id: str
    rr_intervals_ms: np.ndarray      # RR intervals in milliseconds
    beat_types: List[str]            # Beat type at start of each interval
    sample_indices: np.ndarray       # Sample index of starting beat
    sampling_frequency: float        # For reference
    
    @property
    def num_intervals(self) -> int:
        return len(self.rr_intervals_ms)
    
    @property
    def duration_seconds(self) -> float:
        """Total duration covered by these RR intervals."""
        return np.sum(self.rr_intervals_ms) / 1000.0
    
    def get_beat_type_mask(self, beat_types: set) -> np.ndarray:
        """Get boolean mask for intervals starting with specific beat types."""
        return np.array([bt in beat_types for bt in self.beat_types])


class RRIntervalExtractor:
    """
    Extracts RR intervals from MIT-BIH annotations.
    
    This class converts beat timestamps into the timing differences
    that represent heart rate variability.
    
    CRITICAL: We do not filter out ectopic beats here.
    Ectopic beats ARE the signal for arrhythmia detection.
    We only exclude non-beat annotations (artifacts, noise markers).
    """
    
    # All valid beat annotations (exclude noise/artifact markers)
    VALID_BEATS = NORMAL_BEATS | VENTRICULAR_BEATS | SUPRAVENTRICULAR_BEATS
    
    def __init__(self, sampling_frequency: float = 360.0):
        """
        Initialize extractor.
        
        Args:
            sampling_frequency: Sampling rate in Hz (360 for MIT-BIH)
        """
        self.sampling_frequency = sampling_frequency
    
    def extract(self, record: MITBIHRecord) -> RRIntervalData:
        """
        Extract RR intervals from a MIT-BIH record.
        
        Args:
            record: Loaded MITBIHRecord with annotations
            
        Returns:
            RRIntervalData with intervals, beat types, and metadata
        """
        # Filter to only valid beat annotations
        valid_mask = [sym in self.VALID_BEATS for sym in record.annotation_symbols]
        valid_indices = np.where(valid_mask)[0]
        
        if len(valid_indices) < 2:
            raise ValueError(f"Record {record.record_id}: Not enough valid beats ({len(valid_indices)})")
        
        # Get filtered samples and symbols
        filtered_samples = record.annotation_samples[valid_indices]
        filtered_symbols = [record.annotation_symbols[i] for i in valid_indices]
        
        # Calculate RR intervals: difference between consecutive beats
        # RR[i] = sample[i+1] - sample[i]
        rr_samples = np.diff(filtered_samples)
        
        # Convert samples to milliseconds
        # ms = samples / (samples_per_second) * 1000
        rr_ms = (rr_samples / record.sampling_frequency) * 1000.0
        
        # Beat type is the beat at the START of each interval
        # So we take all symbols except the last one
        beat_types = filtered_symbols[:-1]
        
        # Sample indices (for traceability back to original record)
        sample_indices = filtered_samples[:-1]
        
        # Validation checks
        self._validate_extraction(rr_ms, record.record_id)
        
        return RRIntervalData(
            record_id=record.record_id,
            rr_intervals_ms=rr_ms,
            beat_types=beat_types,
            sample_indices=sample_indices,
            sampling_frequency=record.sampling_frequency
        )
    
    def _validate_extraction(self, rr_ms: np.ndarray, record_id: str) -> None:
        """
        Validate extracted RR intervals.
        
        Raises:
            ValueError: If extraction produced invalid data
        """
        # Check for negative or zero values (would indicate bug)
        if np.any(rr_ms <= 0):
            n_invalid = np.sum(rr_ms <= 0)
            raise ValueError(
                f"Record {record_id}: Found {n_invalid} non-positive RR intervals. "
                "This indicates a bug in extraction."
            )
        
        # Check for NaN or Inf
        if np.any(~np.isfinite(rr_ms)):
            raise ValueError(f"Record {record_id}: Found NaN or Inf in RR intervals.")
    
    def get_extraction_summary(self, rr_data: RRIntervalData) -> dict:
        """
        Get summary statistics for extracted RR intervals.
        
        Args:
            rr_data: Extracted RRIntervalData
            
        Returns:
            Dictionary with extraction statistics
        """
        from collections import Counter
        beat_counts = Counter(rr_data.beat_types)
        
        return {
            "record_id": rr_data.record_id,
            "num_intervals": rr_data.num_intervals,
            "duration_minutes": rr_data.duration_seconds / 60,
            "mean_rr_ms": float(np.mean(rr_data.rr_intervals_ms)),
            "std_rr_ms": float(np.std(rr_data.rr_intervals_ms)),
            "min_rr_ms": float(np.min(rr_data.rr_intervals_ms)),
            "max_rr_ms": float(np.max(rr_data.rr_intervals_ms)),
            "mean_hr_bpm": 60000.0 / float(np.mean(rr_data.rr_intervals_ms)),
            "beat_type_counts": dict(beat_counts),
            "pct_normal": sum(beat_counts.get(b, 0) for b in NORMAL_BEATS) / rr_data.num_intervals * 100,
            "pct_ventricular": sum(beat_counts.get(b, 0) for b in VENTRICULAR_BEATS) / rr_data.num_intervals * 100,
        }
