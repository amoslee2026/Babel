#!/usr/bin/env python3
"""Parse floorplan output from Magic and extract key metrics."""
import json, re, sys
from pathlib import Path

def parse_magic_log(log_path: Path) -> dict:
    results = {"status": "unknown", "die_area_um2": 0, "utilization": 0,
               "io_pads_placed": 0, "errors": []}
    if not log_path.exists():
        results["status"] = "error"
        results["errors"].append(f"Log not found: {log_path}")
        return results
    text = log_path.read_text()
    m = re.search(r"Die area:\s*([\d.]+)\s*x\s*([\d.]+)\s*um", text)
    if m:
        results["die_area_um2"] = round(float(m.group(1)) * float(m.group(2)), 2)
    m = re.search(r"Utilization:\s*([\d.]+)%", text)
    if m:
        results["utilization"] = float(m.group(1))
    results["io_pads_placed"] = len(re.findall(r"Placed IO pad:", text))
    results["status"] = "success" if not results["errors"] else "error"
    return results

if __name__ == "__main__":
    print(json.dumps(parse_magic_log(Path(sys.argv[1])), indent=2))
