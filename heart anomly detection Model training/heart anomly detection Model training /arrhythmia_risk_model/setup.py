"""
Guardian Angel - Arrhythmia Risk Screening Model

Setup configuration for package installation.
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as f:
    long_description = f.read()

setup(
    name="guardian_angel_arrhythmia",
    version="0.1.0",
    author="Guardian Angel Team",
    description="XGBoost-based arrhythmia risk screening using HRV features",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/guardian-angel/arrhythmia-risk-model",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=3.10",
    install_requires=[
        "numpy>=1.24.0,<2.0.0",
        "pandas>=2.0.0,<3.0.0",
        "scipy>=1.11.0,<2.0.0",
        "wfdb>=4.1.0,<5.0.0",
        "scikit-learn>=1.3.0,<2.0.0",
        "xgboost>=2.0.0,<3.0.0",
        "pyyaml>=6.0.0,<7.0.0",
        "joblib>=1.3.0,<2.0.0",
        "loguru>=0.7.0,<1.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.0,<8.0.0",
            "pytest-cov>=4.1.0,<5.0.0",
            "matplotlib>=3.7.0,<4.0.0",
            "seaborn>=0.13.0,<1.0.0",
        ],
        "entropy": [
            "antropy>=0.1.6",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Healthcare Industry",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Scientific/Engineering :: Medical Science Apps.",
    ],
    entry_points={
        "console_scripts": [
            "ga-download-data=scripts.download_data:main",
            "ga-extract-rr=scripts.extract_rr_intervals:main",
            "ga-compute-features=scripts.compute_features:main",
            "ga-train=scripts.train_model:main",
            "ga-evaluate=scripts.evaluate_model:main",
            "ga-export=scripts.export_model:main",
        ],
    },
)
