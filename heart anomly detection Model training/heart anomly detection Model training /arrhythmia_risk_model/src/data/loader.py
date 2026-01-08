"""
MIT-BIH Arrhythmia Database Loader

Handles loading records from the MIT-BIH Arrhythmia Database.
Records contain ECG signals and expert-annotated beat positions.
"""

from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple
from dataclasses import dataclass

import wfdb
import numpy as np


# MIT-BIH record IDs (48 records, 47 patients - records 201 & 202 are same patient)
MITBIH_RECORD_IDS = [
    "100", "101", "102", "103", "104", "105", "106", "107", "108", "109",
    "111", "112", "113", "114", "115", "116", "117", "118", "119", "121",
    "122", "123", "124", "200", "201", "202", "203", "205", "207", "208",
    "209", "210", "212", "213", "214", "215", "217", "219", "220", "221",
    "222", "223", "228", "230", "231", "232", "233", "234"
]

# Records with pacemaker - exclude for HRV analysis (artificial rhythm)
PACED_RECORDS = ["102", "104", "107", "217"]


@dataclass
class MITBIHRecord:
    """Container for a loaded MIT-BIH record."""
    record_id: str
    signal: np.ndarray          # ECG signal (not used for RR, but available)
    annotation_samples: np.ndarray  # Sample indices of annotated beats
    annotation_symbols: List[str]   # Beat type symbols (N, V, A, etc.)
    sampling_frequency: float   # Hz (360 for MIT-BIH)
    record_length_samples: int  # Total samples in record
    
    @property
    def duration_seconds(self) -> float:
        """Total record duration in seconds."""
        return self.record_length_samples / self.sampling_frequency
    
    @property
    def num_beats(self) -> int:
        """Number of annotated beats."""
        return len(self.annotation_samples)


class MITBIHLoader:
    """
    Loads MIT-BIH Arrhythmia Database records.
    
    This loader extracts:
    - Beat annotation timestamps (sample indices)
    - Beat type symbols for each annotation
    - Sampling frequency for time conversion
    
    We do NOT use the ECG waveform - only the expert-annotated beat times.
    """
    
    def __init__(self, data_dir: str | Path):
        """
        Initialize loader with path to MIT-BIH data.
        
        Args:
            data_dir: Directory containing MIT-BIH .dat/.hea/.atr files
        """
        self.data_dir = Path(data_dir)
        if not self.data_dir.exists():
            raise FileNotFoundError(f"Data directory not found: {self.data_dir}")
    
    def load_record(self, record_id: str) -> MITBIHRecord:
        """
        Load a single MIT-BIH record with annotations.
        
        Args:
            record_id: Record identifier (e.g., "100", "101")
            
        Returns:
            MITBIHRecord with signal, annotations, and metadata
        """
        record_path = self.data_dir / record_id
        
        # Load the record (ECG signal + header)
        record = wfdb.rdrecord(str(record_path))
        
        # Load annotations (beat positions + types)
        annotation = wfdb.rdann(str(record_path), 'atr')
        
        return MITBIHRecord(
            record_id=record_id,
            signal=record.p_signal[:, 0],  # First channel (MLII typically)
            annotation_samples=annotation.sample,
            annotation_symbols=annotation.symbol,
            sampling_frequency=float(record.fs),
            record_length_samples=record.sig_len
        )
    
    def load_all_records(
        self, 
        exclude_paced: bool = True,
        record_ids: Optional[List[str]] = None
    ) -> Dict[str, MITBIHRecord]:
        """
        Load multiple MIT-BIH records.
        
        Args:
            exclude_paced: If True, skip pacemaker records (default: True)
            record_ids: Specific records to load, or None for all
            
        Returns:
            Dictionary mapping record_id -> MITBIHRecord
        """
        if record_ids is None:
            record_ids = MITBIH_RECORD_IDS
        
        if exclude_paced:
            record_ids = [r for r in record_ids if r not in PACED_RECORDS]
        
        records = {}
        for record_id in record_ids:
            try:
                records[record_id] = self.load_record(record_id)
            except Exception as e:
                print(f"Warning: Failed to load record {record_id}: {e}")
        
        return records
    
    def get_record_summary(self, record: MITBIHRecord) -> Dict[str, Any]:
        """
        Get summary statistics for a record.
        
        Args:
            record: Loaded MITBIHRecord
            
        Returns:
            Dictionary with record statistics
        """
        from collections import Counter
        beat_counts = Counter(record.annotation_symbols)
        
        return {
            "record_id": record.record_id,
            "duration_min": record.duration_seconds / 60,
            "num_beats": record.num_beats,
            "sampling_frequency": record.sampling_frequency,
            "beat_type_counts": dict(beat_counts),
            "is_paced": record.record_id in PACED_RECORDS
        }
    
    @staticmethod
    def get_available_records(exclude_paced: bool = True) -> List[str]:
        """Get list of available MIT-BIH record IDs."""
        records = MITBIH_RECORD_IDS.copy()
        if exclude_paced:
            records = [r for r in records if r not in PACED_RECORDS]
        return records
