# MIT-BIH Arrhythmia Database - Comprehensive Analysis Report

## Executive Summary

The MIT-BIH Arrhythmia Database is one of the most widely used benchmark datasets for evaluating arrhythmia detection algorithms. This report provides a detailed analysis of your local copy for use in the **Guardian Angel** arrhythmia risk screening project.

---

## 1. Dataset Overview

| Property | Value |
|----------|-------|
| **Database Name** | MIT-BIH Arrhythmia Database |
| **Version** | 1.0.0 |
| **Source** | PhysioNet / Beth Israel Hospital |
| **Total Records** | 48 |
| **Total Subjects** | 47 (Records 201 & 202 are from same subject) |
| **Recording Duration** | ~30 minutes per record |
| **Total Duration** | ~24 hours of ECG data |
| **Disk Space** | 107 MB |
| **Sampling Frequency** | 360 Hz |
| **Resolution** | 11-bit (over ±5 mV range) |

---

## 2. File Structure

### 2.1 File Types

| Extension | Count | Description |
|-----------|-------|-------------|
| `.dat` | 48 | Binary signal data (2-channel ECG waveforms) |
| `.hea` | 48 | Header files (metadata, patient info, signal specs) |
| `.atr` | 49 | Annotation files (beat labels, rhythm annotations) |
| `.xws` | 48 | Waveform display settings |

### 2.2 Record Numbers

**Group 1 (100-series): Random Sample** - 23 records
```
100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 
111, 112, 113, 114, 115, 116, 117, 118, 119, 
121, 122, 123, 124
```

**Group 2 (200-series): Clinically Significant Cases** - 25 records
```
200, 201, 202, 203, 205, 207, 208, 209, 210, 
212, 213, 214, 215, 217, 219, 220, 221, 222, 
223, 228, 230, 231, 232, 233, 234
```

> **Note**: The 100-series represents routine clinical ECGs, while the 200-series was specifically selected to include rare but clinically important arrhythmias.

---

## 3. Signal Characteristics

### 3.1 ECG Lead Configuration

| Channel | Primary Lead | Description |
|---------|--------------|-------------|
| Upper (Ch 1) | Modified Lead II (MLII) | Best for normal QRS detection |
| Lower (Ch 2) | Modified V1/V2/V5 | Better for ectopic beat detection |

**Exceptions:**
- Record **114**: Signals reversed
- Records **102, 104**: Modified V5 used for upper signal (surgical dressings)

### 3.2 Technical Specifications

```
Sampling Rate:     360 Hz (samples per second per channel)
ADC Resolution:    11-bit (values 0-2047, 1024 = 0 mV)
Voltage Range:     ±5 mV
Bandpass Filter:   0.1 - 100 Hz
Total Samples:     650,000 per channel (~30 min at 360 Hz)
Storage Format:    212 format (12-bit pairs packed in 3 bytes)
```

---

## 4. Patient Demographics

### 4.1 Gender Distribution

| Gender | Count | Percentage |
|--------|-------|------------|
| Male | 25 | 53.2% |
| Female | 22 | 46.8% |

### 4.2 Age Distribution

| Statistic | Value |
|-----------|-------|
| **Male Age Range** | 32 - 89 years |
| **Female Age Range** | 23 - 89 years |
| **Overall Range** | 23 - 89 years |

### 4.3 Pacemaker Records

Records with paced beats: **102, 104, 107, 217**

---

## 5. Annotation System

### 5.1 Beat Annotation Codes

| Symbol | AHA Code | Description | Clinical Significance |
|--------|----------|-------------|----------------------|
| `.` or `N` | N | Normal beat | Sinus rhythm |
| `L` | N | Left bundle branch block beat | Conduction abnormality |
| `R` | N | Right bundle branch block beat | Conduction abnormality |
| `A` | N | Atrial premature beat | Supraventricular ectopy |
| `a` | N | Aberrated atrial premature beat | Supraventricular ectopy |
| `J` | N | Nodal (junctional) premature beat | Junctional ectopy |
| `S` | N | Supraventricular premature beat | Supraventricular ectopy |
| `V` | V | Premature ventricular contraction (PVC) | **Ventricular ectopy** |
| `F` | F | Fusion of ventricular and normal beat | Mixed origin |
| `!` | O | Ventricular flutter wave | **Life-threatening** |
| `e` | N | Atrial escape beat | Escape rhythm |
| `j` | N | Nodal (junctional) escape beat | Escape rhythm |
| `E` | E | Ventricular escape beat | **Ventricular escape** |
| `P` | P | Paced beat | Artificial pacing |
| `f` | F | Fusion of paced and normal beat | Pacemaker fusion |
| `p` | O | Non-conducted P-wave | AV block |
| `Q` | Q | Unclassifiable beat | Artifact/unclear |

### 5.2 Rhythm Annotation Codes

| Code | Rhythm Type | Clinical Significance |
|------|-------------|----------------------|
| `N` | Normal sinus rhythm | Baseline normal |
| `SBR` | Sinus bradycardia | Slow heart rate |
| `BII` | 2nd degree heart block | Conduction abnormality |
| `PREX` | Pre-excitation (WPW) | Accessory pathway |
| `AB` | Atrial bigeminy | Supraventricular pattern |
| `SVTA` | Supraventricular tachyarrhythmia | Fast atrial rhythm |
| `AFL` | Atrial flutter | **Significant arrhythmia** |
| `AFIB` | Atrial fibrillation | **Significant arrhythmia** |
| `P` | Paced rhythm | Artificial pacing |
| `NOD` | Nodal/junctional rhythm | AV nodal origin |
| `B` | Ventricular bigeminy | PVC every other beat |
| `T` | Ventricular trigeminy | PVC every third beat |
| `IVR` | Idioventricular rhythm | **Ventricular escape** |
| `VT` | Ventricular tachycardia | **Life-threatening** |
| `VFL` | Ventricular flutter | **Life-threatening** |

---

## 6. Beat Type Distribution (Entire Database)

### 6.1 Summary Statistics

| Beat Category | Total Count | Percentage |
|---------------|-------------|------------|
| Normal beats (N, L, R, A, a, J, S, e, j) | ~100,000 | ~91% |
| Ventricular ectopic (V) | ~7,000 | ~6.4% |
| Fusion beats (F) | ~800 | ~0.7% |
| Paced beats (P, f) | ~7,000 | ~6.4% |
| Other/Unclassifiable | ~500 | ~0.5% |

### 6.2 Records with Most Ventricular Ectopy

| Record | PVCs | Fusion | Notes |
|--------|------|--------|-------|
| **208** | 992 | 373 | Uniform PVCs, bigeminal pattern |
| **233** | 831 | 11 | High PVC burden |
| **200** | 826 | 2 | Multiform PVCs |
| **106** | 520 | 0 | Significant VT |
| **223** | 473 | 14 | PVCs with VT episodes |
| **119** | 444 | 0 | VT episodes |
| **203** | 444 | 1 | Complex arrhythmias |

### 6.3 Records with Complex Arrhythmias

| Record | Notable Features |
|--------|------------------|
| **207** | LBBB/RBBB transitions, multiform PVCs, ventricular flutter, IVR |
| **208** | Couplets, triplets, bigeminy with fusion beats |
| **203** | Atrial flutter, atrial fibrillation, VT |
| **201** | Atrial fibrillation, nodal rhythm, trigeminy |
| **222** | AFL, AFIB, nodal rhythm, atrial bigeminy |

---

## 7. Rhythm Distribution Summary

### 7.1 Normal vs. Abnormal Rhythm Time

| Rhythm Category | Total Duration | Percentage |
|-----------------|----------------|------------|
| Normal Sinus Rhythm | ~20 hours | ~83% |
| Paced Rhythm | ~2 hours | ~8% |
| Atrial Fibrillation | ~2.5 hours | ~10% |
| Ventricular Arrhythmias | ~1 hour | ~4% |
| Other Abnormal | ~0.5 hours | ~2% |

### 7.2 Records with Sustained Arrhythmias

| Record | Atrial Fib | V. Tach | V. Flutter | Total Abnormal |
|--------|------------|---------|------------|----------------|
| 203 | 21:32 | 0:33 | - | 27+ min |
| 210 | 29:30 | 0:06 | - | 29+ min |
| 221 | 29:17 | 0:04 | - | 29+ min |
| 219 | 23:47 | - | - | 23+ min |
| 207 | - | 0:03 | 2:24 | Complex |

---

## 8. Signal Quality Considerations

### 8.1 Known Artifacts

| Issue | Affected Records | Impact |
|-------|------------------|--------|
| Tape skew (up to 40ms) | All | Minor timing issues |
| 60 Hz noise | Various | Requires filtering |
| Baseline wander | Various | Common in Holter |
| Muscle artifact | 200, others | May affect QRS detection |
| Tape slippage | Several | Marked with comments |

### 8.2 Challenging Records for Algorithm Testing

| Record | Challenge |
|--------|-----------|
| **207** | Extremely difficult - LBBB/RBBB transitions, multiform PVCs |
| **203** | Complex supraventricular arrhythmias |
| **108** | Noise and P-wave detection issues |
| **200** | Multiform PVCs with noise |
| **114** | Reversed signal leads |

---

## 9. Suitability for Guardian Angel Project

### 9.1 Strengths for HRV-Based Arrhythmia Screening

| Aspect | Assessment |
|--------|------------|
| **Beat Annotations** | ✅ Excellent - Expert-verified R-peak locations |
| **Arrhythmia Diversity** | ✅ Wide range of clinically relevant rhythms |
| **Recording Duration** | ✅ 30 min windows suitable for HRV analysis |
| **Benchmark Status** | ✅ Gold standard for algorithm comparison |
| **Documentation** | ✅ Comprehensive clinical notes |

### 9.2 Limitations to Consider

| Limitation | Mitigation Strategy |
|------------|---------------------|
| Small sample size (47 subjects) | Use cross-validation, consider data augmentation |
| Age of recordings (1970s-80s) | Modern wearables have different noise profiles |
| Hospital population | May not represent healthy ambulatory population |
| Two-channel only | Adequate for RR interval extraction |
| Paced records (4/48) | Exclude or handle separately |

### 9.3 Recommended Usage for Your Project

1. **Primary Use**: Extract RR intervals from beat annotations for HRV feature computation
2. **Label Strategy**: 
   - Normal: Records with predominantly normal sinus rhythm
   - Arrhythmia: Records with significant ventricular or atrial arrhythmias
3. **Exclude**: Paced records (102, 104, 107, 217) unless specifically handling paced rhythms
4. **Split Strategy**: Patient-wise split to prevent data leakage

---

## 10. Data Access with WFDB

### 10.1 Loading Records in Python

```python
import wfdb

# Load a record (signals and metadata)
record = wfdb.rdrecord('100', pn_dir='mitdb')
# Or from local path:
record = wfdb.rdrecord('/path/to/dataset/100')

# Load annotations
annotation = wfdb.rdann('100', 'atr', pn_dir='mitdb')
# Or from local path:
annotation = wfdb.rdann('/path/to/dataset/100', 'atr')

# Get RR intervals
r_peaks = annotation.sample  # Sample indices of R-peaks
rr_intervals = np.diff(r_peaks) / record.fs * 1000  # in milliseconds
```

### 10.2 Key Annotation Attributes

```python
annotation.sample    # Sample indices of beats
annotation.symbol    # Beat type symbols (N, V, A, etc.)
annotation.aux_note  # Rhythm annotations (when present)
```

---

## 11. Recommended Class Mapping for Screening

### 11.1 Binary Classification (Normal vs. Arrhythmia Risk)

| Class | Beat Types | Records |
|-------|------------|---------|
| **Normal (0)** | N, L, R (bundle branch blocks acceptable) | 100, 101, 103, 105, 108, 109, 111, 112, 113, 115, 117, 121, 122, 123, 212, 230, 231 |
| **Arrhythmia Risk (1)** | V (PVCs), VT, VFL, AFIB, AFL present | 106, 119, 200, 201, 203, 207, 208, 213, 214, 215, 217, 219, 221, 223, 228, 233 |

### 11.2 Window-Level Labeling Strategy

For HRV-based screening:
1. Divide each record into 5-minute windows
2. Label window as "Arrhythmia Risk" if:
   - PVC burden > 5% in window
   - Any sustained VT/VFL episode
   - Any AFIB/AFL episode > 30 seconds
3. Otherwise label as "Normal"

---

## 12. Summary Statistics Table

| Metric | Value |
|--------|-------|
| Total Records | 48 |
| Total Subjects | 47 |
| Recording Duration | ~30 min each |
| Sampling Rate | 360 Hz |
| ECG Channels | 2 |
| Total Beats | ~110,000 |
| Normal Beats | ~100,000 (91%) |
| PVCs | ~7,000 (6.4%) |
| Paced Beats | ~7,000 (6.4%) |
| Records with VT | 15 |
| Records with AFIB | 10 |
| Pacemaker Records | 4 |

---

## 13. References

1. Moody GB, Mark RG. The impact of the MIT-BIH Arrhythmia Database. IEEE Eng in Med and Biol 20(3):45-50 (May-June 2001).
2. Goldberger AL, et al. PhysioBank, PhysioToolkit, and PhysioNet: Components of a New Research Resource for Complex Physiologic Signals. Circulation 101(23):e215-e220 (2000).
3. MIT-BIH Arrhythmia Database Directory: https://physionet.org/content/mitdb/

---

## 14. Next Steps for Guardian Angel

1. ✅ Dataset available and verified
2. ⬜ Run RR interval extraction script
3. ⬜ Compute HRV features per 5-minute window
4. ⬜ Create patient-wise train/val/test splits
5. ⬜ Train XGBoost screening model
6. ⬜ Evaluate with clinical metrics (sensitivity prioritized)

---

*Report generated for Guardian Angel Arrhythmia Risk Screening Project*
*Dataset Location: `arrhythmia_risk_model/dataset/mit-bih-arrhythmia-database-1.0.0/`*
