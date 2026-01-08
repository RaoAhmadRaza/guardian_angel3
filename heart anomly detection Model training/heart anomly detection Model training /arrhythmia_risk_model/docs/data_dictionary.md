# Data Dictionary - HRV Features for Arrhythmia Risk Screening

## Overview

This document provides detailed descriptions of all features used in the Guardian Angel arrhythmia risk screening model. All features are derived from RR intervals extracted from ECG recordings.

## Data Sources

| Source | Description |
|--------|-------------|
| MIT-BIH Arrhythmia Database | 48 half-hour ECG recordings from 47 subjects |
| Sampling Rate | 360 Hz |
| Annotations | Beat-by-beat rhythm annotations |

## Feature Categories

### 1. Time-Domain Features

| Feature | Unit | Description | Clinical Significance |
|---------|------|-------------|----------------------|
| `mean_rr` | ms | Mean RR interval | Inversely related to heart rate |
| `sdnn` | ms | Standard deviation of NN intervals | Overall HRV, autonomic function |
| `rmssd` | ms | Root mean square of successive differences | Parasympathetic activity |
| `pnn50` | % | % of intervals >50ms difference | Vagal tone marker |
| `pnn20` | % | % of intervals >20ms difference | Short-term variability |
| `mean_hr` | bpm | Mean heart rate | Basic cardiac rhythm |
| `std_hr` | bpm | HR standard deviation | Rate variability |
| `cv_rr` | % | Coefficient of variation | Normalized variability |

### 2. Frequency-Domain Features

| Feature | Unit | Description | Clinical Significance |
|---------|------|-------------|----------------------|
| `vlf_power` | ms² | Very low frequency power (0.003-0.04 Hz) | Long-term regulation |
| `lf_power` | ms² | Low frequency power (0.04-0.15 Hz) | Mixed sympathetic/parasympathetic |
| `hf_power` | ms² | High frequency power (0.15-0.4 Hz) | Parasympathetic, RSA |
| `lf_hf_ratio` | ratio | LF/HF power ratio | Sympathovagal balance |
| `total_power` | ms² | Total spectral power | Overall variability |
| `lf_nu` | n.u. | LF normalized units | Relative LF contribution |
| `hf_nu` | n.u. | HF normalized units | Relative HF contribution |

### 3. Non-Linear Features

| Feature | Unit | Description | Clinical Significance |
|---------|------|-------------|----------------------|
| `sd1` | ms | Poincaré plot SD1 | Short-term variability |
| `sd2` | ms | Poincaré plot SD2 | Long-term variability |
| `sd1_sd2_ratio` | ratio | SD1/SD2 ratio | Variability balance |
| `sample_entropy` | - | Sample entropy | Signal complexity |
| `approximate_entropy` | - | Approximate entropy | Regularity measure |

## Target Variable

| Variable | Type | Description |
|----------|------|-------------|
| `arrhythmia_risk` | Binary | 0 = Normal, 1 = Arrhythmia risk |

## Data Quality Notes

- Minimum 200 beats per 5-minute window required
- Ectopic beats identified and handled per configuration
- RR intervals outside 300-2000ms range excluded
- Windows with >20% missing/invalid beats excluded

## References

1. Task Force of ESC and NASPE. Heart rate variability: standards of measurement. Circulation 1996.
2. Malik M. Heart rate variability. Curr Opin Cardiol 1998.
