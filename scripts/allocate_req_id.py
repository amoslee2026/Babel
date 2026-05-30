#!/usr/bin/env python3
"""Allocate next REQ_ID for a module.

Usage:
    uv run scripts/allocate_req_id.py M01
    uv run scripts/allocate_req_id.py M01 --category F  # default
    uv run scripts/allocate_req_id.py M01 --category P  # performance
    uv run scripts/allocate_req_id.py M01 --category I  # DFT/scan
    uv run scripts/allocate_req_id.py M01 --category C  # constraint
"""

import argparse
import csv
import sys
from pathlib import Path

REGISTRY_PATH = Path(__file__).parent.parent / "traceability" / "requirements_matrix.csv"

# Category mappings for REQ_ID format
CATEGORY_PREFIX = {
    "F": "F",   # Functional
    "P": "P",   # Performance
    "I": "I",   # DFT/Implementation
    "C": "C",   # Constraint
}

VALID_CATEGORIES = set(CATEGORY_PREFIX.keys())


def read_existing_ids(module_id: str, category: str) -> set[int]:
    """Read existing REQ_ID numbers for a module and category."""
    existing = set()
    prefix = f"REQ-M{module_id}-{CATEGORY_PREFIX[category]}"

    if not REGISTRY_PATH.exists():
        return existing

    with open(REGISTRY_PATH, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            req_id = row.get("req_id", "")
            if req_id.startswith(prefix):
                try:
                    # Extract numeric part after category prefix
                    num_part = req_id.split(prefix)[1]
                    existing.add(int(num_part))
                except (IndexError, ValueError):
                    continue

    return existing


def allocate_next(module_id: str, category: str = "F") -> str:
    """Allocate the next available REQ_ID for a module."""
    if not module_id.isdigit() or len(module_id) != 2:
        raise ValueError(f"module_id must be 2-digit string (e.g., '01'), got '{module_id}'")

    if category not in VALID_CATEGORIES:
        raise ValueError(f"category must be one of {VALID_CATEGORIES}, got '{category}'")

    existing = read_existing_ids(module_id, category)

    # Find next available number
    next_num = 1
    while next_num in existing:
        next_num += 1

    # Check namespace limit (99 max for 2-digit)
    if next_num > 99:
        prefix = f"REQ-M{module_id}-{CATEGORY_PREFIX[category]}"
        raise ValueError(f"Module M{module_id} exhausted {prefix}## namespace (99 max)")

    prefix_char = CATEGORY_PREFIX[category]
    return f"REQ-M{module_id}-{prefix_char}{next_num:02d}"


def main():
    parser = argparse.ArgumentParser(description="Allocate next REQ_ID")
    parser.add_argument("module_id", help="Module ID (2-digit, e.g., 01)")
    parser.add_argument(
        "--category",
        default="F",
        choices=sorted(VALID_CATEGORIES),
        help="REQ category (default: F)",
    )
    parser.add_argument(
        "--registry",
        type=Path,
        default=REGISTRY_PATH,
        help=f"Registry CSV path (default: {REGISTRY_PATH})",
    )
    args = parser.parse_args()

    try:
        req_id = allocate_next(args.module_id, args.category)
        print(req_id)
        return 0
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
