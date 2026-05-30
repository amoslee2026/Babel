#!/usr/bin/env python3
"""
Babel Traceability Wrapper

Wraps mySkills traceability scripts with Babel-specific paths.
Generates phase-scoped CSV matrices and validates traceability.

Usage:
    uv run scripts/babel_traceability.py <phase>
    uv run scripts/babel_traceability.py validate
    uv run scripts/babel_traceability.py sdc

Phases: prd, arch, impl, src, test, sdc
"""

import sys
import subprocess
import os
import re
import csv
from pathlib import Path

# Babel paths
PROJECT_ROOT = Path(__file__).parent.parent
TRACEABILITY_DIR = PROJECT_ROOT / "traceability"
MYSKILLS_DIR = Path.home() / "wrk" / "mySkills"

# mySkills scripts
GENERATE_SCRIPT = MYSKILLS_DIR / "scripts" / "generate_traceability_matrix.py"
VALIDATE_SCRIPT = MYSKILLS_DIR / "scripts" / "validate_traceability.py"

PHASES = ["prd", "arch", "impl", "src", "test", "sdc"]


def ensure_traceability_dir():
    """Ensure traceability directory exists."""
    TRACEABILITY_DIR.mkdir(parents=True, exist_ok=True)


def generate_sdc_matrix() -> int:
    """Scan SDC files and extract @requirement annotations into CSV."""
    ensure_traceability_dir()
    output_csv = TRACEABILITY_DIR / "requirements_matrix.sdc.csv"

    sdc_commands = [
        "create_clock", "set_input_delay", "set_output_delay",
        "set_false_path", "set_multicycle_path", "set_clock_groups",
        "set_max_delay", "set_min_delay", "set_clock_latency",
    ]

    rows = []
    designs_dir = PROJECT_ROOT / "designs"

    if not designs_dir.exists():
        print(f"Warning: designs directory not found: {designs_dir}")
        return 0

    for sdc_file in sorted(designs_dir.rglob("*.sdc")):
        lines = sdc_file.read_text().splitlines()
        design_name = sdc_file.parent.parent.name

        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("#") or not stripped:
                continue

            for cmd in sdc_commands:
                if cmd in stripped:
                    # Look back up to 5 lines for @requirement / @spec_ref
                    context = "\n".join(lines[max(0, i - 5):i])
                    req_match = re.findall(r'@requirement\s+([\w-]+(?:\s*,\s*[\w-]+)*)', context)
                    spec_match = re.search(r'@spec_ref\s+(\S+)', context)

                    req_ids = []
                    for m in req_match:
                        req_ids.extend([r.strip() for r in m.split(",")])

                    rows.append({
                        "req_id": ";".join(req_ids) if req_ids else "UNANNOTATED",
                        "source_file": str(sdc_file.relative_to(PROJECT_ROOT)),
                        "source_line": i + 1,
                        "sdc_command": cmd,
                        "sdc_line": stripped[:120],
                        "spec_ref": spec_match.group(1) if spec_match else "",
                        "design": design_name,
                        "status": "implemented" if req_ids else "missing_annotation",
                    })

    # Write CSV
    fieldnames = ["req_id", "source_file", "source_line", "sdc_command",
                  "sdc_line", "spec_ref", "design", "status"]

    with open(output_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    annotated = sum(1 for r in rows if r["status"] == "implemented")
    total = len(rows)
    print(f"✓ Generated: {output_csv}")
    print(f"  SDC commands: {total}, annotated: {annotated}, "
          f"coverage: {annotated/total*100:.1f}%" if total else "  No SDC commands found")
    return 0


def generate_matrix(phase: str) -> int:
    """Generate traceability matrix for a specific phase."""
    if phase not in PHASES:
        print(f"Error: Invalid phase '{phase}'. Must be one of: {PHASES}")
        return 1

    # SDC phase uses built-in scanner
    if phase == "sdc":
        return generate_sdc_matrix()

    ensure_traceability_dir()

    output_csv = TRACEABILITY_DIR / f"requirements_matrix.{phase}.csv"

    # Determine input based on phase
    if phase == "prd":
        input_path = PROJECT_ROOT / "spec" / "PRD"
    elif phase == "arch":
        input_path = PROJECT_ROOT / "spec" / "ARCH"
    elif phase == "impl":
        input_path = PROJECT_ROOT / "rtl" / "designs"
    elif phase == "src":
        input_path = PROJECT_ROOT / "rtl" / "designs"
    elif phase == "test":
        input_path = PROJECT_ROOT / "designs"

    if not GENERATE_SCRIPT.exists():
        print(f"Error: mySkills script not found: {GENERATE_SCRIPT}")
        print("Ensure mySkills is cloned at ~/wrk/mySkills/")
        return 1

    cmd = [
        "uv", "run", str(GENERATE_SCRIPT),
        "--phase", phase,
        "--input", str(input_path),
        "--output", str(output_csv)
    ]

    print(f"Generating {phase} matrix: {output_csv}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"Error generating matrix:\n{result.stderr}")
        return 1

    print(f"✓ Generated: {output_csv}")
    return 0


def validate_traceability() -> int:
    """Validate traceability across all phases."""
    ensure_traceability_dir()

    merged_csv = TRACEABILITY_DIR / "requirements_matrix.csv"

    if not VALIDATE_SCRIPT.exists():
        print(f"Error: mySkills script not found: {VALIDATE_SCRIPT}")
        return 1

    cmd = [
        "uv", "run", str(VALIDATE_SCRIPT),
        "--input-dir", str(TRACEABILITY_DIR),
        "--output", str(merged_csv)
    ]

    print(f"Validating and merging to: {merged_csv}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"Validation failed:\n{result.stderr}")
        return 1

    print(f"✓ Validation passed: {merged_csv}")
    return 0


def merge_csvs() -> int:
    """Merge all phase CSVs into a single matrix."""
    ensure_traceability_dir()

    merged_csv = TRACEABILITY_DIR / "requirements_matrix.csv"
    phase_csvs = []

    for phase in PHASES:
        csv_path = TRACEABILITY_DIR / f"requirements_matrix.{phase}.csv"
        if csv_path.exists():
            phase_csvs.append(csv_path)

    if not phase_csvs:
        print("Error: No phase CSVs found. Generate at least one phase first.")
        return 1

    # Simple merge: concatenate all CSVs (header from first, data from all)
    with open(merged_csv, "w") as out:
        for i, csv_path in enumerate(phase_csvs):
            with open(csv_path) as f:
                lines = f.readlines()
                if i == 0:
                    out.writelines(lines)  # Include header
                else:
                    out.writelines(lines[1:])  # Skip header

    print(f"✓ Merged {len(phase_csvs)} phase CSVs to: {merged_csv}")
    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: babel_traceability.py <phase|validate|merge>")
        print(f"Phases: {PHASES}")
        return 1

    command = sys.argv[1]

    if command == "validate":
        return validate_traceability()
    elif command == "merge":
        return merge_csvs()
    elif command in PHASES:
        return generate_matrix(command)
    else:
        print(f"Error: Unknown command '{command}'")
        print(f"Valid commands: {PHASES} | validate | merge")
        return 1


if __name__ == "__main__":
    sys.exit(main())
