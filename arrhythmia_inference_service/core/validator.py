"""
Input Validator

Validates RR interval data before feature extraction and inference.
"""

from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional, Tuple

from config import settings


@dataclass
class ValidationResult:
    """Result of input validation."""
    is_valid: bool
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    error_details: Optional[dict] = None
    
    # Cleaned data (if valid)
    cleaned_rr_intervals: Optional[List[int]] = None
    window_duration_s: Optional[float] = None


class InputValidator:
    """
    Validates RR interval input for arrhythmia analysis.
    
    Checks:
    - RR count (min/max)
    - RR values (physiological range)
    - Window duration (reasonable time span)
    """
    
    def __init__(
        self,
        min_rr_count: int = settings.min_rr_count,
        max_rr_count: int = settings.max_rr_count,
        min_rr_value_ms: int = settings.min_rr_value_ms,
        max_rr_value_ms: int = settings.max_rr_value_ms,
        min_window_duration_s: int = settings.min_window_duration_s,
        max_window_duration_s: int = settings.max_window_duration_s,
    ):
        """Initialize validator with thresholds."""
        self.min_rr_count = min_rr_count
        self.max_rr_count = max_rr_count
        self.min_rr_value_ms = min_rr_value_ms
        self.max_rr_value_ms = max_rr_value_ms
        self.min_window_duration_s = min_window_duration_s
        self.max_window_duration_s = max_window_duration_s
    
    def validate(
        self,
        rr_intervals_ms: List[int],
        start_timestamp: datetime,
        end_timestamp: datetime,
    ) -> ValidationResult:
        """
        Validate RR interval input.
        
        Args:
            rr_intervals_ms: List of RR intervals in milliseconds
            start_timestamp: Start of window
            end_timestamp: End of window
            
        Returns:
            ValidationResult with status and cleaned data
        """
        # Check RR count
        count_result = self._validate_count(rr_intervals_ms)
        if not count_result.is_valid:
            return count_result
        
        # Check RR values and filter invalid ones
        values_result = self._validate_values(rr_intervals_ms)
        if not values_result.is_valid:
            return values_result
        
        cleaned_rr = values_result.cleaned_rr_intervals
        
        # Check if enough valid RR intervals remain after filtering
        if len(cleaned_rr) < self.min_rr_count:
            return ValidationResult(
                is_valid=False,
                error_code="INSUFFICIENT_VALID_DATA",
                error_message=(
                    f"After filtering invalid values, only {len(cleaned_rr)} "
                    f"intervals remain. Minimum required: {self.min_rr_count}"
                ),
                error_details={
                    "original_count": len(rr_intervals_ms),
                    "valid_count": len(cleaned_rr),
                    "minimum_required": self.min_rr_count,
                }
            )
        
        # Check window duration
        window_result = self._validate_window(start_timestamp, end_timestamp)
        if not window_result.is_valid:
            return window_result
        
        # All checks passed
        return ValidationResult(
            is_valid=True,
            cleaned_rr_intervals=cleaned_rr,
            window_duration_s=window_result.window_duration_s,
        )
    
    def _validate_count(self, rr_intervals_ms: List[int]) -> ValidationResult:
        """Validate RR interval count."""
        count = len(rr_intervals_ms)
        
        if count < self.min_rr_count:
            return ValidationResult(
                is_valid=False,
                error_code="INSUFFICIENT_DATA",
                error_message=(
                    f"Received {count} RR intervals, "
                    f"minimum required is {self.min_rr_count}"
                ),
                error_details={
                    "received_count": count,
                    "minimum_required": self.min_rr_count,
                }
            )
        
        if count > self.max_rr_count:
            return ValidationResult(
                is_valid=False,
                error_code="EXCESSIVE_DATA",
                error_message=(
                    f"Received {count} RR intervals, "
                    f"maximum allowed is {self.max_rr_count}"
                ),
                error_details={
                    "received_count": count,
                    "maximum_allowed": self.max_rr_count,
                }
            )
        
        return ValidationResult(is_valid=True)
    
    def _validate_values(self, rr_intervals_ms: List[int]) -> ValidationResult:
        """
        Validate RR interval values.
        
        Filters out invalid values and returns cleaned list.
        """
        cleaned = []
        invalid_count = 0
        invalid_values = []
        
        for rr in rr_intervals_ms:
            if self.min_rr_value_ms <= rr <= self.max_rr_value_ms:
                cleaned.append(rr)
            else:
                invalid_count += 1
                if len(invalid_values) < 5:  # Keep first 5 for diagnostics
                    invalid_values.append(rr)
        
        # If more than 50% are invalid, reject entirely
        if invalid_count > len(rr_intervals_ms) * 0.5:
            return ValidationResult(
                is_valid=False,
                error_code="INVALID_RR_VALUES",
                error_message=(
                    f"{invalid_count} of {len(rr_intervals_ms)} RR intervals "
                    f"are outside valid range ({self.min_rr_value_ms}-{self.max_rr_value_ms} ms)"
                ),
                error_details={
                    "invalid_count": invalid_count,
                    "total_count": len(rr_intervals_ms),
                    "valid_range_ms": [self.min_rr_value_ms, self.max_rr_value_ms],
                    "sample_invalid_values": invalid_values,
                }
            )
        
        return ValidationResult(
            is_valid=True,
            cleaned_rr_intervals=cleaned,
        )
    
    def _validate_window(
        self,
        start_timestamp: datetime,
        end_timestamp: datetime,
    ) -> ValidationResult:
        """Validate window duration."""
        # Handle timezone-aware vs naive datetimes
        if start_timestamp.tzinfo is not None and end_timestamp.tzinfo is not None:
            duration = (end_timestamp - start_timestamp).total_seconds()
        else:
            # Assume both are naive and in same timezone
            duration = (end_timestamp - start_timestamp).total_seconds()
        
        if duration < self.min_window_duration_s:
            return ValidationResult(
                is_valid=False,
                error_code="WINDOW_TOO_SHORT",
                error_message=(
                    f"Window duration is {duration:.1f} seconds, "
                    f"minimum required is {self.min_window_duration_s} seconds"
                ),
                error_details={
                    "window_duration_s": duration,
                    "minimum_required_s": self.min_window_duration_s,
                }
            )
        
        if duration > self.max_window_duration_s:
            return ValidationResult(
                is_valid=False,
                error_code="WINDOW_TOO_LONG",
                error_message=(
                    f"Window duration is {duration:.1f} seconds, "
                    f"maximum allowed is {self.max_window_duration_s} seconds"
                ),
                error_details={
                    "window_duration_s": duration,
                    "maximum_allowed_s": self.max_window_duration_s,
                }
            )
        
        return ValidationResult(
            is_valid=True,
            window_duration_s=duration,
        )


# Global validator instance
validator = InputValidator()
