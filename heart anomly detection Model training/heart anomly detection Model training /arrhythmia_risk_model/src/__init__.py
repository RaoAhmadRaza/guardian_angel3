"""
Guardian Angel - Arrhythmia Risk Screening Model

XGBoost-based arrhythmia risk screening using HRV features derived from RR intervals.
Trained on MIT-BIH Arrhythmia Database for mobile health application deployment.

This is a SCREENING tool, not a diagnostic device.
"""

__version__ = "0.1.0"
__author__ = "Guardian Angel Team"

from pathlib import Path

# Project root directory
PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_DIR = PROJECT_ROOT / "config"
DATA_DIR = PROJECT_ROOT / "data"
MODELS_DIR = PROJECT_ROOT / "models"
