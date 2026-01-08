#!/usr/bin/env python3
"""
End-to-End Dry Test - Pipeline Validation

This script validates the entire pipeline on a single record BEFORE training.
If this looks wrong, STOP and fix upstream.

Pipeline:
    Record 100 → RR extraction → RR preprocessing → 60s windows → HRV features → Labels

What we check:
    - RR intervals are in milliseconds
    - No negative or zero RR values
    - Beat types align correctly
    - Features fall in physiological ranges
    - Labels make clinical sense

Usage:
    python scripts/dry_test_pipeline.py
    python scripts/dry_test_pipeline.py --record 207  # AF record
"""

import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import argparse
import numpy as np
from collections import Counter

from src.data.loader import MITBIHLoader, PACED_RECORDS
from src.data.rr_extraction import RRIntervalExtractor, NORMAL_BEATS, VENTRICULAR_BEATS
from src.data.preprocessing import RRPreprocessor
from src.features.time_domain import TimeDomainExtractor


def print_header(text: str) -> None:
    """Print a formatted header."""
    print("\n" + "=" * 70)
    print(f"  {text}")
    print("=" * 70)


def print_section(text: str) -> None:
    """Print a section divider."""
    print(f"\n--- {text} ---")


def assign_window_label(window) -> tuple:
    """
    Assign label to a window based on beat composition.
    
    Returns:
        (label, label_name, reason)
        label: 0 = normal, 1 = abnormal/at-risk
    """
    # High ventricular ectopy → abnormal
    if window.pct_ventricular > 10:
        return 1, "ABNORMAL", f"High PVC burden ({window.pct_ventricular:.1f}%)"
    
    # High supraventricular ectopy → abnormal
    if window.pct_supraventricular > 10:
        return 1, "ABNORMAL", f"High supraventricular ectopy ({window.pct_supraventricular:.1f}%)"
    
    # Low normal beat percentage → abnormal
    if window.pct_normal < 80:
        return 1, "ABNORMAL", f"Low normal beat % ({window.pct_normal:.1f}%)"
    
    # Otherwise → normal
    return 0, "NORMAL", "Predominantly normal beats"


def run_dry_test(record_id: str, data_dir: Path, verbose: bool = True):
    """
    Run end-to-end pipeline test on a single record.
    """
    print_header(f"DRY TEST: Record {record_id}")
    
    if record_id in PACED_RECORDS:
        print(f"⚠️  WARNING: Record {record_id} is a paced record (artificial rhythm)")
    
    # =========================================================================
    # STEP 1: Load Record
    # =========================================================================
    print_section("STEP 1: Loading Record")
    
    loader = MITBIHLoader(data_dir)
    record = loader.load_record(record_id)
    
    summary = loader.get_record_summary(record)
    print(f"  Record ID:        {record_id}")
    print(f"  Duration:         {summary['duration_min']:.1f} minutes")
    print(f"  Total beats:      {summary['num_beats']}")
    print(f"  Sampling freq:    {summary['sampling_frequency']} Hz")
    print(f"  Beat types:       {summary['beat_type_counts']}")
    
    # =========================================================================
    # STEP 2: Extract RR Intervals
    # =========================================================================
    print_section("STEP 2: RR Interval Extraction")
    
    extractor = RRIntervalExtractor(sampling_frequency=record.sampling_frequency)
    rr_data = extractor.extract(record)
    
    rr_summary = extractor.get_extraction_summary(rr_data)
    print(f"  Number of RR intervals: {rr_summary['num_intervals']}")
    print(f"  Duration covered:       {rr_summary['duration_minutes']:.1f} minutes")
    print(f"  Mean RR:                {rr_summary['mean_rr_ms']:.1f} ms")
    print(f"  Std RR:                 {rr_summary['std_rr_ms']:.1f} ms")
    print(f"  Min RR:                 {rr_summary['min_rr_ms']:.1f} ms")
    print(f"  Max RR:                 {rr_summary['max_rr_ms']:.1f} ms")
    print(f"  Mean HR:                {rr_summary['mean_hr_bpm']:.1f} BPM")
    print(f"  % Normal beats:         {rr_summary['pct_normal']:.1f}%")
    print(f"  % Ventricular beats:    {rr_summary['pct_ventricular']:.1f}%")
    
    # Validation checks
    print("\n  ✓ Validations:")
    assert np.all(rr_data.rr_intervals_ms > 0), "Found non-positive RR intervals!"
    print("    - All RR intervals > 0 ms ✓")
    
    assert len(rr_data.beat_types) == len(rr_data.rr_intervals_ms), "Beat type alignment error!"
    print("    - Beat types align with RR intervals ✓")
    
    assert np.all(np.isfinite(rr_data.rr_intervals_ms)), "Found NaN/Inf in RR!"
    print("    - No NaN or Inf values ✓")
    
    # =========================================================================
    # STEP 3: Preprocess into Windows
    # =========================================================================
    print_section("STEP 3: RR Preprocessing & Windowing")
    
    preprocessor = RRPreprocessor(
        min_rr_ms=300.0,
        max_rr_ms=2000.0,
        window_size_sec=60.0,
        window_step_sec=30.0,
        min_beats_per_window=40
    )
    
    windows, stats = preprocessor.process_record(rr_data)
    
    print(f"  Total intervals:       {stats.total_intervals}")
    print(f"  Removed (too short):   {stats.removed_too_short} (<300ms)")
    print(f"  Removed (too long):    {stats.removed_too_long} (>2000ms)")
    print(f"  % Removed:             {stats.pct_removed:.2f}%")
    print(f"  Total windows:         {stats.total_windows}")
    print(f"  Valid windows:         {stats.valid_windows}")
    print(f"  Invalid windows:       {stats.invalid_windows}")
    
    if stats.valid_windows == 0:
        print("\n⛔ ERROR: No valid windows! Cannot continue.")
        return False
    
    # =========================================================================
    # STEP 4: Extract Features & Assign Labels
    # =========================================================================
    print_section("STEP 4: Time-Domain HRV Features")
    
    feature_extractor = TimeDomainExtractor(min_intervals=10)
    
    # Process only valid windows
    valid_windows = [w for w in windows if w.is_valid]
    
    # Show first 5 windows in detail
    n_show = min(5, len(valid_windows))
    print(f"\n  Showing first {n_show} windows:\n")
    
    all_features = []
    all_labels = []
    
    for i, window in enumerate(valid_windows[:n_show]):
        features = feature_extractor.extract(window.rr_intervals_ms)
        label, label_name, reason = assign_window_label(window)
        
        all_features.append(features)
        all_labels.append(label)
        
        print(f"  Window {window.window_index}:")
        print(f"    Duration:     {window.duration_sec:.1f}s")
        print(f"    Beats:        {window.num_intervals}")
        print(f"    Beat mix:     {window.pct_normal:.0f}% N, {window.pct_ventricular:.0f}% V, {window.pct_supraventricular:.0f}% S")
        print(f"    ---")
        print(f"    mean_rr:      {features.mean_rr:.1f} ms")
        print(f"    mean_hr:      {features.mean_hr:.1f} BPM")
        print(f"    sdnn:         {features.sdnn:.1f} ms")
        print(f"    rmssd:        {features.rmssd:.1f} ms")
        print(f"    pnn50:        {features.pnn50:.1f}%")
        print(f"    pnn20:        {features.pnn20:.1f}%")
        print(f"    std_hr:       {features.std_hr:.1f} BPM")
        print(f"    cv_rr:        {features.cv_rr:.1f}%")
        print(f"    ---")
        print(f"    Label:        {label} ({label_name})")
        print(f"    Reason:       {reason}")
        print()
    
    # Process all remaining windows
    for window in valid_windows[n_show:]:
        features = feature_extractor.extract(window.rr_intervals_ms)
        label, _, _ = assign_window_label(window)
        all_features.append(features)
        all_labels.append(label)
    
    # =========================================================================
    # STEP 5: Summary Statistics
    # =========================================================================
    print_section("STEP 5: Summary Statistics")
    
    # Label distribution
    label_counts = Counter(all_labels)
    print(f"\n  Label distribution:")
    print(f"    Normal (0):    {label_counts[0]} windows ({label_counts[0]/len(all_labels)*100:.1f}%)")
    print(f"    Abnormal (1):  {label_counts[1]} windows ({label_counts[1]/len(all_labels)*100:.1f}%)")
    
    # Feature statistics (only valid features)
    valid_features = [f for f in all_features if f.is_valid]
    if valid_features:
        print(f"\n  Feature ranges across {len(valid_features)} valid windows:")
        
        for fname in TimeDomainExtractor.FEATURE_NAMES:
            values = [getattr(f, fname) for f in valid_features]
            print(f"    {fname:10s}: min={min(values):8.1f}, max={max(values):8.1f}, mean={np.mean(values):8.1f}")
    
    # =========================================================================
    # Final Validation
    # =========================================================================
    print_section("FINAL VALIDATION")
    
    all_passed = True
    
    # Check no NaN in features
    for f in valid_features:
        if not f.is_valid:
            print("  ⛔ Found invalid feature set")
            all_passed = False
            break
        arr = f.to_array()
        if np.any(~np.isfinite(arr)):
            print("  ⛔ Found NaN/Inf in features")
            all_passed = False
            break
    else:
        print("  ✓ All features are finite")
    
    # Check physiological ranges
    for f in valid_features:
        if f.mean_hr < 20 or f.mean_hr > 250:
            print(f"  ⛔ Implausible mean HR: {f.mean_hr}")
            all_passed = False
            break
        # Note: RMSSD can be very high (>500ms) in severe arrhythmia - that's the signal!
        if f.rmssd < 0 or f.rmssd > 1000:
            print(f"  ⛔ Implausible RMSSD: {f.rmssd}")
            all_passed = False
            break
    else:
        print("  ✓ Features in physiological range")
    
    # Check we have both labels
    if len(label_counts) == 2:
        print("  ✓ Both labels present in data")
    else:
        print(f"  ⚠️ Only one label present: {list(label_counts.keys())}")
    
    if all_passed:
        print_header("✓ DRY TEST PASSED - Pipeline working correctly")
    else:
        print_header("⛔ DRY TEST FAILED - Fix issues before training")
    
    return all_passed


def main():
    parser = argparse.ArgumentParser(
        description="End-to-end pipeline dry test"
    )
    parser.add_argument(
        "--record", "-r",
        type=str,
        default="100",
        help="MIT-BIH record ID to test (default: 100)"
    )
    parser.add_argument(
        "--data-dir", "-d",
        type=str,
        default=None,
        help="Path to MIT-BIH data directory"
    )
    
    args = parser.parse_args()
    
    # Find data directory
    if args.data_dir:
        data_dir = Path(args.data_dir)
    else:
        # Try common locations
        possible_paths = [
            PROJECT_ROOT / "dataset" / "mit-bih-arrhythmia-database-1.0.0",
            PROJECT_ROOT / "data" / "raw" / "mitdb",
        ]
        data_dir = None
        for p in possible_paths:
            if p.exists():
                data_dir = p
                break
        
        if data_dir is None:
            print("ERROR: Could not find MIT-BIH data directory.")
            print("Please specify with --data-dir or run download_data.py first.")
            sys.exit(1)
    
    print(f"Using data directory: {data_dir}")
    
    # Run test
    success = run_dry_test(args.record, data_dir)
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
