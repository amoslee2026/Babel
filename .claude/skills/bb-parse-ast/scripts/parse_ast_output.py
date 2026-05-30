#!/usr/bin/env python3
"""Parse pyverilog/slang AST output into normalized JSON summary.

Validates the generated AST JSON, extracts module list,
and detects known error patterns from the log.
"""
import json
import re
import sys
from pathlib import Path


# Known error patterns and their canonical error codes
ERROR_PATTERNS = [
    (re.compile(r"pyverilog\.vparser.*Exception", re.IGNORECASE), "UNSUPPORTED_SV_SYNTAX"),
    (re.compile(r"SyntaxError", re.IGNORECASE), "UNSUPPORTED_SV_SYNTAX"),
    (re.compile(r"ImportError.*pyverilog", re.IGNORECASE), "PYVERILOG_NOT_INSTALLED"),
    (re.compile(r"TIMEOUT", re.IGNORECASE), "AST_TIMEOUT"),
    (re.compile(r"FileNotFoundError", re.IGNORECASE), "FILE_NOT_FOUND"),
]


def parse_ast_output(ast_path: str, log_path: str) -> dict:
    """Parse and validate AST output files.

    Args:
        ast_path: Path to the generated AST JSON file.
        log_path: Path to the parser log file.

    Returns:
        Summary dict with valid, modules, error, etc.
    """
    ast_file = Path(ast_path)
    log_file = Path(log_path)

    # Check if AST JSON exists and is non-empty
    if not ast_file.exists() or ast_file.stat().st_size == 0:
        error_code = "AST_FILE_MISSING"
        # Try to get more specific error from log
        if log_file.exists():
            log_text = log_file.read_text(errors="replace")
            for pattern, code in ERROR_PATTERNS:
                if pattern.search(log_text):
                    error_code = code
                    break
        return {
            "valid": False,
            "error": error_code,
            "modules": [],
            "ast_path": ast_path,
            "log_path": log_path,
        }

    # Parse JSON
    try:
        ast_data = json.loads(ast_file.read_text())
    except json.JSONDecodeError as e:
        return {
            "valid": False,
            "error": f"JSON_PARSE_ERROR: {e}",
            "modules": [],
            "ast_path": ast_path,
            "log_path": log_path,
        }

    # Extract module list
    modules = []
    for mod in ast_data.get("modules", []):
        name = mod.get("name", "unknown")
        port_count = len(mod.get("ports", []))
        modules.append({"name": name, "port_count": port_count})

    # Check for errors in log even if JSON was produced
    log_warnings = []
    if log_file.exists():
        log_text = log_file.read_text(errors="replace")
        for pattern, code in ERROR_PATTERNS:
            if pattern.search(log_text):
                log_warnings.append(code)

    return {
        "valid": True,
        "error": None,
        "modules": modules,
        "module_count": len(modules),
        "node_count": ast_data.get("node_count", 0),
        "design_name": ast_data.get("design_name", ""),
        "warnings": log_warnings,
        "ast_path": ast_path,
        "log_path": log_path,
    }


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <ast_path> <log_path>", file=sys.stderr)
        sys.exit(1)

    ast_path = sys.argv[1]
    log_path = sys.argv[2]

    result = parse_ast_output(ast_path, log_path)
    print(json.dumps(result, indent=2))

    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
