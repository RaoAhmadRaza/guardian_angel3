"""
Window Labeling Logic for Arrhythmia Risk Screening

This module implements the labeling logic for identifying arrhythmia RISK,
not arrhythmia diagnosis. The labels indicate elevated cardiovascular risk
based on rhythm abnormalities detectable in ECG/HRV data.

IMPORTANT CLINICAL CONTEXT:
- Label = 1 means "ELEVATED ARRHYTHMIA RISK" - warrants clinical follow-up
- Label = 0 means "LOW RISK" - normal sinus rhythm patterns
- This is SCREENING, not DIAGNOSIS

Labeling Criteria (based on MIT-BIH beat annotations):
1. PVC Burden > 5%: Premature ventricular contractions indicate risk
2. Supraventricular Ectopy > 10%: PACs and other atrial arrhythmias
3. Any sustained abnormal rhythm: Ventricular runs, atrial flutter/fib

Beat Type Classifications (from MIT-BIH):
- Normal (N): N, L (LBBB), R (RBBB), e, j, B (bundle branch)
- Ventricular (V): V (PVC), ! (ventricular flutter), E (escape beat)
- Supraventricular (S): A (PAC), a, S, J (nodal escape)
- Other abnormal: F (fusion), / (paced), f (fusion paced), Q (unclass)
"""

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import numpy as np

from .preprocessing import RRWindow


# Beat classification mapping based on MIT-BIH annotation codes
# Reference: https://physionet.org/physiobank/database/html/mitdbdir/tables.htm

NORMAL_BEATS = {'N', 'L', 'R', 'e', 'j', 'B'}
"""Normal sinus rhythm and bundle branch variants."""

VENTRICULAR_BEATS = {'V', '!', 'E', 'F'}
"""
Ventricular ectopic beats:
- V: Premature ventricular contraction (PVC)
- !: Ventricular flutter wave
- E: Ventricular escape beat
- F: Fusion of ventricular and normal beat
"""

SUPRAVENTRICULAR_BEATS = {'A', 'a', 'S', 'J'}
"""
Supraventricular ectopic beats:
- A: Atrial premature beat (PAC)
- a: Aberrated atrial premature beat
- S: Supraventricular premature beat
- J: Nodal (junctional) escape beat
"""

PACED_BEATS = {'/', 'f', 'p'}
"""Paced beats - exclude from analysis."""

OTHER_BEATS = {'Q', 'x', '|'}
"""Unclassifiable or artifact markers."""


@dataclass
class WindowLabel:
    """
    Label information for a single window.
    
    Attributes:
        label: Binary label (1=risk, 0=normal)
        pvc_burden: Percentage of PVCs in window
        sv_burden: Percentage of supraventricular ectopy
        has_ventricular_run: Whether 3+ consecutive V beats detected
        label_reason: Human-readable reason for label
        beat_counts: Dict of beat type counts
    """
    label: int
    pvc_burden: float
    sv_burden: float
    has_ventricular_run: bool
    label_reason: str
    beat_counts: Dict[str, int]
    
    @property
    def is_risk(self) -> bool:
        """Whether this window indicates arrhythmia risk."""
        return self.label == 1


@dataclass  
class LabelingConfig:
    """
    Configuration for window labeling thresholds.
    
    These thresholds define what constitutes "elevated risk":
    - Conservative thresholds reduce false alarms (high specificity)
    - Aggressive thresholds catch more cases (high sensitivity)
    
    Current defaults are SCREENING-appropriate (favor sensitivity).
    """
    # PVC threshold - >5% PVC burden indicates risk
    # Clinical basis: >6 PVCs/minute or >5% in 24h associated with increased risk
    pvc_threshold: float = 5.0
    
    # Supraventricular ectopy threshold
    # PACs >100/day associated with AF risk
    sv_threshold: float = 10.0
    
    # Consecutive ventricular beats to flag (run of V beats)
    # 3+ is commonly used for "ventricular run"
    ventricular_run_length: int = 3
    
    # Minimum total beats for reliable labeling
    min_beats: int = 30


class WindowLabeler:
    """
    Labels windows for arrhythmia risk based on beat composition.
    
    This implements a RULE-BASED labeling strategy using clinically
    meaningful thresholds. The rules are:
    
    LABEL = 1 (Arrhythmia Risk) if ANY of:
    1. PVC burden > pvc_threshold (default 5%)
    2. Supraventricular ectopy > sv_threshold (default 10%)  
    3. Ventricular run detected (3+ consecutive V beats)
    
    LABEL = 0 (Normal/Low Risk) otherwise
    
    Note: This is for SCREENING. Final clinical decisions require
    physician review and additional testing.
    """
    
    def __init__(self, config: Optional[LabelingConfig] = None):
        """
        Initialize labeler with configuration.
        
        Args:
            config: LabelingConfig with thresholds. Defaults used if None.
        """
        self.config = config or LabelingConfig()
    
    def label_window(self, window: RRWindow) -> WindowLabel:
        """
        Assign risk label to a single window.
        
        Args:
            window: RRWindow with beat_types information
            
        Returns:
            WindowLabel with label and supporting metrics
        """
        # Count beat types
        beat_counts = self._count_beats(window.beat_types)
        total_beats = sum(beat_counts.values())
        
        # Handle insufficient data
        if total_beats < self.config.min_beats:
            return WindowLabel(
                label=0,  # Default to low-risk if insufficient data
                pvc_burden=0.0,
                sv_burden=0.0,
                has_ventricular_run=False,
                label_reason="Insufficient beats for reliable labeling",
                beat_counts=beat_counts
            )
        
        # Calculate burdens
        v_count = beat_counts.get('ventricular', 0)
        sv_count = beat_counts.get('supraventricular', 0)
        
        pvc_burden = (v_count / total_beats) * 100
        sv_burden = (sv_count / total_beats) * 100
        
        # Check for ventricular runs
        has_v_run = self._detect_ventricular_run(window.beat_types)
        
        # Apply labeling rules
        label = 0
        reasons = []
        
        if pvc_burden > self.config.pvc_threshold:
            label = 1
            reasons.append(f"PVC burden {pvc_burden:.1f}% > {self.config.pvc_threshold}%")
        
        if sv_burden > self.config.sv_threshold:
            label = 1
            reasons.append(f"SV ectopy {sv_burden:.1f}% > {self.config.sv_threshold}%")
        
        if has_v_run:
            label = 1
            reasons.append(f"Ventricular run (≥{self.config.ventricular_run_length} consecutive)")
        
        label_reason = "; ".join(reasons) if reasons else "Normal sinus rhythm"
        
        return WindowLabel(
            label=label,
            pvc_burden=pvc_burden,
            sv_burden=sv_burden,
            has_ventricular_run=has_v_run,
            label_reason=label_reason,
            beat_counts=beat_counts
        )
    
    def label_windows(self, windows: List[RRWindow]) -> List[WindowLabel]:
        """
        Label multiple windows.
        
        Args:
            windows: List of RRWindow objects
            
        Returns:
            List of WindowLabel objects
        """
        return [self.label_window(w) for w in windows]
    
    def _count_beats(self, beat_types: List[str]) -> Dict[str, int]:
        """
        Count beats by category.
        
        Returns:
            Dict with keys: 'normal', 'ventricular', 'supraventricular', 
                           'paced', 'other'
        """
        counts = {
            'normal': 0,
            'ventricular': 0,
            'supraventricular': 0,
            'paced': 0,
            'other': 0
        }
        
        for beat in beat_types:
            if beat in NORMAL_BEATS:
                counts['normal'] += 1
            elif beat in VENTRICULAR_BEATS:
                counts['ventricular'] += 1
            elif beat in SUPRAVENTRICULAR_BEATS:
                counts['supraventricular'] += 1
            elif beat in PACED_BEATS:
                counts['paced'] += 1
            else:
                counts['other'] += 1
        
        return counts
    
    def _detect_ventricular_run(self, beat_types: List[str]) -> bool:
        """
        Detect if there's a run of consecutive ventricular beats.
        
        A "run" is defined as >= ventricular_run_length consecutive V beats.
        """
        run_length = self.config.ventricular_run_length
        consecutive = 0
        
        for beat in beat_types:
            if beat in VENTRICULAR_BEATS:
                consecutive += 1
                if consecutive >= run_length:
                    return True
            else:
                consecutive = 0
        
        return False
    
    def get_label_distribution(
        self, 
        labels: List[WindowLabel]
    ) -> Dict[str, any]:
        """
        Get summary statistics for a list of labels.
        
        Returns:
            Dict with label counts, percentages, and reasons
        """
        n_total = len(labels)
        n_risk = sum(1 for l in labels if l.label == 1)
        n_normal = n_total - n_risk
        
        # Collect unique reasons
        risk_reasons = [l.label_reason for l in labels if l.label == 1]
        
        # Average burdens
        avg_pvc = np.mean([l.pvc_burden for l in labels]) if labels else 0
        avg_sv = np.mean([l.sv_burden for l in labels]) if labels else 0
        
        return {
            'total_windows': n_total,
            'n_risk': n_risk,
            'n_normal': n_normal,
            'pct_risk': (n_risk / n_total * 100) if n_total > 0 else 0,
            'avg_pvc_burden': avg_pvc,
            'avg_sv_burden': avg_sv,
            'risk_reasons': risk_reasons
        }
    
    @staticmethod
    def get_labeling_criteria_summary() -> str:
        """Return human-readable summary of labeling criteria."""
        return """
ARRHYTHMIA RISK LABELING CRITERIA
=================================
Label = 1 (ELEVATED RISK) if ANY of:
  1. PVC burden > 5% (default threshold)
  2. Supraventricular ectopy > 10% (default threshold)
  3. Ventricular run detected (≥3 consecutive V beats)

Label = 0 (LOW RISK) otherwise

Beat Classifications:
  Normal: N, L, R, e, j, B (sinus rhythm variants)
  Ventricular: V (PVC), ! (flutter), E (escape), F (fusion)
  Supraventricular: A (PAC), a, S, J (junctional)

This is SCREENING for elevated risk, not diagnosis.
Clinical follow-up required for any positive screens.
"""


def create_training_dataset(
    windows: List[RRWindow],
    features: np.ndarray,
    labeler: Optional[WindowLabeler] = None
) -> Tuple[np.ndarray, np.ndarray, List[WindowLabel]]:
    """
    Create labeled training dataset from windows and features.
    
    Args:
        windows: List of RRWindow objects
        features: Feature matrix (n_windows, n_features)
        labeler: WindowLabeler instance (default config if None)
        
    Returns:
        Tuple of (X features, y labels, WindowLabel objects)
    """
    if labeler is None:
        labeler = WindowLabeler()
    
    # Generate labels
    labels = labeler.label_windows(windows)
    y = np.array([l.label for l in labels])
    
    return features, y, labels
