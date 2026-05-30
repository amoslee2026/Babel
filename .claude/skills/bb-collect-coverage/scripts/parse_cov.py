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

    if dat_file.exists():
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
        return round(n / d * 100, 1) if d > 0 else 100.0

    return {
        "line_coverage": pct(line_covered, line_total),
        "branch_coverage": pct(branch_covered, branch_total),
        "toggle_coverage": pct(toggle_covered, toggle_total),
        "line_covered": line_covered, "line_total": line_total,
        "branch_covered": branch_covered, "branch_total": branch_total,
        "toggle_covered": toggle_covered, "toggle_total": toggle_total,
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <coverage_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse(sys.argv[1]), indent=2))
