#!/usr/bin/env python3
"""Parse RTL artifact JSON for quality gate evaluation."""
import json, sys


def parse(path: str) -> dict:
    with open(path) as f:
        data = json.load(f)
    return {
        "modules": data.get("modules", []),
        "lint_pass": data.get("lint_results", {}).get("clean", False),
        "file_list_hash": data.get("file_list_sha256", ""),
        "iteration_count": data.get("iteration_count", 0),
    }


if __name__ == "__main__":
    result = parse(sys.argv[1])
    print(json.dumps(result, indent=2))
