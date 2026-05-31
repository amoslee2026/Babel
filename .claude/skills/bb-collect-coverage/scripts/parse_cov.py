#!/usr/bin/env python3
"""Parse Verilator coverage data into structured JSON."""
import json, re, sys
from pathlib import Path

def parse(coverage_dir: str) -> dict:
    cov_dir = Path(coverage_dir)
    # Parse coverage.dat if it exists
    dat_file = cov_dir / "coverage.dat"
    line_covered = 0
    line_total = 0
    branch_covered = 0
    branch_total = 0
    toggle_covered = 0
    toggle_total = 0

    # Fail CLOSED: missing coverage data must NEVER be reported as 100%.
    if not dat_file.exists():
        return {
            "valid": False,
            "status": "error",
            "error": f"coverage data file not found: {dat_file}",
            "meets_target": False,
            "line_coverage": None,
            "branch_coverage": None,
            "toggle_coverage": None,
            "line_covered": 0, "line_total": 0,
            "branch_covered": 0, "branch_total": 0,
            "toggle_covered": 0, "toggle_total": 0,
        }

    for line in dat_file.read_text(errors="replace").splitlines():
        if line.startswith("L"):
            parts = line.split()
            if len(parts) >= 3:
                count = int(parts[1]) if parts[1].isdigit() else 0
                line_total += 1
                if count > 0:
                    line_covered += 1
        elif line.startswith("B"):
            parts = line.split()
            if len(parts) >= 3:
                count = int(parts[1]) if parts[1].isdigit() else 0
                branch_total += 1
                if count > 0:
                    branch_covered += 1
        elif line.startswith("T"):
            parts = line.split()
            if len(parts) >= 3:
                count = int(parts[1]) if parts[1].isdigit() else 0
                toggle_total += 1
                if count > 0:
                    toggle_covered += 1

    def pct(n, d):
        # Fail CLOSED: no measurable data (d==0) is 0%, never 100%.
        return round(n / d * 100, 1) if d > 0 else 0.0

    line_cov = pct(line_covered, line_total)
    branch_cov = pct(branch_covered, branch_total)
    toggle_cov = pct(toggle_covered, toggle_total)
    meets_target = (line_cov >= 100.0 and branch_cov >= 100.0 and toggle_cov >= 100.0)

    return {
        "valid": True,
        "status": "ok",
        "error": None,
        "meets_target": meets_target,
        "line_coverage": line_cov,
        "branch_coverage": branch_cov,
        "toggle_coverage": toggle_cov,
        "line_covered": line_covered, "line_total": line_total,
        "branch_covered": branch_covered, "branch_total": branch_total,
        "toggle_covered": toggle_covered, "toggle_total": toggle_total,
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <coverage_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse(sys.argv[1]), indent=2))
