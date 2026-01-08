#!/usr/bin/env python3
"""
Full Training Pipeline for Arrhythmia Risk Screening Model

This script executes the complete training pipeline:
1. Load all MIT-BIH records (excluding paced)
2. Extract RR intervals and create windows
3. Extract 15 HRV features per window
4. Label windows based on arrhythmia risk criteria
5. Patient-wise train/val/test split
6. Train XGBoost with early stopping
7. Evaluate on held-out test set
8. Save model and results

Usage:
    python scripts/train_model.py

Output:
    - Trained model: models/xgboost_arrhythmia_risk.json
    - Training report: reports/training_report.txt
"""

import sys
import time
from pathlib import Path
from datetime import datetime
import numpy as np

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from src.data import (
    MITBIHLoader,
    RRIntervalExtractor,
    RRPreprocessor,
    WindowLabeler,
    PACED_RECORDS
)
from src.features import HRVFeatureExtractor
from src.training import (
    PatientWiseSplitter,
    XGBoostTrainer,
    TrainingConfig,
    create_patient_wise_split
)


def main():
    """Main training pipeline."""
    print("=" * 70)
    print("ARRHYTHMIA RISK SCREENING MODEL - TRAINING PIPELINE")
    print("=" * 70)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Configuration
    DATASET_PATH = "dataset/mit-bih-arrhythmia-database-1.0.0"
    MODEL_OUTPUT = "models/xgboost_arrhythmia_risk"
    REPORT_OUTPUT = "reports/training_report.txt"
    RANDOM_SEED = 42
    
    # Initialize components
    print("Initializing pipeline components...")
    loader = MITBIHLoader(DATASET_PATH)
    rr_extractor = RRIntervalExtractor()
    preprocessor = RRPreprocessor(
        min_rr_ms=300,
        max_rr_ms=2000,
        window_size_sec=60,
        window_step_sec=30,
        min_beats_per_window=40
    )
    hrv_extractor = HRVFeatureExtractor()
    labeler = WindowLabeler()
    
    # Get all non-paced records
    all_records = MITBIHLoader.get_available_records(exclude_paced=False)
    records_to_use = [r for r in all_records if r not in PACED_RECORDS]
    print(f"Using {len(records_to_use)} records (excluding paced: {PACED_RECORDS})")
    print()
    
    # ==================================================================
    # STEP 1: Process all records
    # ==================================================================
    print("STEP 1: Processing records and extracting features...")
    print("-" * 50)
    
    all_features = []
    all_labels = []
    all_patient_ids = []
    all_windows = []
    
    start_time = time.time()
    
    for i, record_id in enumerate(records_to_use):
        # Load and process
        record = loader.load_record(record_id)
        rr_data = rr_extractor.extract(record)
        windows, stats = preprocessor.process_record(rr_data)
        
        # Filter valid windows
        valid_windows = [w for w in windows if w.is_valid]
        
        if len(valid_windows) == 0:
            print(f"  [{i+1:2d}/{len(records_to_use)}] Record {record_id}: No valid windows")
            continue
        
        # Extract features
        record_features = []
        for window in valid_windows:
            features = hrv_extractor.extract(window.rr_intervals_ms)
            if features.is_valid:
                record_features.append(features.to_array())
        
        if len(record_features) == 0:
            print(f"  [{i+1:2d}/{len(records_to_use)}] Record {record_id}: No valid features")
            continue
        
        # Label windows
        window_labels = labeler.label_windows(valid_windows)
        
        # Store results
        record_features = np.array(record_features)
        record_labels = np.array([lbl.label for lbl in window_labels[:len(record_features)]])
        
        all_features.append(record_features)
        all_labels.append(record_labels)
        all_patient_ids.extend([record_id] * len(record_features))
        all_windows.extend(valid_windows[:len(record_features)])
        
        n_risk = np.sum(record_labels == 1)
        pct_risk = n_risk / len(record_labels) * 100
        print(f"  [{i+1:2d}/{len(records_to_use)}] Record {record_id}: "
              f"{len(record_features)} windows, {n_risk} risk ({pct_risk:.0f}%)")
    
    # Combine all data
    X = np.vstack(all_features)
    y = np.concatenate(all_labels)
    
    processing_time = time.time() - start_time
    print()
    print(f"Processing complete in {processing_time:.1f}s")
    print(f"Total samples: {len(X)}")
    print(f"Total risk (label=1): {np.sum(y==1)} ({np.sum(y==1)/len(y)*100:.1f}%)")
    print(f"Total normal (label=0): {np.sum(y==0)} ({np.sum(y==0)/len(y)*100:.1f}%)")
    print()
    
    # ==================================================================
    # STEP 2: Patient-wise split
    # ==================================================================
    print("STEP 2: Creating patient-wise train/val/test split...")
    print("-" * 50)
    
    (X_train, y_train), (X_val, y_val), (X_test, y_test), split = create_patient_wise_split(
        X, y, all_patient_ids,
        train_ratio=0.7,
        val_ratio=0.15,
        test_ratio=0.15,
        random_seed=RANDOM_SEED
    )
    
    print(f"Train: {len(X_train)} samples from {len(split.train_patients)} patients")
    print(f"  Risk: {np.sum(y_train==1)} ({np.sum(y_train==1)/len(y_train)*100:.1f}%)")
    print(f"Val:   {len(X_val)} samples from {len(split.val_patients)} patients")
    print(f"  Risk: {np.sum(y_val==1)} ({np.sum(y_val==1)/len(y_val)*100:.1f}%)")
    print(f"Test:  {len(X_test)} samples from {len(split.test_patients)} patients")
    print(f"  Risk: {np.sum(y_test==1)} ({np.sum(y_test==1)/len(y_test)*100:.1f}%)")
    print()
    
    # ==================================================================
    # STEP 3: Train XGBoost
    # ==================================================================
    print("STEP 3: Training XGBoost model...")
    print("-" * 50)
    
    config = TrainingConfig(
        n_estimators=200,
        max_depth=4,
        learning_rate=0.05,
        early_stopping_rounds=20,
        random_seed=RANDOM_SEED
    )
    
    trainer = XGBoostTrainer(config)
    
    # Get feature names
    feature_names = hrv_extractor.FEATURE_NAMES
    
    results = trainer.train(
        X_train, y_train,
        X_val, y_val,
        feature_names=feature_names
    )
    
    print(f"Training complete in {results.training_time_sec:.1f}s")
    print(f"Best iteration: {results.best_iteration}")
    print()
    
    # ==================================================================
    # STEP 4: Evaluate on test set
    # ==================================================================
    print("STEP 4: Evaluating on test set...")
    print("-" * 50)
    
    results = trainer.evaluate(results, X_test, y_test)
    
    print(results.summary())
    print()
    
    # Feature importance
    print(trainer.get_feature_importance_report(results, top_n=10))
    print()
    
    # ==================================================================
    # STEP 5: Save model and report
    # ==================================================================
    print("STEP 5: Saving model and report...")
    print("-" * 50)
    
    # Create output directories
    Path("models").mkdir(exist_ok=True)
    Path("reports").mkdir(exist_ok=True)
    
    # Save model
    trainer.save_model(MODEL_OUTPUT)
    print(f"Model saved to: {MODEL_OUTPUT}.json")
    
    # Generate comprehensive report
    report_lines = [
        "=" * 70,
        "ARRHYTHMIA RISK SCREENING MODEL - TRAINING REPORT",
        "=" * 70,
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "DATASET",
        "-" * 40,
        f"Source: MIT-BIH Arrhythmia Database",
        f"Records used: {len(records_to_use)}",
        f"Excluded (paced): {PACED_RECORDS}",
        f"Total windows: {len(X)}",
        f"Features per window: {X.shape[1]}",
        "",
        "LABELING CRITERIA",
        "-" * 40,
        labeler.get_labeling_criteria_summary(),
        "",
        "DATA SPLIT (Patient-Wise)",
        "-" * 40,
        split.summary(),
        "",
        f"Train class distribution:",
        f"  Risk (1): {np.sum(y_train==1)} ({np.sum(y_train==1)/len(y_train)*100:.1f}%)",
        f"  Normal (0): {np.sum(y_train==0)} ({np.sum(y_train==0)/len(y_train)*100:.1f}%)",
        "",
        "MODEL CONFIGURATION",
        "-" * 40,
        f"Algorithm: XGBoost",
        f"n_estimators: {config.n_estimators}",
        f"max_depth: {config.max_depth}",
        f"learning_rate: {config.learning_rate}",
        f"early_stopping_rounds: {config.early_stopping_rounds}",
        f"Best iteration: {results.best_iteration}",
        "",
        "TEST SET RESULTS",
        "-" * 40,
        results.summary(),
        "",
        "FEATURE IMPORTANCE",
        "-" * 40,
        trainer.get_feature_importance_report(results, top_n=15),
        "",
        "=" * 70,
        "END OF REPORT",
        "=" * 70,
    ]
    
    report_text = "\n".join(report_lines)
    
    with open(REPORT_OUTPUT, 'w') as f:
        f.write(report_text)
    print(f"Report saved to: {REPORT_OUTPUT}")
    
    print()
    print("=" * 70)
    print("TRAINING PIPELINE COMPLETE")
    print("=" * 70)
    
    # Return key metrics for programmatic use
    return {
        'recall': results.test_recall,
        'specificity': results.confusion_matrix[0, 0] / (results.confusion_matrix[0, 0] + results.confusion_matrix[0, 1]),
        'roc_auc': results.test_roc_auc,
        'accuracy': results.test_accuracy
    }


if __name__ == "__main__":
    metrics = main()
    print(f"\nKey Metrics:")
    print(f"  Recall (Primary): {metrics['recall']:.4f}")
    print(f"  Specificity:      {metrics['specificity']:.4f}")
    print(f"  ROC-AUC:          {metrics['roc_auc']:.4f}")
