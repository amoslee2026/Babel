#!/usr/bin/env python3
"""Parse fallback AST results and validate output against common schema.

Checks that the generated AST JSON exists, is valid JSON,
conforms to the expected schema, and reports the backend used.
"""
import json
import re
import sys
from pathlib import Path


REQUIRED_TOP_LEVEL_KEYS = {"modules", "node_count", "serialized"}
REQUIRED_MODULE_KEYS = {"name", "ports"}


def validate_schema(data: dict) -> list[str]:
    """Validate AST JSON against the expected schema.

    Args:
        data: Parsed AST JSON dict.

    Returns:
        List of validation error strings. Empty if valid.
    """
    errors = []

    if not isinstance(data, dict):
        return ["root is not a dict"]

    missing_keys = REQUIRED_TOP_LEVEL_KEYS - set(data.keys())
    if missing_keys:
        errors.append(f"missing top-level keys: {missing_keys}")

    modules = data.get("modules", [])
    if not isinstance(modules, list):
        errors.append("modules is not a list")
        return errors

    for i, mod in enumerate(modules):
        if not isinstance(mod, dict):
            errors.append(f"module[{i}] is not a dict")
            continue
        mod_missing = REQUIRED_MODULE_KEYS - set(mod.keys())
        if mod_missing:
            errors.append(f"module[{i}] missing keys: {mod_missing}")

    return errors


def detect_backend(log_text: str) -> str:
    """Detect which backend was actually used from log content.

    Args:
        log_text: Contents of the fallback parsing log.

    Returns:
        Backend name string: 'verible', 'slang', or 'unknown'.
    """
    if "verible-verilog-syntax" in log_text:
        return "verible"
    if "slang" in log_text:
        return "slang"
    return "unknown"


def parse_fallback_output(
    artifact_path: str, log_path: str, script_path: str = ""
) -> dict:
    """Parse and validate fallback AST output.

    Args:
        artifact_path: Path to the normalized AST JSON.
        log_path: Path to the parsing log file.
        script_path: Path to the shell script that was run (optional).

    Returns:
        Summary dict with valid, backend_used, modules, error.
    """
    artifact = Path(artifact_path)
    log = Path(log_path)

    # Check if artifact exists
    if not artifact.exists() or artifact.stat().st_size == 0:
        error_code = "ARTIFACT_MISSING"
        if log.exists():
            log_text = log.read_text(errors="replace")
            if "command not found" in log_text:
                error_code = "BACKEND_NOT_INSTALLED"
            elif "exit:1" in log_text or "exit:127" in log_text:
                error_code = "BACKEND_FAILED"
        return {
            "valid": False,
            "error": error_code,
            "backend_used": "unknown",
            "modules": [],
            "artifact_path": artifact_path,
        }

    # Parse JSON
    try:
        data = json.loads(artifact.read_text())
    except json.JSONDecodeError as e:
        return {
            "valid": False,
            "error": f"JSON_PARSE_ERROR: {e}",
            "backend_used": "unknown",
            "modules": [],
            "artifact_path": artifact_path,
        }

    # Validate schema
    schema_errors = validate_schema(data)
    if schema_errors:
        return {
            "valid": False,
            "error": f"SCHEMA_INVALID: {'; '.join(schema_errors)}",
            "backend_used": data.get("backend", "unknown"),
            "modules": [],
            "artifact_path": artifact_path,
        }

    # Detect backend from log
    backend_used = data.get("backend", "unknown")
    if log.exists():
        log_text = log.read_text(errors="replace")
        detected = detect_backend(log_text)
        if detected != "unknown":
            backend_used = detected

    # Extract module info
    modules = []
    for mod in data.get("modules", []):
        modules.append({
            "name": mod.get("name", "unknown"),
            "port_count": len(mod.get("ports", [])),
        })

    return {
        "valid": True,
        "error": None,
        "backend_used": backend_used,
        "modules": [m["name"] for m in modules],
        "module_details": modules,
        "module_count": len(modules),
        "node_count": data.get("node_count", 0),
        "artifact_path": artifact_path,
        "log_path": log_path,
    }


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <artifact_path> <log_path> [script_path]", file=sys.stderr)
        sys.exit(1)

    artifact_path = sys.argv[1]
    log_path = sys.argv[2]
    script_path = sys.argv[3] if len(sys.argv) > 3 else ""

    result = parse_fallback_output(artifact_path, log_path, script_path)
    print(json.dumps(result, indent=2))

    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
