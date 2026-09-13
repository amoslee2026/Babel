#!/usr/bin/env python3
"""
parse_sim_log.py -- Parse Verilator simulation log into structured JSON.

Phase 3 of bb-invoke-verilator: extracts pass/fail, assertion counts,
timing info from simulation log.
"""

import json
import re
import sys
from pathlib import Path


def parse(output_path: str) -> dict:
    """Parse Verilator simulation log and return structured results."""
    path = Path(output_path)
    if not path.exists():
        return {
            "status": "error",
            "valid": False,
            "error": "LOG_NOT_FOUND",
            "details": {},
        }

    text = path.read_text(errors="replace")

    # Extract exit code
    exit_match = re.search(r"exit:(\d+)", text)
    exit_code = int(exit_match.group(1)) if exit_match else None

    # Extract simulation time from $finish
    sim_time_ns = None
    time_match = re.search(r"\$finish at (\d+)", text)
    if time_match:
        sim_time_ns = int(time_match.group(1))

    # Check for errors
    error_lines = re.findall(r"%Error[^\n]*", text)
    has_errors = len(error_lines) > 0

    # Check for assertion failures
    assertion_failures = re.findall(r"Assertion failed[^\n]*", text)
    assertions_pass = len(assertion_failures) == 0 and not has_errors

    # Check for VERSION_MISMATCH
    version_mismatch = "VERSION_MISMATCH" in text

    # Check for timeout
    sim_timeout = "SIM_TIMEOUT" in text or (
        exit_code is not None and exit_code == 124
    )

    # Count PASS/FAIL markers (common in testbenches)
    pass_count = len(re.findall(r"\bPASS\b", text, re.IGNORECASE))
    fail_count = len(re.findall(r"\bFAIL\b", text, re.IGNORECASE))

    # Determine overall validity
    valid = (
        (exit_code == 0 if exit_code is not None else False)
        and not has_errors
        and not version_mismatch
        and not sim_timeout
    )

    # Build error string
    error = None
    if version_mismatch:
        error = "VERSION_MISMATCH"
    elif sim_timeout:
        error = "SIM_TIMEOUT"
    elif has_errors:
        error = error_lines[0][:200] if error_lines else "UNKNOWN_ERROR"
    elif exit_code is not None and exit_code != 0:
        error = f"EXIT_CODE_{exit_code}"

    return {
        "status": "parsed" if valid else "failed",
        "valid": valid,
        "assertions_pass": assertions_pass,
        "sim_time_ns": sim_time_ns,
        "exit_code": exit_code,
        "error": error,
        "details": {
            "error_count": len(error_lines),
            "assertion_failures": len(assertion_failures),
            "pass_markers": pass_count,
            "fail_markers": fail_count,
            "errors": [e[:200] for e in error_lines[:10]],
            "failed_assertions": [a[:200] for a in assertion_failures[:10]],
        },
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <output_file>", file=sys.stderr)
        sys.exit(1)
    result = parse(sys.argv[1])
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("valid") else 1)
