#!/usr/bin/env python3
"""
Extract RR Intervals from MIT-BIH Records

Processes raw MIT-BIH records and extracts RR intervals.
"""

import argparse
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"


def main():
    parser = argparse.ArgumentParser(
        description="Extract RR intervals from MIT-BIH records"
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=RAW_DATA_DIR,
        help="Directory containing raw MIT-BIH records"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=PROCESSED_DIR,
        help="Output directory for processed RR intervals"
    )
    args = parser.parse_args()
    
    # TODO: Implement RR extraction pipeline
    print("RR interval extraction - Not yet implemented")
    print(f"Input: {args.input_dir}")
    print(f"Output: {args.output_dir}")


if __name__ == "__main__":
    main()
