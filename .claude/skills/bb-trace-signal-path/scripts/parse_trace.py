#!/usr/bin/env python3
"""Parse signal trace results and produce a summary report.

Reads the trace output JSON, validates the path, detects CDC crossings,
and produces a structured summary for the caller.
"""
import json
import sys
from pathlib import Path
from typing import Optional


def parse_trace(artifact_path: str, log_path: str) -> dict:
    """Parse and validate trace output.

    Args:
        artifact_path: Path to the trace result JSON.
        log_path: Path to the trace execution log.

    Returns:
        Summary dict with path, CDC status, and error info.
    """
    artifact = Path(artifact_path)
    log = Path(log_path)

    # Check artifact exists
    if not artifact.exists() or artifact.stat().st_size == 0:
        error = "TRACE_FILE_MISSING"
        if log.exists():
            log_text = log.read_text(errors="replace")
            if "TIMEOUT" in log_text:
                error = "trace depth exceeded"
            elif "path not found" in log_text:
                error = "path not found"
        return {
            "valid": False,
            "error": error,
            "path": [],
            "crosses_clock_domain": False,
            "artifact_path": artifact_path,
        }

    # Parse JSON
    try:
        data = json.loads(artifact.read_text())
    except json.JSONDecodeError as e:
        return {
            "valid": False,
            "error": f"JSON_PARSE_ERROR: {e}",
            "path": [],
            "crosses_clock_domain": False,
            "artifact_path": artifact_path,
        }

    path = data.get("path", [])
    crosses_cdc = data.get("crosses_clock_domain", False)
    source = data.get("source", "")
    sink = data.get("sink", "")

    # Validate path
    if not path:
        return {
            "valid": False,
            "error": "path not found",
            "path": [],
            "crosses_clock_domain": False,
            "source": source,
            "sink": sink,
            "artifact_path": artifact_path,
        }

    # Detect CDC transitions in path
    cdc_transitions = []
    prev_domain = None
    for i, node in enumerate(path):
        domain = node.get("clk_domain")
        if domain and prev_domain and domain != prev_domain:
            cdc_transitions.append({
                "index": i,
                "from_domain": prev_domain,
                "to_domain": domain,
                "signal": node.get("signal", ""),
                "module": node.get("module", ""),
            })
        if domain:
            prev_domain = domain

    return {
        "valid": True,
        "error": None,
        "source": source,
        "sink": sink,
        "path": path,
        "path_length": len(path),
        "crosses_clock_domain": crosses_cdc,
        "cdc_transitions": cdc_transitions,
        "design_name": data.get("design_name", ""),
        "artifact_path": artifact_path,
    }


def format_path_summary(path: list[dict]) -> str:
    """Format path as a human-readable string.

    Args:
        path: List of path node dicts.

    Returns:
        String like "M01.sig_a -> M02.sig_b -> M03.sig_c"
    """
    parts = []
    for node in path:
        module = node.get("module", "?")
        signal = node.get("signal", "?")
        parts.append(f"{module}.{signal}")
    return " -> ".join(parts)


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <artifact_path> <log_path>", file=sys.stderr)
        sys.exit(1)

    artifact_path = sys.argv[1]
    log_path = sys.argv[2]

    result = parse_trace(artifact_path, log_path)

    # Add human-readable path summary
    if result["path"]:
        result["path_summary"] = format_path_summary(result["path"])

    print(json.dumps(result, indent=2))

    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
