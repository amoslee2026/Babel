#!/usr/bin/env python3
"""Parse synthesis report JSON for quality gate evaluation."""
import json, sys


def parse(path: str) -> dict:
    with open(path) as f:
        data = json.load(f)
    return {
        "wns_ns": data.get("wns_ns", -1),
        "area_um2": data.get("area_um2", 0),
        "cell_count": data.get("cell_count", 0),
        "cdc_clean": data.get("cdc_clean", False),
    }


if __name__ == "__main__":
    result = parse(sys.argv[1])
    print(json.dumps(result, indent=2))
