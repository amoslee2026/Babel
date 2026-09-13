#!/usr/bin/env python3
"""Render gate-specific quality check configuration from artifact JSON."""
import json
import sys
from pathlib import Path


def render_config(gate_type: str, artifact: dict) -> dict:
    """Generate gate-specific check configuration."""
    configs = {
        "rtl": {
            "checks": ["lint_clean", "modules_nonempty", "file_list_valid"],
            "artifact_schema": "rtl_artifact.schema.json",
            "pass_criteria": "All lint checks pass, all modules present"
        },
        "test": {
            "checks": ["functional_coverage_100", "line_coverage_100", "branch_coverage_95", "toggle_coverage_90"],
            "artifact_schema": "test_report.schema.json",
            "pass_criteria": "Functional=100%, Line=100%, Branch>=95%, Toggle>=90%"
        },
        "synth": {
            "checks": ["timing_met", "area_reasonable", "cells_exist"],
            "artifact_schema": "synth_report.schema.json",
            "pass_criteria": "WNS>=0, area>0, cells>0"
        },
        "pd": {
            "checks": ["drc_clean", "lvs_clean", "timing_met"],
            "artifact_schema": "pd_report.schema.json",
            "pass_criteria": "DRC clean, LVS clean, WNS>=0"
        }
    }
    config = configs.get(gate_type, {})
    config["gate_type"] = gate_type
    config["artifact_summary"] = {
        "keys": list(artifact.keys()),
        "module_count": len(artifact.get("modules", [])),
    }
    return config


def main():
    if len(sys.argv) < 3:
        print("Usage: render_gate_config.py <gate_type> <artifact.json>", file=sys.stderr)
        sys.exit(1)
    gate_type = sys.argv[1]
    with open(sys.argv[2]) as f:
        artifact = json.load(f)
    config = render_config(gate_type, artifact)
    print(json.dumps(config, indent=2))


if __name__ == "__main__":
    main()
