"""
Reproducibility Utilities

Ensures deterministic behavior across runs.
"""

import os
import random
from typing import Optional

import numpy as np


def set_seed(seed: int = 42) -> None:
    """
    Set random seed for reproducibility across all libraries.
    
    Args:
        seed: Random seed value (default: 42)
    """
    # Python random
    random.seed(seed)
    
    # NumPy
    np.random.seed(seed)
    
    # Environment variable for hash seed
    os.environ["PYTHONHASHSEED"] = str(seed)
    
    # Note: XGBoost uses seed parameter directly in model initialization


def get_reproducibility_info() -> dict:
    """
    Get information about current reproducibility settings.
    
    Returns:
        Dictionary with package versions and seed info
    """
    import xgboost
    import sklearn
    import scipy
    import pandas
    
    return {
        "numpy_version": np.__version__,
        "pandas_version": pandas.__version__,
        "scipy_version": scipy.__version__,
        "sklearn_version": sklearn.__version__,
        "xgboost_version": xgboost.__version__,
        "python_hash_seed": os.environ.get("PYTHONHASHSEED", "not set")
    }
