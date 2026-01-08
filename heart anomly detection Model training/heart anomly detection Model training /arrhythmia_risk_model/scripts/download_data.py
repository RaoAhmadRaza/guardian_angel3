#!/usr/bin/env python3
"""
Download MIT-BIH Arrhythmia Database

Downloads the MIT-BIH Arrhythmia Database to data/raw/ directory.
"""

import argparse
from pathlib import Path

import wfdb

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"


def download_mitbih(output_dir: Path = RAW_DATA_DIR) -> None:
    """
    Download MIT-BIH Arrhythmia Database.
    
    Args:
        output_dir: Directory to save downloaded files
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Downloading MIT-BIH Arrhythmia Database to: {output_dir}")
    print("This may take several minutes...")
    
    # Download the database
    wfdb.dl_database("mitdb", dl_dir=str(output_dir))
    
    print(f"✅ Download complete! Files saved to: {output_dir}")
    
    # List downloaded records
    records = list(output_dir.glob("*.dat"))
    print(f"Downloaded {len(records)} records")


def main():
    parser = argparse.ArgumentParser(
        description="Download MIT-BIH Arrhythmia Database"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=RAW_DATA_DIR,
        help="Output directory for downloaded files"
    )
    args = parser.parse_args()
    
    download_mitbih(args.output_dir)


if __name__ == "__main__":
    main()
