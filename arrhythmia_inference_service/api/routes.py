"""
API Routes for Arrhythmia Inference Service

Endpoints:
- POST /v1/arrhythmia/analyze - Analyze RR intervals
- GET /health - Health check
"""

import logging
import time
from datetime import datetime
from typing import Optional

import numpy as np
from fastapi import APIRouter, HTTPException, status

from api.schemas import (
    AnalysisRequest,
    AnalysisSuccessResponse,
    AnalysisErrorResponse,
    ArrhythmiaAnalysis,
    FeatureSummary,
    TimeDomainFeatures,
    FrequencyDomainFeatures,
    FeatureInterpretation,
    ModelInfo,
    Timing,
    Audit,
    HealthResponse,
    RiskLevel,
    Confidence,
    Recommendation,
    ErrorDetails,
)
from config import settings
from core.feature_extractor import HRVFeatureExtractor
from core.predictor import get_predictor, InferenceError
from core.validator import validator, ValidationResult


logger = logging.getLogger(__name__)

router = APIRouter()

# Track last inference time for health check
_last_inference_at: Optional[datetime] = None
_startup_time: datetime = datetime.utcnow()

# Feature extractor instance
_extractor = HRVFeatureExtractor()


def _classify_risk(probability: float) -> RiskLevel:
    """Classify risk probability into categorical level."""
    if probability < settings.risk_threshold_low:
        return RiskLevel.LOW
    elif probability < settings.risk_threshold_moderate:
        return RiskLevel.MODERATE
    elif probability < settings.risk_threshold_elevated:
        return RiskLevel.ELEVATED
    else:
        return RiskLevel.HIGH


def _get_confidence(features_valid: bool, rr_count: int) -> Confidence:
    """Determine analysis confidence based on data quality."""
    if not features_valid:
        return Confidence.LOW
    if rr_count >= 60:
        return Confidence.HIGH
    elif rr_count >= 40:
        return Confidence.MEDIUM
    else:
        return Confidence.LOW


def _get_recommendation(risk_level: RiskLevel) -> Recommendation:
    """Get clinical recommendation based on risk level."""
    match risk_level:
        case RiskLevel.LOW:
            return Recommendation.NORMAL
        case RiskLevel.MODERATE:
            return Recommendation.MONITOR
        case RiskLevel.ELEVATED:
            return Recommendation.CONSULT
        case RiskLevel.HIGH:
            return Recommendation.URGENT


def _interpret_hrv(features: dict) -> FeatureInterpretation:
    """Generate human-readable interpretation of HRV features."""
    sdnn = features.get("sdnn", 0)
    rmssd = features.get("rmssd", 0)
    lf_hf_ratio = features.get("lf_hf_ratio", 1.0)
    
    # Determine HRV status
    if sdnn < 20:
        hrv_status = "severely_reduced"
    elif sdnn < 50:
        hrv_status = "reduced"
    elif sdnn < 100:
        hrv_status = "normal"
    else:
        hrv_status = "elevated"
    
    # Determine dominant concern
    dominant_concern = None
    
    if rmssd > 100:
        dominant_concern = "possible_atrial_fibrillation"
    elif lf_hf_ratio and lf_hf_ratio > 4.0:
        dominant_concern = "elevated_sympathetic_tone"
    elif sdnn < 20:
        dominant_concern = "severely_reduced_autonomic_function"
    
    return FeatureInterpretation(
        hrv_status=hrv_status,
        dominant_concern=dominant_concern,
    )


@router.post(
    "/v1/arrhythmia/analyze",
    response_model=AnalysisSuccessResponse,
    responses={
        400: {"model": AnalysisErrorResponse, "description": "Malformed request"},
        422: {"model": AnalysisErrorResponse, "description": "Validation error"},
        503: {"model": AnalysisErrorResponse, "description": "Model unavailable"},
    },
    summary="Analyze RR intervals for arrhythmia risk",
    description="Accepts RR intervals and returns arrhythmia risk assessment",
)
async def analyze_arrhythmia(request: AnalysisRequest):
    """
    Analyze RR intervals for arrhythmia risk.
    
    Performs:
    1. Input validation
    2. HRV feature extraction (15 features)
    3. XGBoost inference
    4. Risk classification
    """
    global _last_inference_at
    
    request_id = request.request_id
    start_time = time.perf_counter()
    
    logger.info(f"[{request_id}] Received analysis request with {len(request.rr_intervals_ms)} RR intervals")
    
    # Step 1: Validate input
    validation = validator.validate(
        rr_intervals_ms=request.rr_intervals_ms,
        start_timestamp=request.window_metadata.start_timestamp_iso,
        end_timestamp=request.window_metadata.end_timestamp_iso,
    )
    
    if not validation.is_valid:
        logger.warning(f"[{request_id}] Validation failed: {validation.error_code}")
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "request_id": request_id,
                "status": "error",
                "error": {
                    "code": validation.error_code,
                    "message": validation.error_message,
                    "details": validation.error_details,
                },
                "timestamp_iso": datetime.utcnow().isoformat(),
            }
        )
    
    # Step 2: Extract features
    feature_start = time.perf_counter()
    
    rr_array = np.array(validation.cleaned_rr_intervals, dtype=np.float64)
    features = _extractor.extract(rr_array)
    
    feature_time_ms = int((time.perf_counter() - feature_start) * 1000)
    
    if not features.is_valid:
        logger.warning(f"[{request_id}] Feature extraction failed: {features.invalid_domains}")
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "request_id": request_id,
                "status": "error",
                "error": {
                    "code": "FEATURE_EXTRACTION_FAILED",
                    "message": f"Could not extract features from RR intervals",
                    "details": {"invalid_domains": features.invalid_domains},
                },
                "timestamp_iso": datetime.utcnow().isoformat(),
            }
        )
    
    # Step 3: Run inference
    inference_start = time.perf_counter()
    
    predictor = get_predictor()
    
    if not predictor.is_loaded:
        logger.error(f"[{request_id}] Model not loaded")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "request_id": request_id,
                "status": "error",
                "error": {
                    "code": "MODEL_UNAVAILABLE",
                    "message": "Arrhythmia detection model is not loaded",
                    "details": None,
                },
                "timestamp_iso": datetime.utcnow().isoformat(),
            }
        )
    
    try:
        risk_probability = predictor.predict(features)
    except InferenceError as e:
        logger.error(f"[{request_id}] Inference error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "request_id": request_id,
                "status": "error",
                "error": {
                    "code": "INFERENCE_ERROR",
                    "message": str(e),
                    "details": None,
                },
                "timestamp_iso": datetime.utcnow().isoformat(),
            }
        )
    
    inference_time_ms = int((time.perf_counter() - inference_start) * 1000)
    total_time_ms = int((time.perf_counter() - start_time) * 1000)
    
    # Step 4: Build response
    risk_level = _classify_risk(risk_probability)
    confidence = _get_confidence(features.is_valid, len(validation.cleaned_rr_intervals))
    recommendation = _get_recommendation(risk_level)
    
    feature_dict = features.to_dict()
    
    response = AnalysisSuccessResponse(
        request_id=request_id,
        status="success",
        analysis=ArrhythmiaAnalysis(
            risk_probability=round(risk_probability, 4),
            risk_level=risk_level,
            confidence=confidence,
            recommendation=recommendation,
        ),
        feature_summary=FeatureSummary(
            time_domain=TimeDomainFeatures(
                mean_rr_ms=round(feature_dict["mean_rr"], 1),
                sdnn_ms=round(feature_dict["sdnn"], 1),
                rmssd_ms=round(feature_dict["rmssd"], 1),
                pnn50_percent=round(feature_dict["pnn50"], 1),
            ),
            frequency_domain=FrequencyDomainFeatures(
                lf_hf_ratio=round(feature_dict.get("lf_hf_ratio", 0), 2),
                total_power_ms2=round(feature_dict.get("total_power", 0), 1),
            ),
            interpretation=_interpret_hrv(feature_dict),
        ),
        model_info=ModelInfo(
            model_version=predictor.model_version,
            model_hash=f"sha256:{predictor.model_hash}",
            feature_count=predictor.feature_count,
            trained_at=predictor.trained_at,
        ),
        timing=Timing(
            feature_extraction_ms=feature_time_ms,
            inference_ms=inference_time_ms,
            total_ms=total_time_ms,
        ),
        audit=Audit(
            analyzed_at_iso=datetime.utcnow(),
            rr_count_received=len(request.rr_intervals_ms),
            window_duration_s=validation.window_duration_s,
        ),
    )
    
    _last_inference_at = datetime.utcnow()
    
    logger.info(
        f"[{request_id}] Analysis complete. "
        f"Risk: {risk_probability:.3f} ({risk_level.value}), "
        f"Time: {total_time_ms}ms"
    )
    
    return response


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Health check",
    description="Check if service is healthy and model is loaded",
)
async def health_check():
    """
    Health check endpoint.
    
    Returns service status and model information.
    """
    predictor = get_predictor()
    uptime = (datetime.utcnow() - _startup_time).total_seconds()
    
    return HealthResponse(
        status="healthy" if predictor.is_loaded else "degraded",
        model_loaded=predictor.is_loaded,
        model_version=predictor.model_version if predictor.is_loaded else None,
        uptime_seconds=round(uptime, 1),
        last_inference_at=_last_inference_at,
    )
