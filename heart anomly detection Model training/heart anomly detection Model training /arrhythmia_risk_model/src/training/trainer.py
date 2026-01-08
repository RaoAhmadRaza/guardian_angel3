"""
XGBoost Model Trainer for Arrhythmia Risk Screening

Handles XGBoost model training with:
- Configurable hyperparameters
- Early stopping on validation set
- Class imbalance handling via scale_pos_weight
- Model checkpointing and export

For wearable screening, we prioritize:
1. RECALL (catch true positives - miss no at-risk cases)
2. Specificity (avoid false alarms, but less critical)
3. ROC-AUC (overall discriminative ability)
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
import numpy as np
import json
from pathlib import Path
from datetime import datetime

try:
    import xgboost as xgb
    HAS_XGBOOST = True
except ImportError:
    HAS_XGBOOST = False
    xgb = None

from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix, classification_report
)


@dataclass
class TrainingConfig:
    """
    XGBoost training configuration.
    
    Defaults are tuned for arrhythmia risk screening:
    - Moderate tree complexity (max_depth=4)
    - Low learning rate for stability
    - Early stopping to prevent overfitting
    - Class weight balancing
    """
    # XGBoost core parameters
    n_estimators: int = 200
    max_depth: int = 4
    learning_rate: float = 0.05
    min_child_weight: int = 3
    subsample: float = 0.8
    colsample_bytree: float = 0.8
    
    # Regularization
    reg_alpha: float = 0.1  # L1 regularization
    reg_lambda: float = 1.0  # L2 regularization
    gamma: float = 0.1  # Min loss reduction for split
    
    # Training settings
    early_stopping_rounds: int = 20
    eval_metric: str = "auc"  # Use AUC for imbalanced data
    
    # Class imbalance
    auto_class_weight: bool = True  # Auto-calculate scale_pos_weight
    
    # Reproducibility
    random_seed: int = 42
    
    # Hardware
    tree_method: str = "hist"  # CPU-optimized; use "gpu_hist" for GPU
    n_jobs: int = -1


@dataclass
class TrainingResults:
    """
    Container for training results and metrics.
    """
    # Model
    model: Optional[object] = None  # XGBoost model
    
    # Training history
    train_metrics: Dict[str, List[float]] = field(default_factory=dict)
    val_metrics: Dict[str, List[float]] = field(default_factory=dict)
    best_iteration: int = 0
    
    # Final evaluation metrics
    test_accuracy: float = 0.0
    test_precision: float = 0.0
    test_recall: float = 0.0
    test_f1: float = 0.0
    test_roc_auc: float = 0.0
    confusion_matrix: Optional[np.ndarray] = None
    
    # Feature importance
    feature_importance: Dict[str, float] = field(default_factory=dict)
    
    # Metadata
    training_time_sec: float = 0.0
    config: Optional[TrainingConfig] = None
    
    def summary(self) -> str:
        """Return summary string of results."""
        cm = self.confusion_matrix
        tn, fp, fn, tp = cm.ravel() if cm is not None else (0, 0, 0, 0)
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
        
        return f"""
TRAINING RESULTS
================
Best iteration: {self.best_iteration}
Training time: {self.training_time_sec:.1f}s

TEST SET METRICS:
  Accuracy:    {self.test_accuracy:.4f}
  Precision:   {self.test_precision:.4f}
  Recall:      {self.test_recall:.4f}  <- PRIMARY (catch at-risk cases)
  Specificity: {specificity:.4f}
  F1 Score:    {self.test_f1:.4f}
  ROC-AUC:     {self.test_roc_auc:.4f}

CONFUSION MATRIX:
  TN={tn}, FP={fp}
  FN={fn}, TP={tp}
"""


class XGBoostTrainer:
    """
    XGBoost trainer for arrhythmia risk screening.
    
    Designed for binary classification:
    - Class 0: Low risk (normal rhythm)
    - Class 1: Elevated risk (arrhythmia indicators)
    
    Prioritizes recall to minimize missed cases while
    maintaining acceptable specificity.
    """
    
    def __init__(self, config: Optional[TrainingConfig] = None):
        """
        Initialize trainer.
        
        Args:
            config: TrainingConfig with hyperparameters
        """
        if not HAS_XGBOOST:
            raise ImportError("XGBoost not installed. Run: pip install xgboost")
        
        self.config = config or TrainingConfig()
        self.model = None
        self.feature_names: List[str] = []
    
    def train(
        self,
        X_train: np.ndarray,
        y_train: np.ndarray,
        X_val: np.ndarray,
        y_val: np.ndarray,
        feature_names: Optional[List[str]] = None
    ) -> TrainingResults:
        """
        Train XGBoost model.
        
        Args:
            X_train: Training features
            y_train: Training labels
            X_val: Validation features (for early stopping)
            y_val: Validation labels
            feature_names: Optional list of feature names
            
        Returns:
            TrainingResults with model and metrics
        """
        import time
        start_time = time.time()
        
        # Store feature names
        self.feature_names = feature_names or [f"f{i}" for i in range(X_train.shape[1])]
        
        # Calculate class weight for imbalance
        if self.config.auto_class_weight:
            n_neg = np.sum(y_train == 0)
            n_pos = np.sum(y_train == 1)
            scale_pos_weight = n_neg / n_pos if n_pos > 0 else 1.0
        else:
            scale_pos_weight = 1.0
        
        # Build XGBoost parameters
        params = {
            'objective': 'binary:logistic',
            'eval_metric': self.config.eval_metric,
            'max_depth': self.config.max_depth,
            'learning_rate': self.config.learning_rate,
            'min_child_weight': self.config.min_child_weight,
            'subsample': self.config.subsample,
            'colsample_bytree': self.config.colsample_bytree,
            'reg_alpha': self.config.reg_alpha,
            'reg_lambda': self.config.reg_lambda,
            'gamma': self.config.gamma,
            'scale_pos_weight': scale_pos_weight,
            'tree_method': self.config.tree_method,
            'random_state': self.config.random_seed,
            'n_jobs': self.config.n_jobs,
        }
        
        # Create DMatrix
        dtrain = xgb.DMatrix(X_train, label=y_train, feature_names=self.feature_names)
        dval = xgb.DMatrix(X_val, label=y_val, feature_names=self.feature_names)
        
        # Training with early stopping
        evals = [(dtrain, 'train'), (dval, 'val')]
        evals_result = {}
        
        self.model = xgb.train(
            params,
            dtrain,
            num_boost_round=self.config.n_estimators,
            evals=evals,
            evals_result=evals_result,
            early_stopping_rounds=self.config.early_stopping_rounds,
            verbose_eval=False
        )
        
        training_time = time.time() - start_time
        
        # Extract training history
        train_metrics = {k: list(v) for k, v in evals_result.get('train', {}).items()}
        val_metrics = {k: list(v) for k, v in evals_result.get('val', {}).items()}
        
        # Get feature importance
        importance = self.model.get_score(importance_type='gain')
        feature_importance = {
            self.feature_names[int(k[1:])] if k.startswith('f') else k: v 
            for k, v in importance.items()
        }
        
        results = TrainingResults(
            model=self.model,
            train_metrics=train_metrics,
            val_metrics=val_metrics,
            best_iteration=self.model.best_iteration,
            feature_importance=feature_importance,
            training_time_sec=training_time,
            config=self.config
        )
        
        return results
    
    def evaluate(
        self,
        results: TrainingResults,
        X_test: np.ndarray,
        y_test: np.ndarray,
        threshold: float = 0.5
    ) -> TrainingResults:
        """
        Evaluate model on test set.
        
        Args:
            results: TrainingResults from training
            X_test: Test features
            y_test: Test labels
            threshold: Classification threshold (default 0.5)
            
        Returns:
            Updated TrainingResults with test metrics
        """
        if self.model is None:
            raise ValueError("Model not trained. Call train() first.")
        
        # Predict
        dtest = xgb.DMatrix(X_test, feature_names=self.feature_names)
        y_prob = self.model.predict(dtest)
        y_pred = (y_prob >= threshold).astype(int)
        
        # Calculate metrics
        results.test_accuracy = accuracy_score(y_test, y_pred)
        results.test_precision = precision_score(y_test, y_pred, zero_division=0)
        results.test_recall = recall_score(y_test, y_pred, zero_division=0)
        results.test_f1 = f1_score(y_test, y_pred, zero_division=0)
        results.test_roc_auc = roc_auc_score(y_test, y_prob)
        results.confusion_matrix = confusion_matrix(y_test, y_pred)
        
        return results
    
    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        """
        Get probability predictions.
        
        Args:
            X: Feature matrix
            
        Returns:
            Array of probabilities for class 1
        """
        if self.model is None:
            raise ValueError("Model not trained. Call train() first.")
        
        dmatrix = xgb.DMatrix(X, feature_names=self.feature_names)
        return self.model.predict(dmatrix)
    
    def predict(self, X: np.ndarray, threshold: float = 0.5) -> np.ndarray:
        """
        Get class predictions.
        
        Args:
            X: Feature matrix
            threshold: Classification threshold
            
        Returns:
            Array of predicted classes (0 or 1)
        """
        proba = self.predict_proba(X)
        return (proba >= threshold).astype(int)
    
    def save_model(self, path: str) -> None:
        """
        Save trained model to file.
        
        Args:
            path: Path to save model (without extension)
        """
        if self.model is None:
            raise ValueError("Model not trained. Call train() first.")
        
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        
        # Save model in XGBoost format
        self.model.save_model(str(path) + '.json')
        
        # Save feature names
        meta = {
            'feature_names': self.feature_names,
            'config': {
                'n_estimators': self.config.n_estimators,
                'max_depth': self.config.max_depth,
                'learning_rate': self.config.learning_rate,
            },
            'saved_at': datetime.now().isoformat()
        }
        with open(str(path) + '_meta.json', 'w') as f:
            json.dump(meta, f, indent=2)
    
    def load_model(self, path: str) -> None:
        """
        Load trained model from file.
        
        Args:
            path: Path to model (without extension)
        """
        self.model = xgb.Booster()
        self.model.load_model(str(path) + '.json')
        
        # Load feature names
        with open(str(path) + '_meta.json', 'r') as f:
            meta = json.load(f)
        self.feature_names = meta['feature_names']
    
    def get_feature_importance_report(
        self, 
        results: TrainingResults,
        top_n: int = 10
    ) -> str:
        """
        Generate feature importance report.
        
        Args:
            results: TrainingResults with feature importance
            top_n: Number of top features to show
            
        Returns:
            Formatted string report
        """
        importance = results.feature_importance
        sorted_features = sorted(
            importance.items(), 
            key=lambda x: x[1], 
            reverse=True
        )
        
        lines = ["FEATURE IMPORTANCE (by gain)", "=" * 40]
        for i, (name, score) in enumerate(sorted_features[:top_n]):
            lines.append(f"{i+1:2d}. {name:20s}: {score:.4f}")
        
        return "\n".join(lines)
