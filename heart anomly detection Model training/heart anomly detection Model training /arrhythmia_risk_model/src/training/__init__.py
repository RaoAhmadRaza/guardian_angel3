"""
Training Module - XGBoost Model Training Pipeline

This module handles:
- Patient-wise data splitting (critical for no data leakage)
- XGBoost model training with early stopping
- Class imbalance handling
- Model evaluation and checkpointing
"""

from .splitter import (
    PatientWiseSplitter, 
    PatientSplit, 
    create_patient_wise_split
)
from .trainer import (
    XGBoostTrainer, 
    TrainingConfig, 
    TrainingResults
)

__all__ = [
    "PatientWiseSplitter",
    "PatientSplit",
    "create_patient_wise_split",
    "XGBoostTrainer",
    "TrainingConfig",
    "TrainingResults",
]
