#!/bin/bash
# Guardian Angel - Arrhythmia Risk Model Environment Setup
# Compatible with macOS (Apple Silicon) and Linux

set -e

echo "=================================================="
echo "Guardian Angel - Environment Setup"
echo "Arrhythmia Risk Screening Model"
echo "=================================================="

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.10"

echo ""
echo "Checking Python version..."
echo "Found: Python $PYTHON_VERSION"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ Error: Python 3.10+ is required"
    exit 1
fi
echo "✅ Python version OK"

# Create virtual environment
echo ""
echo "Creating virtual environment..."
if [ -d "venv" ]; then
    echo "Virtual environment already exists. Removing..."
    rm -rf venv
fi

python3 -m venv venv
echo "✅ Virtual environment created"

# Activate virtual environment
echo ""
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo ""
echo "Installing dependencies..."
pip install -r requirements.txt

# Verify installation
echo ""
echo "Verifying installation..."
python -c "
import sys
print(f'Python: {sys.version}')

import numpy as np
print(f'NumPy: {np.__version__}')

import pandas as pd
print(f'Pandas: {pd.__version__}')

import scipy
print(f'SciPy: {scipy.__version__}')

import sklearn
print(f'Scikit-learn: {sklearn.__version__}')

import xgboost as xgb
print(f'XGBoost: {xgb.__version__}')

import wfdb
print(f'WFDB: {wfdb.__version__}')

print()
print('✅ All core dependencies installed successfully!')
"

# Check optional dependencies
echo ""
echo "Checking optional dependencies..."
python -c "
try:
    import antropy
    print(f'Antropy: {antropy.__version__} ✅')
except ImportError:
    print('Antropy: Not installed (optional)')

try:
    import matplotlib
    print(f'Matplotlib: {matplotlib.__version__} ✅')
except ImportError:
    print('Matplotlib: Not installed (optional)')
"

echo ""
echo "=================================================="
echo "✅ Environment setup complete!"
echo "=================================================="
echo ""
echo "To activate the environment, run:"
echo "  source venv/bin/activate"
echo ""
echo "To verify the setup, run:"
echo "  python -c \"import xgboost; import wfdb; print('Ready!')\""
echo ""
echo "Next steps:"
echo "  1. Download MIT-BIH data: python scripts/download_data.py"
echo "  2. Extract RR intervals:  python scripts/extract_rr_intervals.py"
echo "  3. Compute features:      python scripts/compute_features.py"
echo "  4. Train model:           python scripts/train_model.py"
echo ""
