"""
Pydantic Schemas for Arrhythmia Analysis API

Defines request/response models with validation.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# =============================================================================
# ENUMS
# =============================================================================

class RiskLevel(str, Enum):
    """Arrhythmia risk classification levels."""
    LOW = "low"
    MODERATE = "moderate"
    ELEVATED = "elevated"
    HIGH = "high"


class Confidence(str, Enum):
    """Analysis confidence levels."""
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class Recommendation(str, Enum):
    """Clinical recommendations based on risk."""
    NORMAL = "normal_rhythm"
    MONITOR = "continue_monitoring"
    CONSULT = "consult_physician"
    URGENT = "seek_immediate_care"


# =============================================================================
# REQUEST MODELS
# =============================================================================

class WindowMetadata(BaseModel):
    """Metadata about the analysis window."""
    
    start_timestamp_iso: datetime = Field(
        ...,
        description="Start of the RR interval window (ISO8601)"
    )
    end_timestamp_iso: datetime = Field(
        ...,
        description="End of the RR interval window (ISO8601)"
    )
    source_device: Optional[str] = Field(
        None,
        description="Device that captured the data (e.g., 'apple_watch')"
    )
    patient_uid: Optional[str] = Field(
        None,
        description="Optional patient identifier for audit logging"
    )


class AnalysisRequest(BaseModel):
    """Request body for arrhythmia analysis endpoint."""
    
    request_id: str = Field(
        ...,
        description="Client-generated UUID for request tracing",
        min_length=1,
        max_length=64
    )
    rr_intervals_ms: list[int] = Field(
        ...,
        description="RR intervals in milliseconds",
        min_length=1
    )
    window_metadata: WindowMetadata = Field(
        ...,
        description="Metadata about the analysis window"
    )
    
    @field_validator('rr_intervals_ms')
    @classmethod
    def validate_rr_intervals(cls, v: list[int]) -> list[int]:
        """Basic validation - detailed validation in validator module."""
        if not v:
            raise ValueError("rr_intervals_ms cannot be empty")
        return v


# =============================================================================
# RESPONSE MODELS
# =============================================================================

class TimeDomainFeatures(BaseModel):
    """Time-domain HRV features for response."""
    
    mean_rr_ms: float = Field(..., description="Mean RR interval in ms")
    sdnn_ms: float = Field(..., description="Standard deviation of NN intervals")
    rmssd_ms: float = Field(..., description="Root mean square of successive differences")
    pnn50_percent: float = Field(..., description="Percentage of successive differences > 50ms")


class FrequencyDomainFeatures(BaseModel):
    """Frequency-domain HRV features for response."""
    
    lf_hf_ratio: float = Field(..., description="LF/HF power ratio")
    total_power_ms2: float = Field(..., description="Total spectral power")


class FeatureInterpretation(BaseModel):
    """Human-readable interpretation of features."""
    
    hrv_status: str = Field(..., description="Overall HRV status")
    dominant_concern: Optional[str] = Field(None, description="Primary concern if any")


class FeatureSummary(BaseModel):
    """Summary of extracted HRV features."""
    
    time_domain: TimeDomainFeatures
    frequency_domain: FrequencyDomainFeatures
    interpretation: FeatureInterpretation


class ArrhythmiaAnalysis(BaseModel):
    """Core analysis results."""
    
    risk_probability: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Probability of elevated arrhythmia risk (0-1)"
    )
    risk_level: RiskLevel = Field(..., description="Categorical risk level")
    confidence: Confidence = Field(..., description="Analysis confidence")
    recommendation: Recommendation = Field(..., description="Clinical recommendation")


class ModelInfo(BaseModel):
    """Information about the model used for inference."""
    
    model_version: str = Field(..., description="Model version string")
    model_hash: str = Field(..., description="SHA256 hash of model file")
    feature_count: int = Field(..., description="Number of features used")
    trained_at: str = Field(..., description="When the model was trained")


class Timing(BaseModel):
    """Performance timing information."""
    
    feature_extraction_ms: int = Field(..., description="Time to extract features")
    inference_ms: int = Field(..., description="Time to run model inference")
    total_ms: int = Field(..., description="Total processing time")


class Audit(BaseModel):
    """Audit trail information."""
    
    analyzed_at_iso: datetime = Field(..., description="When analysis was performed")
    rr_count_received: int = Field(..., description="Number of RR intervals received")
    window_duration_s: float = Field(..., description="Duration of analysis window")


class AnalysisSuccessResponse(BaseModel):
    """Successful analysis response."""
    
    request_id: str
    status: str = "success"
    analysis: ArrhythmiaAnalysis
    feature_summary: FeatureSummary
    model_info: ModelInfo
    timing: Timing
    audit: Audit


class ErrorDetails(BaseModel):
    """Detailed error information."""
    
    code: str = Field(..., description="Error code")
    message: str = Field(..., description="Human-readable error message")
    details: Optional[dict] = Field(None, description="Additional error details")


class AnalysisErrorResponse(BaseModel):
    """Error response for failed analysis."""
    
    request_id: str
    status: str = "error"
    error: ErrorDetails
    timestamp_iso: datetime = Field(default_factory=datetime.utcnow)


class HealthResponse(BaseModel):
    """Health check response."""
    
    status: str = Field(..., description="Service health status")
    model_loaded: bool = Field(..., description="Whether model is loaded")
    model_version: Optional[str] = Field(None, description="Loaded model version")
    uptime_seconds: float = Field(..., description="Service uptime")
    last_inference_at: Optional[datetime] = Field(None, description="Last inference timestamp")
