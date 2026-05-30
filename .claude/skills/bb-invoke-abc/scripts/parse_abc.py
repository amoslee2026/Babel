#!/usr/bin/env python3
"""Parse ABC optimization log and extract metrics."""
import json, re, sys
from pathlib import Path

def parse_abc_log(log_path: Path) -> dict:
    results = {"status": "unknown", "area": 0, "delay": 0, "gates": 0, "errors": []}
    if not log_path.exists():
        results["status"] = "error"
        results["errors"].append(f"Log not found: {log_path}")
        return results
    text = log_path.read_text()
    m = re.search(r"area\s*=\s*([\d.]+)", text)
    if m: results["area"] = float(m.group(1))
    m = re.search(r"delay\s*=\s*([\d.]+)", text)
    if m: results["delay"] = float(m.group(1))
    m = re.search(r"(\d+)\s*gates", text)
    if m: results["gates"] = int(m.group(1))
    results["status"] = "success" if not results["errors"] else "error"
    return results

if __name__ == "__main__":
    print(json.dumps(parse_abc_log(Path(sys.argv[1])), indent=2))
