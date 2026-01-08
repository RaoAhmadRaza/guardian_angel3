# Guardian Angel - Arrhythmia Risk Screening Model

[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

This module implements an **XGBoost-based arrhythmia risk screening model** designed for integration into the Guardian Angel mobile health application. The model uses Heart Rate Variability (HRV) features derived from RR intervals to assess arrhythmia risk.

> ⚠️ **Important**: This is a **screening tool**, not a diagnostic device. Results should be interpreted by qualified healthcare professionals.

## Project Purpose

- **Goal**: Early-stage arrhythmia risk stratification using wearable-derived RR intervals
- **Method**: Classical ML (XGBoost) with interpretable HRV features
- **Dataset**: MIT-BIH Arrhythmia Database
- **Deployment Target**: Mobile health application (iOS/Android)

## Design Philosophy

| Principle | Implementation |
|-----------|----------------|
| Interpretability | HRV features with clinical meaning |
| Reproducibility | Fixed random seeds, version-locked dependencies |
| Safety | Patient-wise splits, no data leakage |
| Auditability | Logged experiments, clear pipelines |
| Portability | No GPU dependency, lightweight model |

## Project Structure

```
arrhythmia_risk_model/
├── config/                 # Configuration files
│   ├── config.yaml         # Main configuration
│   └── features.yaml       # Feature definitions
├── data/
│   ├── raw/                # Original MIT-BIH records
│   ├── processed/          # Processed RR intervals
│   └── features/           # Extracted HRV features
├── docs/                   # Documentation
│   ├── data_dictionary.md  # Feature descriptions
│   └── model_card.md       # Model documentation
├── models/
│   ├── checkpoints/        # Training checkpoints
│   └── exported/           # Deployment-ready models
├── notebooks/              # Exploratory analysis only
├── src/
│   ├── data/               # Data loading & processing
│   ├── features/           # HRV feature extraction
│   ├── training/           # Model training pipeline
│   ├── evaluation/         # Metrics & validation
│   └── export/             # Model export utilities
├── tests/                  # Unit & integration tests
├── utils/                  # Shared utilities
├── scripts/                # CLI entry points
├── requirements.txt        # Python dependencies
├── setup.py                # Package installation
└── README.md               # This file
```

## Quick Start

### 1. Environment Setup

```bash
# Create virtual environment
python3.10 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Verify installation
python -c "import xgboost; import wfdb; print('✅ Environment ready')"
```

### 2. Download MIT-BIH Dataset

```bash
# Dataset will be downloaded to data/raw/
python scripts/download_data.py
```

### 3. Pipeline Execution

```bash
# Step 1: Extract RR intervals
python scripts/extract_rr_intervals.py

# Step 2: Compute HRV features
python scripts/compute_features.py

# Step 3: Train model
python scripts/train_model.py

# Step 4: Evaluate model
python scripts/evaluate_model.py

# Step 5: Export for deployment
python scripts/export_model.py
```

## Data Flow

```
MIT-BIH Records (.dat, .hea, .atr)
        │
        ▼
    [RR Interval Extraction]
        │
        ▼
    Processed RR Intervals (.csv)
        │
        ▼
    [HRV Feature Extraction]
        │
        ▼
    Feature Matrix (.parquet)
        │
        ▼
    [XGBoost Training]
        │
        ▼
    Trained Model (.json, .pkl)
        │
        ▼
    [Export for Mobile]
        │
        ▼
    Deployment Artifact
```

## HRV Features (Planned)

### Time-Domain
- SDNN, RMSSD, pNN50, Mean RR, HR

### Frequency-Domain
- LF Power, HF Power, LF/HF Ratio, VLF Power

### Non-Linear
- SD1, SD2 (Poincaré), Sample Entropy, Approximate Entropy

## Requirements

- Python 3.10+
- macOS (Apple Silicon compatible) / Linux
- No GPU required
- ~2GB disk space for dataset

## Reproducibility

All experiments use:
- Fixed random seed: `42`
- Patient-wise stratified splits
- Version-locked dependencies
- Logged hyperparameters

## License

MIT License - See LICENSE file for details.

## Disclaimer

This software is intended for research and screening purposes only. It is **NOT** a medical device and should **NOT** be used for clinical diagnosis. Always consult qualified healthcare professionals for medical decisions.

---

**Guardian Angel Project** | Digital Health & Wearable Analytics
