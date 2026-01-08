"""
RR Interval Preprocessing

Cleans RR intervals to match wearable reality and prevent garbage features.

Key principles:
1. Physiological bounds: Remove impossible RR values (< 300ms, > 2000ms)
2. NO interpolation: Ectopic beats ARE the signal, not noise
3. Window validity: Discard windows with insufficient data

What we DO:
- Flag physiologically impossible values
- Track ectopic beat percentages
- Validate window quality

What we DON'T do:
- Interpolate ectopic beats (they're the arrhythmia signal!)
- Smooth the data (destroys HRV information)
"""

from dataclasses import dataclass, field
from typing import List, Tuple, Optional
import numpy as np

from .rr_extraction import (
    RRIntervalData, 
    NORMAL_BEATS, 
    VENTRICULAR_BEATS, 
    SUPRAVENTRICULAR_BEATS
)


@dataclass
class RRWindow:
    """
    A single time window of RR intervals ready for feature extraction.
    """
    record_id: str
    window_index: int
    rr_intervals_ms: np.ndarray      # Clean RR intervals
    beat_types: List[str]            # Beat types for each interval
    start_sample: int                # Sample index where window starts
    end_sample: int                  # Sample index where window ends
    
    # Quality metrics
    duration_sec: float              # Actual duration of window
    num_intervals: int               # Number of RR intervals
    num_removed: int                 # Intervals removed (out of bounds)
    pct_normal: float                # % normal beats
    pct_ventricular: float           # % ventricular ectopic
    pct_supraventricular: float      # % supraventricular ectopic
    is_valid: bool                   # Meets minimum quality criteria
    invalid_reason: Optional[str] = None


@dataclass
class PreprocessingStats:
    """Statistics from preprocessing a full record."""
    record_id: str
    total_intervals: int
    removed_too_short: int           # RR < min_rr_ms
    removed_too_long: int            # RR > max_rr_ms
    total_windows: int
    valid_windows: int
    invalid_windows: int
    
    @property
    def pct_removed(self) -> float:
        if self.total_intervals == 0:
            return 0.0
        return (self.removed_too_short + self.removed_too_long) / self.total_intervals * 100


class RRPreprocessor:
    """
    Preprocesses RR intervals for HRV feature extraction.
    
    This class:
    1. Removes physiologically impossible RR values
    2. Segments into fixed-duration windows
    3. Validates window quality
    4. Tracks ectopic beat composition (but does NOT remove them)
    """
    
    def __init__(
        self,
        min_rr_ms: float = 300.0,      # 200 bpm max
        max_rr_ms: float = 2000.0,     # 30 bpm min
        window_size_sec: float = 60.0,  # 60-second windows
        window_step_sec: float = 30.0,  # 30-second overlap
        min_beats_per_window: int = 40  # Minimum for valid window
    ):
        """
        Initialize preprocessor with quality thresholds.
        
        Args:
            min_rr_ms: Minimum physiologically plausible RR (ms)
            max_rr_ms: Maximum physiologically plausible RR (ms)
            window_size_sec: Window duration in seconds
            window_step_sec: Step between windows (overlap = window_size - step)
            min_beats_per_window: Minimum beats for a valid window
        """
        self.min_rr_ms = min_rr_ms
        self.max_rr_ms = max_rr_ms
        self.window_size_sec = window_size_sec
        self.window_step_sec = window_step_sec
        self.min_beats_per_window = min_beats_per_window
    
    def process_record(
        self, 
        rr_data: RRIntervalData
    ) -> Tuple[List[RRWindow], PreprocessingStats]:
        """
        Process a full record into clean windows.
        
        Args:
            rr_data: Raw extracted RR intervals
            
        Returns:
            Tuple of (list of RRWindows, PreprocessingStats)
        """
        # Step 1: Apply physiological bounds
        clean_rr, clean_types, clean_samples, stats = self._apply_bounds(rr_data)
        
        # Step 2: Segment into windows
        windows = self._segment_into_windows(
            clean_rr, clean_types, clean_samples, rr_data
        )
        
        # Update stats with window counts
        stats.total_windows = len(windows)
        stats.valid_windows = sum(1 for w in windows if w.is_valid)
        stats.invalid_windows = stats.total_windows - stats.valid_windows
        
        return windows, stats
    
    def _apply_bounds(
        self, 
        rr_data: RRIntervalData
    ) -> Tuple[np.ndarray, List[str], np.ndarray, PreprocessingStats]:
        """
        Remove physiologically impossible RR intervals.
        
        Returns:
            Tuple of (clean_rr, clean_beat_types, clean_sample_indices, stats)
        """
        rr = rr_data.rr_intervals_ms
        
        # Find valid intervals
        too_short = rr < self.min_rr_ms
        too_long = rr > self.max_rr_ms
        valid_mask = ~(too_short | too_long)
        
        # Apply mask
        clean_rr = rr[valid_mask]
        clean_types = [rr_data.beat_types[i] for i in np.where(valid_mask)[0]]
        clean_samples = rr_data.sample_indices[valid_mask]
        
        # Track statistics
        stats = PreprocessingStats(
            record_id=rr_data.record_id,
            total_intervals=len(rr),
            removed_too_short=int(np.sum(too_short)),
            removed_too_long=int(np.sum(too_long)),
            total_windows=0,
            valid_windows=0,
            invalid_windows=0
        )
        
        return clean_rr, clean_types, clean_samples, stats
    
    def _segment_into_windows(
        self,
        rr_ms: np.ndarray,
        beat_types: List[str],
        sample_indices: np.ndarray,
        original_data: RRIntervalData
    ) -> List[RRWindow]:
        """
        Segment RR intervals into fixed-duration windows.
        
        Windows are based on cumulative time, not fixed beat counts.
        This matches how wearables operate.
        """
        if len(rr_ms) == 0:
            return []
        
        # Convert to seconds for windowing
        window_size_ms = self.window_size_sec * 1000
        window_step_ms = self.window_step_sec * 1000
        
        # Cumulative time from start
        cumsum_ms = np.cumsum(rr_ms)
        total_duration_ms = cumsum_ms[-1]
        
        windows = []
        window_idx = 0
        window_start_ms = 0.0
        
        while window_start_ms + window_size_ms <= total_duration_ms:
            window_end_ms = window_start_ms + window_size_ms
            
            # Find indices within this time window
            # Include interval if its START time is within the window
            if window_start_ms == 0:
                start_idx = 0
            else:
                start_idx = np.searchsorted(cumsum_ms, window_start_ms, side='right')
            
            end_idx = np.searchsorted(cumsum_ms, window_end_ms, side='right')
            
            # Extract window data
            window_rr = rr_ms[start_idx:end_idx]
            window_types = beat_types[start_idx:end_idx]
            
            # Get sample indices for traceability
            if len(sample_indices) > 0 and start_idx < len(sample_indices):
                start_sample = int(sample_indices[start_idx])
                end_sample = int(sample_indices[min(end_idx, len(sample_indices)-1)])
            else:
                start_sample = 0
                end_sample = 0
            
            # Calculate beat type percentages
            n_beats = len(window_types)
            if n_beats > 0:
                pct_normal = sum(1 for b in window_types if b in NORMAL_BEATS) / n_beats * 100
                pct_vent = sum(1 for b in window_types if b in VENTRICULAR_BEATS) / n_beats * 100
                pct_supra = sum(1 for b in window_types if b in SUPRAVENTRICULAR_BEATS) / n_beats * 100
            else:
                pct_normal = pct_vent = pct_supra = 0.0
            
            # Validate window
            is_valid, invalid_reason = self._validate_window(window_rr, n_beats)
            
            windows.append(RRWindow(
                record_id=original_data.record_id,
                window_index=window_idx,
                rr_intervals_ms=window_rr,
                beat_types=window_types,
                start_sample=start_sample,
                end_sample=end_sample,
                duration_sec=float(np.sum(window_rr)) / 1000.0,
                num_intervals=n_beats,
                num_removed=0,  # Already removed in bounds step
                pct_normal=pct_normal,
                pct_ventricular=pct_vent,
                pct_supraventricular=pct_supra,
                is_valid=is_valid,
                invalid_reason=invalid_reason
            ))
            
            window_idx += 1
            window_start_ms += window_step_ms
        
        return windows
    
    def _validate_window(
        self, 
        rr_ms: np.ndarray, 
        n_beats: int
    ) -> Tuple[bool, Optional[str]]:
        """
        Check if a window meets quality criteria.
        
        Returns:
            Tuple of (is_valid, reason_if_invalid)
        """
        # Check minimum beats
        if n_beats < self.min_beats_per_window:
            return False, f"Insufficient beats: {n_beats} < {self.min_beats_per_window}"
        
        # Check that we have enough data
        if len(rr_ms) == 0:
            return False, "No RR intervals in window"
        
        # Check for any remaining invalid values (shouldn't happen after bounds)
        if np.any(~np.isfinite(rr_ms)):
            return False, "Contains NaN or Inf values"
        
        return True, None
    
    def get_window_summary(self, window: RRWindow) -> dict:
        """Get human-readable summary of a window."""
        return {
            "record_id": window.record_id,
            "window_index": window.window_index,
            "duration_sec": round(window.duration_sec, 1),
            "num_beats": window.num_intervals,
            "is_valid": window.is_valid,
            "invalid_reason": window.invalid_reason,
            "pct_normal": round(window.pct_normal, 1),
            "pct_ventricular": round(window.pct_ventricular, 1),
            "pct_supraventricular": round(window.pct_supraventricular, 1),
            "mean_hr_bpm": round(60000.0 / np.mean(window.rr_intervals_ms), 1) if len(window.rr_intervals_ms) > 0 else 0
        }
