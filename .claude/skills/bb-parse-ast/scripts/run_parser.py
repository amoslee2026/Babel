#!/usr/bin/env python3
"""Execute AST parser on SystemVerilog sources.

Runs the generated parser script with uv, captures output to log,
and appends exit code. Enforces a 600s timeout.
"""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


TIMEOUT_SECONDS = 600


def run_parser(script_path: str, log_path: str) -> dict:
    """Execute the parser script and capture results.

    Args:
        script_path: Path to the generated parser Python script.
        log_path: Path to write stdout/stderr log.

    Returns:
        Dict with status, exit_code, and timing info.
    """
    log = Path(log_path)
    log.parent.mkdir(parents=True, exist_ok=True)

    start = datetime.now(timezone.utc)
    try:
        result = subprocess.run(
            ["uv", "run", "python", script_path],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
        )
        exit_code = result.returncode
        stdout = result.stdout
        stderr = result.stderr
    except subprocess.TimeoutExpired:
        exit_code = -1
        stdout = ""
        stderr = f"TIMEOUT: Parser exceeded {TIMEOUT_SECONDS}s limit"

    elapsed = (datetime.now(timezone.utc) - start).total_seconds()

    # Write log
    log_content = f"=== stdout ===\n{stdout}\n=== stderr ===\n{stderr}\nexit:{exit_code}\n"
    log.write_text(log_content)

    return {
        "status": "success" if exit_code == 0 else "failed",
        "exit_code": exit_code,
        "elapsed_seconds": round(elapsed, 2),
        "log_path": str(log),
        "timed_out": exit_code == -1,
    }


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <script_path> <log_path>", file=sys.stderr)
        sys.exit(1)

    script_path = sys.argv[1]
    log_path = sys.argv[2]

    if not Path(script_path).exists():
        print(f"ERROR: Script not found: {script_path}", file=sys.stderr)
        sys.exit(1)

    result = run_parser(script_path, log_path)
    print(json.dumps(result, indent=2))

    sys.exit(0 if result["status"] == "success" else 1)


if __name__ == "__main__":
    main()
