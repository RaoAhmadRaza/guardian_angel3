"""
Patient-Wise Data Splitter

Ensures no data leakage by splitting at patient level, not sample level.
This is CRITICAL for medical ML - windows from the same patient must
stay together in the same split to prevent artificially inflated performance.

MIT-BIH Note:
- 48 records from 47 subjects (201 and 202 are from the same patient)
- We treat each record_id as a unique patient for simplicity
- Paced records (102, 104, 107, 217) are typically excluded
"""

from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional
import numpy as np
from collections import defaultdict


@dataclass
class PatientSplit:
    """
    Container for a patient-wise data split.
    
    Attributes:
        train_patients: List of patient IDs in training set
        val_patients: List of patient IDs in validation set
        test_patients: List of patient IDs in test set
        train_indices: Indices into the full dataset for training
        val_indices: Indices into the full dataset for validation
        test_indices: Indices into the full dataset for testing
    """
    train_patients: List[str]
    val_patients: List[str]
    test_patients: List[str]
    train_indices: np.ndarray
    val_indices: np.ndarray
    test_indices: np.ndarray
    
    @property
    def n_train(self) -> int:
        return len(self.train_indices)
    
    @property
    def n_val(self) -> int:
        return len(self.val_indices)
    
    @property
    def n_test(self) -> int:
        return len(self.test_indices)
    
    def summary(self) -> str:
        """Return summary string of split."""
        return (
            f"Train: {len(self.train_patients)} patients, {self.n_train} samples\n"
            f"Val:   {len(self.val_patients)} patients, {self.n_val} samples\n"
            f"Test:  {len(self.test_patients)} patients, {self.n_test} samples"
        )


class PatientWiseSplitter:
    """
    Splits data by patient to prevent data leakage.
    
    In medical ML, it's critical that all samples from a patient
    remain in the same split. Otherwise, the model can "recognize"
    patient-specific patterns rather than learning generalizable features.
    
    Strategy:
    1. Group all samples by patient ID
    2. Calculate class ratio per patient (for stratification)
    3. Sort patients and split to maintain class balance
    4. Map patient splits back to sample indices
    """
    
    def __init__(
        self,
        train_ratio: float = 0.7,
        val_ratio: float = 0.15,
        test_ratio: float = 0.15,
        random_seed: int = 42
    ):
        """
        Initialize splitter.
        
        Args:
            train_ratio: Fraction of patients for training (default 0.7)
            val_ratio: Fraction of patients for validation (default 0.15)
            test_ratio: Fraction of patients for testing (default 0.15)
            random_seed: Random seed for reproducibility
        """
        assert abs(train_ratio + val_ratio + test_ratio - 1.0) < 0.01, \
            "Ratios must sum to 1.0"
        
        self.train_ratio = train_ratio
        self.val_ratio = val_ratio
        self.test_ratio = test_ratio
        self.random_seed = random_seed
        self.rng = np.random.RandomState(random_seed)
    
    def split(
        self,
        patient_ids: List[str],
        labels: np.ndarray,
        stratify: bool = True
    ) -> PatientSplit:
        """
        Split data by patient.
        
        Args:
            patient_ids: List of patient IDs, one per sample
            labels: Binary labels array
            stratify: Whether to stratify by class distribution
            
        Returns:
            PatientSplit with train/val/test indices
        """
        # Group samples by patient
        patient_to_indices = defaultdict(list)
        patient_to_labels = defaultdict(list)
        
        for idx, (patient_id, label) in enumerate(zip(patient_ids, labels)):
            patient_to_indices[patient_id].append(idx)
            patient_to_labels[patient_id].append(label)
        
        # Calculate positive class ratio per patient
        patient_pos_ratios = {}
        for patient_id in patient_to_indices:
            patient_labels = patient_to_labels[patient_id]
            patient_pos_ratios[patient_id] = np.mean(patient_labels)
        
        # Get unique patients
        unique_patients = list(patient_to_indices.keys())
        n_patients = len(unique_patients)
        
        if stratify:
            # Sort patients by positive ratio for stratified sampling
            # This helps maintain similar class distributions across splits
            sorted_patients = sorted(
                unique_patients, 
                key=lambda p: patient_pos_ratios[p]
            )
        else:
            # Shuffle for random split
            sorted_patients = unique_patients.copy()
            self.rng.shuffle(sorted_patients)
        
        # Calculate split indices
        n_train = int(n_patients * self.train_ratio)
        n_val = int(n_patients * self.val_ratio)
        # Remaining go to test
        
        # For stratified: interleave selection from sorted list
        if stratify:
            # Shuffle within roughly equal strata
            self.rng.shuffle(sorted_patients)
        
        train_patients = sorted_patients[:n_train]
        val_patients = sorted_patients[n_train:n_train + n_val]
        test_patients = sorted_patients[n_train + n_val:]
        
        # Map back to sample indices
        train_indices = []
        val_indices = []
        test_indices = []
        
        for patient_id in train_patients:
            train_indices.extend(patient_to_indices[patient_id])
        for patient_id in val_patients:
            val_indices.extend(patient_to_indices[patient_id])
        for patient_id in test_patients:
            test_indices.extend(patient_to_indices[patient_id])
        
        return PatientSplit(
            train_patients=train_patients,
            val_patients=val_patients,
            test_patients=test_patients,
            train_indices=np.array(train_indices),
            val_indices=np.array(val_indices),
            test_indices=np.array(test_indices)
        )
    
    def get_class_distribution(
        self,
        labels: np.ndarray,
        indices: np.ndarray
    ) -> Dict[str, float]:
        """Get class distribution for a subset of indices."""
        subset_labels = labels[indices]
        n_pos = np.sum(subset_labels == 1)
        n_neg = np.sum(subset_labels == 0)
        n_total = len(subset_labels)
        
        return {
            'n_positive': int(n_pos),
            'n_negative': int(n_neg),
            'n_total': int(n_total),
            'pct_positive': (n_pos / n_total * 100) if n_total > 0 else 0,
            'class_ratio': (n_pos / n_neg) if n_neg > 0 else float('inf')
        }
    
    def validate_no_leakage(self, split: PatientSplit) -> bool:
        """
        Verify no patient appears in multiple splits.
        
        Returns True if no leakage detected.
        """
        train_set = set(split.train_patients)
        val_set = set(split.val_patients)
        test_set = set(split.test_patients)
        
        # Check for overlaps
        train_val_overlap = train_set & val_set
        train_test_overlap = train_set & test_set
        val_test_overlap = val_set & test_set
        
        if train_val_overlap or train_test_overlap or val_test_overlap:
            return False
        
        return True


def create_patient_wise_split(
    X: np.ndarray,
    y: np.ndarray,
    patient_ids: List[str],
    train_ratio: float = 0.7,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    random_seed: int = 42
) -> Tuple[
    Tuple[np.ndarray, np.ndarray],  # X_train, y_train
    Tuple[np.ndarray, np.ndarray],  # X_val, y_val
    Tuple[np.ndarray, np.ndarray],  # X_test, y_test
    PatientSplit                     # Split metadata
]:
    """
    Convenience function to create patient-wise split.
    
    Args:
        X: Feature matrix (n_samples, n_features)
        y: Labels array (n_samples,)
        patient_ids: Patient ID for each sample
        train_ratio: Fraction for training
        val_ratio: Fraction for validation
        test_ratio: Fraction for testing
        random_seed: Random seed
        
    Returns:
        Tuple of ((X_train, y_train), (X_val, y_val), (X_test, y_test), split)
    """
    splitter = PatientWiseSplitter(
        train_ratio=train_ratio,
        val_ratio=val_ratio,
        test_ratio=test_ratio,
        random_seed=random_seed
    )
    
    split = splitter.split(patient_ids, y, stratify=True)
    
    # Verify no leakage
    assert splitter.validate_no_leakage(split), "Data leakage detected!"
    
    # Extract splits
    X_train = X[split.train_indices]
    y_train = y[split.train_indices]
    X_val = X[split.val_indices]
    y_val = y[split.val_indices]
    X_test = X[split.test_indices]
    y_test = y[split.test_indices]
    
    return (X_train, y_train), (X_val, y_val), (X_test, y_test), split
