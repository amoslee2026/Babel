#!/usr/bin/env python3
"""
parse_lvs.py -- Parse Netgen LVS report into structured JSON.

Phase 3 of bb-invoke-netgen: extracts match/mismatch status,
device count differences, and detailed discrepancies.
"""

import json
import re
import sys
from pathlib import Path


def parse_discrepancies(text: str) -> list[dict]:
    """Extract detailed discrepancies from LVS report."""
    discrepancies = []

    # Net mismatches
    net_pattern = re.compile(
        r"Net mismatch.*?schematic:\s*(\S+).*?layout:\s*(\S+)",
        re.DOTALL | re.IGNORECASE,
    )
    for m in net_pattern.finditer(text):
        discrepancies.append({
            "kind": "net_mismatch",
            "schematic": m.group(1),
            "layout": m.group(2),
            "instance": "",
        })

    # Device mismatches
    dev_pattern = re.compile(
        r"Device mismatch.*?schematic:\s*(\S+).*?layout:\s*(\S+)",
        re.DOTALL | re.IGNORECASE,
    )
    for m in dev_pattern.finditer(text):
        discrepancies.append({
            "kind": "device_mismatch",
            "schematic": m.group(1),
            "layout": m.group(2),
            "instance": "",
        })

    # Instance count differences
    inst_pattern = re.compile(
        r"(\S+)\s+(\d+)\s+(\d+)\s+different",
        re.IGNORECASE,
    )
    for m in inst_pattern.finditer(text):
        discrepancies.append({
            "kind": "count_difference",
            "instance": m.group(1),
            "schematic": int(m.group(2)),
            "layout": int(m.group(3)),
        })

    # Pin/port mismatches
    pin_pattern = re.compile(
        r"Pin (mismatch|missing).*?(\S+)",
        re.IGNORECASE,
    )
    for m in pin_pattern.finditer(text):
        discrepancies.append({
            "kind": f"pin_{m.group(1).lower()}",
            "instance": m.group(2),
            "schematic": "",
            "layout": "",
        })

    return discrepancies


def parse_device_summary(text: str) -> dict:
    """Extract device count summary from LVS report."""
    summary = {"schematic": {}, "layout": {}}

    # Look for device summary tables
    # Pattern: "Device type      Schematic count   Layout count"
    dev_table = re.findall(
        r"(\w+)\s+(\d+)\s+(\d+)",
        text,
    )
    for dev_type, sch_count, lay_count in dev_table:
        if dev_type.lower() not in ("total", "summary"):
            summary["schematic"][dev_type] = int(sch_count)
            summary["layout"][dev_type] = int(lay_count)

    return summary


def parse(output_path: str) -> dict:
    """Parse Netgen LVS report and return structured results."""
    path = Path(output_path)
    if not path.exists():
        return {
            "status": "error",
            "valid": False,
            "match": False,
            "error": "REPORT_NOT_FOUND",
        }

    text = path.read_text(errors="replace")

    # Check for unique match
    match = bool(re.search(r"Circuits match uniquely", text, re.IGNORECASE))

    # Check for differences
    differ = bool(re.search(r"Circuits differ", text, re.IGNORECASE))

    # Check for exit code in log
    exit_match = re.search(r"exit:(\d+)", text)
    exit_code = int(exit_match.group(1)) if exit_match else None

    # Version mismatch
    if "VERSION_MISMATCH" in text:
        return {
            "status": "error",
            "valid": False,
            "match": False,
            "error": "VERSION_MISMATCH",
        }

    # Parse discrepancies
    discrepancies = parse_discrepancies(text)
    device_summary = parse_device_summary(text)

    valid = (
        (exit_code == 0 if exit_code is not None else True)
        and not differ
    )

    error = None
    if not match and not differ:
        error = "INCONCLUSIVE_LVS_RESULT"
    elif differ:
        error = f"LVS_MISMATCH: {len(discrepancies)} discrepancies"

    return {
        "status": "parsed",
        "valid": valid,
        "match": match,
        "discrepancies": discrepancies[:50],  # Limit output
        "discrepancy_count": len(discrepancies),
        "device_summary": device_summary,
        "error": error,
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <lvs_report>", file=sys.stderr)
        sys.exit(1)
    result = parse(sys.argv[1])
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("match") else 1)
