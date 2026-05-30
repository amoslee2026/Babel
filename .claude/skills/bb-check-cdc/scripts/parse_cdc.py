#!/usr/bin/env python3
"""Parse CDC analysis results into structured findings."""
import json, sys
from pathlib import Path

def parse(report_path: str) -> dict:
    """Parse CDC report JSON and compute clean status."""
    try:
        with open(report_path) as f:
            report = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return {"valid": False, "error": str(e), "clean": False, "violations": []}

    violations = report.get("violations", [])
    unwaived = [v for v in violations if not v.get("waived", False)]

    return {
        "violations": violations,
        "violation_count": len(violations),
        "unwaived_count": len(unwaived),
        "clean": len(unwaived) == 0,
        "valid": True,
        "error": None,
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <cdc_report.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse(sys.argv[1]), indent=2))
