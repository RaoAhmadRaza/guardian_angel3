# Fall Detection System - Version 1.0 (FROZEN)

## Model Version
- **Name:** FallDetector_v1_baseline
- **Frozen Date:** 2024-12-25
- **Status:** LOCKED - Do not modify without version increment

## Training Data
- **Dataset:** SisFall (Subject-wise split)
- **Test Subjects:** SA21, SA22, SA23
- **Preprocessing:** Bandpass 0.5-20Hz, Z-score normalization

## Model Architecture
- **Type:** 1D CNN
- **Input Shape:** [1, 400, 8] (batch, timesteps, channels)
- **Channels:** ax, ay, az, accel_mag, gx, gy, gz, gyro_mag
- **Output:** Sigmoid probability (0-1)
- **File:** best_fall_model_v2.tflite

## Preprocessing Contract
```
INPUT:
- 400 samples per window
- 200 Hz sampling rate
- 6 raw channels: [ax, ay, az, gx, gy, gz]
- Units: m/s² (accel), rad/s (gyro)

PROCESSING:
1. Unit conversion (SI → SisFall counts)
2. High-pass filter (α=0.98) to remove gravity
3. Magnitude computation
4. Z-score normalization with fixed stats

OUTPUT:
- 8 normalized channels
- Values clamped to [-10, +10]
```

## Normalization Statistics (FROZEN)
```dart
trainMean = [-0.108100, -0.181585, -0.108891, -0.242277, 
             0.113382, 0.156914, 253.465736, 417.484682]

trainStd = [212.180482, 415.224954, 234.732531, 574.561888,
            406.914084, 381.328314, 456.384550, 683.241066]
```

## Temporal Logic (FROZEN)
- **Voting:** 2-of-3 windows above threshold
- **Threshold:** 0.35 (35%)
- **Refractory Period:** 15 seconds
- **Window Step:** 100 samples (0.5 seconds)

## Optional Enhancements (v1.1 candidates)
- [ ] Post-impact stillness gating (currently disabled)
- [ ] Alert tier messaging
- [ ] Battery optimization

## Change Log
- **v1.0.0** (2024-12-25): Initial frozen release
  - Fixed unit conversion (SI → SisFall counts)
  - Added high-pass filter for gravity removal
  - Extracted real training statistics
  - Added input validation and clamping
  - Created preprocessing contract documentation

## Validation Results
From testing reports:
- Max acceleration spike: 49-76 m/s² (correctly detected)
- Threshold crossings: 2 per session
- Alerts triggered: 1 per session
- Average probability: 2-8% (correct for normal activity)
- System correctly entered refractory after alert

## DO NOT MODIFY
The following must remain unchanged for v1:
- Model weights
- Preprocessing statistics
- Threshold value
- Temporal voting parameters
- Refractory period
