# Arrhythmia Risk Screening Model - Project Report

## Executive Summary

This project implements a **production-ready arrhythmia risk screening system** using XGBoost machine learning on HRV (Heart Rate Variability) features derived from ECG data. The system is designed for **wearable-compatible deployment** and achieved excellent discriminative performance on the MIT-BIH Arrhythmia Database.

### Key Results

| Metric | Value | Clinical Significance |
|--------|-------|----------------------|
| **ROC-AUC** | 0.9653 | Excellent overall discrimination |
| **Recall** | 71.9% | Catches ~72% of at-risk cases |
| **Specificity** | 95.5% | Very low false alarm rate |
| **Accuracy** | 87.5% | Strong overall performance |

---

## Project Scope

### What This System Does
- **Risk Screening**: Identifies individuals with elevated arrhythmia risk patterns
- **Wearable-Compatible**: Uses 60-second windows suitable for smartwatch/fitness band data
- **HRV-Based**: Analyzes heart rate variability patterns, not raw ECG waveforms

### What This System Is NOT
- **Not a Diagnostic Tool**: Does not diagnose specific arrhythmias
- **Not for Emergency Detection**: Not designed for acute cardiac events
- **Requires Clinical Follow-up**: Positive screens need physician review

---

## Technical Architecture

### Data Pipeline
```
MIT-BIH ECG → Beat Annotations → RR Intervals → Windows → HRV Features → XGBoost → Risk Label
```

### Components

1. **Data Loading** (`src/data/loader.py`)
   - Loads MIT-BIH records via WFDB library
   - Excludes paced rhythm records (102, 104, 107, 217)

2. **RR Extraction** (`src/data/rr_extraction.py`)
   - Converts beat annotations to RR intervals
   - Preserves beat type information (N, V, A, etc.)

3. **Preprocessing** (`src/data/preprocessing.py`)
   - Physiological bounds filtering (300-2000ms)
   - 60-second windowing with 30-second overlap
   - Minimum 40 beats per window

4. **Feature Extraction** (`src/features/`)
   - 8 Time-domain features
   - 6 Frequency-domain features (Welch PSD)
   - 1 Nonlinear feature (Sample Entropy)
   - **Total: 15 features**

5. **Labeling** (`src/data/labeling.py`)
   - PVC burden > 5% → Risk
   - Supraventricular ectopy > 10% → Risk
   - Ventricular run (≥3 consecutive) → Risk

6. **Training** (`src/training/`)
   - Patient-wise split (no data leakage)
   - XGBoost with early stopping
   - Class imbalance handling

---

## Feature Set

### Time-Domain Features (8)
| Feature | Description | Clinical Relevance |
|---------|-------------|-------------------|
| mean_rr | Mean RR interval (ms) | Heart rate indicator |
| sdnn | Standard deviation of NN intervals | Overall HRV |
| rmssd | Root mean square of successive differences | Parasympathetic activity |
| pnn50 | % intervals differing >50ms | Vagal tone |
| pnn20 | % intervals differing >20ms | High-frequency variability |
| mean_hr | Mean heart rate (bpm) | Cardiac output |
| std_hr | HR standard deviation | HR variability |
| cv_rr | Coefficient of variation | Normalized variability |

### Frequency-Domain Features (6)
| Feature | Description | Clinical Relevance |
|---------|-------------|-------------------|
| lf_power | Low frequency (0.04-0.15 Hz) | Sympathetic + parasympathetic |
| hf_power | High frequency (0.15-0.4 Hz) | Parasympathetic (respiratory) |
| lf_hf_ratio | LF/HF ratio | Autonomic balance |
| total_power | LF + HF power | Total autonomic activity |
| lf_nu | LF normalized units | Relative sympathetic |
| hf_nu | HF normalized units | Relative parasympathetic |

### Nonlinear Features (1)
| Feature | Description | Clinical Relevance |
|---------|-------------|-------------------|
| sample_entropy | Signal irregularity | Complexity/unpredictability |

---

## Dataset Summary

### MIT-BIH Arrhythmia Database
- **Source**: PhysioNet
- **Records**: 48 total (44 used, 4 paced excluded)
- **Sampling Rate**: 360 Hz
- **Duration**: ~30 minutes per record
- **Total Beats**: ~110,000

### Processed Data
- **Total Windows**: 2,560
- **Risk Windows (Label=1)**: 872 (34.1%)
- **Normal Windows (Label=0)**: 1,688 (65.9%)

### Patient-Wise Split
| Split | Patients | Windows | Risk % |
|-------|----------|---------|--------|
| Train | 30 | 1,736 | 34.3% |
| Validation | 6 | 353 | 32.9% |
| Test | 8 | 471 | 34.0% |

---

## Model Performance

### Test Set Metrics
```
Accuracy:    87.47%
Precision:   89.15%
Recall:      71.88%  ← Primary metric
Specificity: 95.50%
F1 Score:    79.58%
ROC-AUC:     96.53%
```

### Confusion Matrix
```
                 Predicted
                 Normal  Risk
Actual Normal      297    14
Actual Risk         45   115
```

- **True Negatives**: 297 (correctly identified normal)
- **False Positives**: 14 (false alarms)
- **False Negatives**: 45 (missed risk cases)
- **True Positives**: 115 (correctly identified risk)

### Feature Importance (Top 10)
1. **std_hr** (75.55) - Heart rate variability
2. **cv_rr** (29.48) - Coefficient of variation
3. **mean_hr** (15.30) - Average heart rate
4. **rmssd** (11.90) - Successive difference variability
5. **mean_rr** (9.05) - Average interval
6. **hf_power** (7.69) - Parasympathetic power
7. **lf_power** (5.35) - Mixed autonomic power
8. **sdnn** (5.32) - Overall HRV
9. **total_power** (5.28) - Total spectral power
10. **pnn50** (4.25) - Vagal tone indicator

---

## Clinical Interpretation

### Why These Results Matter
1. **High ROC-AUC (0.97)**: The model has excellent ability to distinguish between normal and at-risk patterns across different thresholds.

2. **High Specificity (95.5%)**: Very few false alarms (14 out of 311 normal windows). This is crucial for user trust in wearable applications.

3. **Moderate Recall (71.9%)**: Catches ~72% of at-risk cases. While not perfect, this is appropriate for a **screening** tool where clinical follow-up is expected.

### Trade-offs
- Higher recall would catch more at-risk cases but increase false alarms
- Current balance is appropriate for a screening application
- Threshold can be adjusted based on deployment requirements

---

## File Structure

```
arrhythmia_risk_model/
├── config/
│   ├── config.yaml          # Main configuration
│   └── features.yaml        # Feature definitions
├── src/
│   ├── data/
│   │   ├── loader.py        # MIT-BIH data loading
│   │   ├── rr_extraction.py # RR interval extraction
│   │   ├── preprocessing.py # Windowing and cleaning
│   │   └── labeling.py      # Risk label assignment
│   ├── features/
│   │   ├── time_domain.py   # 8 time-domain features
│   │   ├── frequency_domain.py # 6 frequency features
│   │   ├── nonlinear.py     # Sample entropy
│   │   └── extractor.py     # Unified extraction
│   └── training/
│       ├── splitter.py      # Patient-wise splitting
│       └── trainer.py       # XGBoost training
├── scripts/
│   ├── train_model.py       # Training pipeline
│   └── dry_test_pipeline.py # Validation script
├── tests/
│   ├── test_data.py         # Data pipeline tests
│   ├── test_features.py     # Feature extraction tests
│   └── test_pipeline.py     # Integration tests
├── models/
│   ├── xgboost_arrhythmia_risk.json     # Trained model
│   └── xgboost_arrhythmia_risk_meta.json # Model metadata
└── reports/
    └── training_report.txt  # Detailed training report
```

---

## Usage

### Training
```bash
cd arrhythmia_risk_model
python scripts/train_model.py
```

### Inference (Example)
```python
from src.features import HRVFeatureExtractor
from src.training import XGBoostTrainer

# Extract features from RR intervals
extractor = HRVFeatureExtractor()
features = extractor.extract(rr_intervals_ms)

# Load trained model
trainer = XGBoostTrainer()
trainer.load_model("models/xgboost_arrhythmia_risk")

# Predict
risk_probability = trainer.predict_proba(features.to_array().reshape(1, -1))
```

### Running Tests
```bash
pytest tests/ -v
```

---

## Limitations & Future Work

### Current Limitations
1. **Dataset Size**: MIT-BIH has only 47 patients
2. **Population**: Primarily patients referred for arrhythmia evaluation
3. **Single Window**: No temporal context between windows

### Future Improvements
1. **Larger Datasets**: Train on PTB-XL, INCART, or proprietary data
2. **Deep Learning**: LSTM/Transformer for temporal patterns
3. **Multi-label**: Classify specific arrhythmia types
4. **Real-time**: Optimize for edge device deployment
5. **Cross-validation**: K-fold CV for more robust estimates

---

## Dependencies

```
numpy>=1.24.0
scipy>=1.10.0
wfdb>=4.1.0
xgboost>=1.7.0
scikit-learn>=1.2.0
pytest>=7.0.0
```

---

## References

1. Moody GB, Mark RG. The impact of the MIT-BIH Arrhythmia Database. IEEE Eng Med Biol Mag. 2001;20(3):45-50.
2. Task Force of ESC/NASPE. Heart rate variability: standards of measurement, physiological interpretation, and clinical use. Circulation. 1996;93:1043-1065.
3. Chen T, Guestrin C. XGBoost: A Scalable Tree Boosting System. KDD 2016.

---

## Author & License

Generated as part of the Guardian Angel cardiac monitoring project.

**Report Generated**: 2026-01-03
**Model Version**: v1.0.0
