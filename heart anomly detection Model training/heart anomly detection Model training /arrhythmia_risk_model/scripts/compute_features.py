#!/usr/bin/env python3
"""
Compute HRV Features

Extracts HRV features from processed RR intervals.
"""

import argparse
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
FEATURES_DIR = PROJECT_ROOT / "data" / "features"


def main():
    parser = argparse.ArgumentParser(
        description="Compute HRV features from RR intervals"
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=PROCESSED_DIR,
        help="Directory containing processed RR intervals"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=FEATURES_DIR,
        help="Output directory for computed features"
    )
    args = parser.parse_args()
    
    # TODO: Implement HRV feature computation pipeline
    print("HRV feature computation - Not yet implemented")
    print(f"Input: {args.input_dir}")
    print(f"Output: {args.output_dir}")


if __name__ == "__main__":
    main()
