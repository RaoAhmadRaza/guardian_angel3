"""
Data Module - MIT-BIH Data Loading and RR Interval Processing

This module handles:
- MIT-BIH Arrhythmia Database access via wfdb
- RR interval extraction from ECG annotations
- Data cleaning and artifact removal
- Window labeling for arrhythmia risk
- Patient-wise data organization
"""

from .loader import MITBIHLoader, MITBIHRecord, MITBIH_RECORD_IDS, PACED_RECORDS
from .rr_extraction import (
    RRIntervalExtractor, 
    RRIntervalData,
    NORMAL_BEATS,
    VENTRICULAR_BEATS,
    SUPRAVENTRICULAR_BEATS
)
from .preprocessing import RRPreprocessor, RRWindow, PreprocessingStats
from .labeling import (
    WindowLabeler,
    WindowLabel,
    LabelingConfig,
    create_training_dataset,
)

__all__ = [
    "MITBIHLoader",
    "MITBIHRecord",
    "MITBIH_RECORD_IDS",
    "PACED_RECORDS",
    "RRIntervalExtractor",
    "RRIntervalData",
    "NORMAL_BEATS",
    "VENTRICULAR_BEATS",
    "SUPRAVENTRICULAR_BEATS",
    "RRPreprocessor",
    "RRWindow",
    "PreprocessingStats",
    "WindowLabeler",
    "WindowLabel",
    "LabelingConfig",
    "create_training_dataset",
]
