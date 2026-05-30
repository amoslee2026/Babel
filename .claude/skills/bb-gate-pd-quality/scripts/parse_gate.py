#!/usr/bin/env python3
"""Parse PD report JSON for quality gate evaluation."""
import json, sys
from pathlib import Path


def parse(drc_path: str, lvs_path: str, timing_path: str, gds_path: str) -> dict:
    with open(drc_path) as f:
        drc = json.load(f)
    with open(lvs_path) as f:
        lvs = json.load(f)
    with open(timing_path) as f:
        timing = json.load(f)

    gds = Path(gds_path)
    gds_exists = gds.exists() and gds.stat().st_size > 0

    corners = timing.get("corners", [])
    all_met = all(c.get("wns_ns", -1) >= 0 for c in corners)
    worst_wns = min((c.get("wns_ns", -1) for c in corners), default=-1)

    return {
        "drc_clean": drc.get("clean", False),
        "drc_violations": drc.get("violations", -1),
        "lvs_clean": lvs.get("match", False),
        "wns_ns": worst_wns,
        "timing_corners": corners,
        "timing_all_met": all_met,
        "gds_exists": gds_exists,
        "gds_size_bytes": gds.stat().st_size if gds_exists else 0,
    }


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: parse_gate.py <drc.json> <lvs.json> <timing.json> <gds_path>",
              file=sys.stderr)
        sys.exit(1)
    result = parse(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
    print(json.dumps(result, indent=2))
