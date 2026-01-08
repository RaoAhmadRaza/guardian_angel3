"""
Evaluation Module - Model Performance Assessment

This module handles:
- Classification metrics (accuracy, precision, recall, F1, AUC)
- Confusion matrix analysis
- Calibration assessment
- Feature importance analysis
- Evaluation report generation
"""

from .metrics import MetricsCalculator
from .calibration import CalibrationAnalyzer
from .importance import FeatureImportanceAnalyzer
from .reporter import EvaluationReporter

__all__ = [
    "MetricsCalculator",
    "CalibrationAnalyzer",
    "FeatureImportanceAnalyzer",
    "EvaluationReporter",
]
