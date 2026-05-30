#!/usr/bin/env python3
"""Parse test report JSON for quality gate evaluation."""
import json, sys


def parse(path: str) -> dict:
    with open(path) as f:
        data = json.load(f)
    return {
        "functional_coverage": data.get("functional_coverage", 0),
        "code_coverage": data.get("code_coverage", {}),
        "assertions_pass": data.get("assertions_pass", False),
        "uncovered_bins": data.get("uncovered_bins", []),
    }


if __name__ == "__main__":
    result = parse(sys.argv[1])
    print(json.dumps(result, indent=2))
