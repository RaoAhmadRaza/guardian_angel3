# Arrhythmia Inference Service

Local-only FastAPI service for arrhythmia risk detection using the trained XGBoost model.

## Overview

This service:
- Runs the **unchanged** trained XGBoost model
- Extracts 15 HRV features from RR intervals
- Returns arrhythmia risk probability and classification
- Works **completely offline** (no cloud dependencies)

## Quick Start

### 1. Create Virtual Environment

```bash
cd arrhythmia_inference_service
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the Service

```bash
python main.py
```

Or with uvicorn directly:
```bash
uvicorn main:app --host 127.0.0.1 --port 8000
```

The service will be available at `http://127.0.0.1:8000`

## API Endpoints

### POST /v1/arrhythmia/analyze

Analyze RR intervals for arrhythmia risk.

**Request:**
```json
{
  "request_id": "uuid-v4",
  "rr_intervals_ms": [856, 862, 848, 870, 855, 863, 850, 868, ...],
  "window_metadata": {
    "start_timestamp_iso": "2026-01-05T10:30:00.000Z",
    "end_timestamp_iso": "2026-01-05T10:31:00.000Z",
    "source_device": "apple_watch",
    "patient_uid": "optional-patient-id"
  }
}
```

**Response (Success):**
```json
{
  "request_id": "uuid-v4",
  "status": "success",
  "analysis": {
    "risk_probability": 0.73,
    "risk_level": "elevated",
    "confidence": "high",
    "recommendation": "consult_physician"
  },
  "feature_summary": {
    "time_domain": {
      "mean_rr_ms": 857.4,
      "sdnn_ms": 42.3,
      "rmssd_ms": 38.1,
      "pnn50_percent": 12.4
    },
    "frequency_domain": {
      "lf_hf_ratio": 2.1,
      "total_power_ms2": 1842.0
    },
    "interpretation": {
      "hrv_status": "reduced",
      "dominant_concern": "elevated_sympathetic_tone"
    }
  },
  "model_info": {
    "model_version": "1.0.0",
    "model_hash": "sha256:abc123...",
    "feature_count": 15,
    "trained_at": "2026-01-03T00:00:00Z"
  },
  "timing": {
    "feature_extraction_ms": 12,
    "inference_ms": 3,
    "total_ms": 18
  }
}
```

### GET /health

Check service health status.

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_version": "1.0.0",
  "uptime_seconds": 3600,
  "last_inference_at": "2026-01-05T10:30:00Z"
}
```

## Input Validation

| Parameter | Constraint |
|-----------|------------|
| RR interval count | 40 - 200 |
| RR interval value | 200 - 2000 ms |
| Window duration | 30 - 120 seconds |

## Risk Levels

| Level | Probability Range | Recommendation |
|-------|-------------------|----------------|
| `low` | 0.00 - 0.30 | Normal rhythm |
| `moderate` | 0.30 - 0.50 | Continue monitoring |
| `elevated` | 0.50 - 0.70 | Consult physician |
| `high` | 0.70 - 1.00 | Seek immediate care |

## HRV Features (15 Total)

### Time-Domain (8)
- `mean_rr`: Mean RR interval (ms)
- `sdnn`: Standard deviation of NN intervals (ms)
- `rmssd`: Root mean square of successive differences (ms)
- `pnn50`: % of successive differences > 50ms
- `pnn20`: % of successive differences > 20ms
- `mean_hr`: Mean heart rate (BPM)
- `std_hr`: Standard deviation of heart rate (BPM)
- `cv_rr`: Coefficient of variation (%)

### Frequency-Domain (6)
- `lf_power`: Low frequency power (0.04-0.15 Hz) in ms²
- `hf_power`: High frequency power (0.15-0.4 Hz) in ms²
- `lf_hf_ratio`: LF/HF ratio
- `total_power`: Total spectral power (ms²)
- `lf_nu`: LF in normalized units (%)
- `hf_nu`: HF in normalized units (%)

### Non-Linear (1)
- `sample_entropy`: Signal complexity measure

## Configuration

Environment variables (prefix: `ARRHYTHMIA_`):

| Variable | Default | Description |
|----------|---------|-------------|
| `ARRHYTHMIA_HOST` | 127.0.0.1 | Server host |
| `ARRHYTHMIA_PORT` | 8000 | Server port |
| `ARRHYTHMIA_DEBUG` | false | Enable debug mode |
| `ARRHYTHMIA_LOG_LEVEL` | INFO | Logging level |

## Project Structure

```
arrhythmia_inference_service/
├── main.py                     # FastAPI entry point
├── config.py                   # Configuration
├── requirements.txt            # Dependencies
├── README.md                   # This file
│
├── api/
│   ├── __init__.py
│   ├── schemas.py              # Pydantic request/response models
│   └── routes.py               # API endpoints
│
├── core/
│   ├── __init__.py
│   ├── feature_extractor.py    # HRV feature extraction
│   ├── predictor.py            # XGBoost inference wrapper
│   └── validator.py            # Input validation
│
└── models/
    ├── xgboost_arrhythmia_risk.json       # Trained model (unchanged)
    └── xgboost_arrhythmia_risk_meta.json  # Model metadata
```

## Security

- **localhost only**: Service binds to 127.0.0.1 by default
- **No cloud calls**: All processing is local
- **No data persistence**: RR intervals are processed and discarded
- **Audit logging**: All requests are logged with timestamps

## Testing

```bash
# Health check
curl http://127.0.0.1:8000/health

# Analyze RR intervals
curl -X POST http://127.0.0.1:8000/v1/arrhythmia/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-001",
    "rr_intervals_ms": [856, 862, 848, 870, 855, 863, 850, 868, 857, 865, 856, 862, 848, 870, 855, 863, 850, 868, 857, 865, 856, 862, 848, 870, 855, 863, 850, 868, 857, 865, 856, 862, 848, 870, 855, 863, 850, 868, 857, 865, 856, 862, 848, 870, 855, 863, 850, 868, 857, 865],
    "window_metadata": {
      "start_timestamp_iso": "2026-01-05T10:30:00.000Z",
      "end_timestamp_iso": "2026-01-05T10:31:00.000Z",
      "source_device": "test"
    }
  }'
```

## License

Internal use only - Guardian Angel Project
