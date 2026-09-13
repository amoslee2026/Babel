#!/usr/bin/env python3
"""Shared quality gate runner for Babel EDA flow.

Usage:
    python gate_runner.py <gate_type> <artifact_path> [--output <output_path>]

Gate types: rtl, test, synth, pd
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Field names below MUST match the inter-stage JSON schemas in .claude/schemas/.
# Cross-checked against rtl_artifact / test_report / synth_report / pd_report schemas.
# Coverage policy (CR-6): functional==100, line==100, branch>=95, toggle>=90.
GATE_CONFIGS = {
    "rtl": {
        "name": "RTL Quality Gate",
        # rtl_artifact.schema: lint flag is `lint_clean` (bool); file list is `file_list` (path string).
        "required_fields": ["modules", "lint_clean", "file_list"],
        "checks": {
            "lint_clean": lambda d: d.get("lint_clean", False) is True,
            "modules_nonempty": lambda d: len(d.get("modules", [])) > 0,
            "file_list_valid": lambda d: bool(d.get("file_list", "")),
        }
    },
    "test": {
        "name": "Test Quality Gate",
        "required_fields": ["functional_coverage", "code_coverage"],
        "checks": {
            "functional_coverage_100": lambda d: d.get("functional_coverage", 0) == 100,
            "line_coverage_100": lambda d: d.get("code_coverage", {}).get("line", 0) == 100,
            "branch_coverage_95": lambda d: d.get("code_coverage", {}).get("branch", 0) >= 95,
            "toggle_coverage_90": lambda d: d.get("code_coverage", {}).get("toggle", 0) >= 90,
        }
    },
    "synth": {
        "name": "Synthesis Quality Gate",
        # synth_report.schema: top-level worst-corner `wns_ns` plus per-corner `corners[].timing_met`.
        "required_fields": ["wns_ns", "area_um2", "cell_count", "corners"],
        "checks": {
            # Worst-corner WNS must close AND every signoff corner must meet timing.
            "timing_met": lambda d: d.get("wns_ns", -1) >= 0
            and bool(d.get("corners"))
            and all(c.get("timing_met", False) is True for c in d.get("corners", [])),
            "area_reasonable": lambda d: d.get("area_um2", 0) > 0,
            "cells_exist": lambda d: d.get("cell_count", 0) > 0,
        }
    },
    "pd": {
        "name": "PD Quality Gate",
        # pd_report.schema: `drc_violations` (int), `lvs_match` (bool), per-corner `timing_corners[]`.
        "required_fields": ["drc_violations", "lvs_match", "timing_corners"],
        "checks": {
            "drc_clean": lambda d: d.get("drc_violations", 1) == 0,
            "lvs_clean": lambda d: d.get("lvs_match", False) is True,
            # All signoff corners must meet timing (no flat wns_ns in pd_report).
            "timing_met": lambda d: bool(d.get("timing_corners"))
            and all(c.get("timing_met", False) is True for c in d.get("timing_corners", [])),
        }
    }
}


def run_gate(gate_type: str, artifact: dict) -> dict:
    config = GATE_CONFIGS.get(gate_type)
    if not config:
        return {"pass": False, "error": f"Unknown gate type: {gate_type}"}

    results = {}
    all_pass = True

    # Check required fields
    for field in config["required_fields"]:
        if field not in artifact:
            results[f"field_{field}"] = {"pass": False, "detail": f"Missing required field: {field}"}
            all_pass = False

    # Run checks
    for check_name, check_fn in config["checks"].items():
        try:
            passed = check_fn(artifact)
            results[check_name] = {"pass": bool(passed)}
            if not passed:
                all_pass = False
        except Exception as e:
            results[check_name] = {"pass": False, "detail": str(e)}
            all_pass = False

    return {
        "pass": all_pass,
        "gate_type": gate_type,
        "gate_name": config["name"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "checks": results,
        "summary": f"{sum(1 for v in results.values() if v['pass'])}/{len(results)} checks passed"
    }


def main():
    parser = argparse.ArgumentParser(description="Babel Quality Gate Runner")
    parser.add_argument("gate_type", choices=GATE_CONFIGS.keys(), help="Gate type")
    parser.add_argument("artifact_path", help="Path to artifact JSON file")
    parser.add_argument("--output", "-o", help="Output path (default: stdout)")
    args = parser.parse_args()

    try:
        with open(args.artifact_path) as f:
            artifact = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(json.dumps({"pass": False, "error": str(e)}))
        sys.exit(2)

    result = run_gate(args.gate_type, artifact)

    output = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output)
    print(output)

    sys.exit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
