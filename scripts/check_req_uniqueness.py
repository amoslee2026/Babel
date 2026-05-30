#!/usr/bin/env python3
"""Check REQ_ID uniqueness and immutability in traceability matrix.

Usage:
    uv run scripts/check_req_uniqueness.py
    uv run scripts/check_req_uniqueness.py --registry traceability/requirements_matrix.csv
    uv run scripts/check_req_uniqueness.py --check-deleted  # also check for deleted IDs
"""

import argparse
import csv
import subprocess
import sys
from collections import Counter
from pathlib import Path

REGISTRY_PATH = Path(__file__).parent.parent / "traceability" / "requirements_matrix.csv"


def check_uniqueness(csv_path: Path) -> tuple[bool, list[str]]:
    """Check for duplicate REQ_IDs."""
    req_ids = []
    if not csv_path.exists():
        return True, []

    with open(csv_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            req_id = row.get("req_id", "").strip()
            if req_id:
                req_ids.append(req_id)

    duplicates = [req_id for req_id, count in Counter(req_ids).items() if count > 1]
    unique = len(duplicates) == 0
    return unique, duplicates


def get_deleted_req_ids(csv_path: Path) -> tuple[bool, list[str]]:
    """Check if any REQ_IDs were deleted from CSV (should be deprecated, not deleted)."""
    if not csv_path.exists():
        return True, []

    # Get current REQ_IDs from working tree
    current_ids = set()
    with open(csv_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            req_id = row.get("req_id", "").strip()
            if req_id:
                current_ids.add(req_id)

    # Get REQ_IDs from last committed version
    try:
        result = subprocess.run(
            ["git", "show", f"HEAD:{csv_path.relative_to(Path.cwd())}"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            # File not in git history, skip
            return True, []

        committed_ids = set()
        reader = csv.DictReader(result.stdout.splitlines())
        for row in reader:
            req_id = row.get("req_id", "").strip()
            if req_id:
                committed_ids.add(req_id)

        deleted = sorted(committed_ids - current_ids)
        return len(deleted) == 0, deleted

    except (subprocess.SubprocessError, ValueError):
        return True, []


def main():
    parser = argparse.ArgumentParser(description="Check REQ_ID uniqueness")
    parser.add_argument(
        "--registry",
        type=Path,
        default=REGISTRY_PATH,
        help=f"Registry CSV path (default: {REGISTRY_PATH})",
    )
    parser.add_argument(
        "--check-deleted",
        action="store_true",
        help="Also check for deleted REQ_IDs (should be deprecated, not deleted)",
    )
    args = parser.parse_args()

    exit_code = 0

    # Check uniqueness
    unique, duplicates = check_uniqueness(args.registry)
    if unique:
        print(f"OK: All REQ_IDs are unique in {args.registry}")
    else:
        print(f"ERROR: Duplicate REQ_IDs found: {duplicates}", file=sys.stderr)
        exit_code = 1

    # Check deletions
    if args.check_deleted:
        no_deletions, deleted = get_deleted_req_ids(args.registry)
        if no_deletions:
            print("OK: No REQ_IDs were deleted")
        else:
            print(
                f"WARNING: REQ_IDs were deleted (should mark as 'deprecated' instead): {deleted}",
                file=sys.stderr,
            )
            exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
