#!/usr/bin/env python3
"""Execute fallback parser chain (pyverilog -> slang -> verible -> regex).

Runs the generated shell script with the EDA environment sourced.
If the primary backend fails, automatically retries with the alternate.
Enforces a 600s timeout per backend.
"""
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


TIMEOUT_SECONDS = 600
EDA_ENV_SCRIPT = os.path.expanduser("~/wrk/eda_opensources/eda_env.sh")

# Backend fallback order
BACKEND_CHAIN = {
    "verible": ["verible", "slang"],
    "slang": ["slang", "verible"],
}


def run_shell_script(script_path: str, log_path: str) -> dict:
    """Execute a shell script with EDA environment and timeout.

    Args:
        script_path: Path to the bash script.
        log_path: Path to write stdout/stderr log.

    Returns:
        Dict with status, exit_code, elapsed time.
    """
    log = Path(log_path)
    log.parent.mkdir(parents=True, exist_ok=True)

    # Build command with EDA env sourced
    cmd = f"source {EDA_ENV_SCRIPT} && bash {script_path}"

    start = datetime.now(timezone.utc)
    try:
        result = subprocess.run(
            ["bash", "-c", cmd],
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
        stderr = f"TIMEOUT: Backend exceeded {TIMEOUT_SECONDS}s limit"

    elapsed = (datetime.now(timezone.utc) - start).total_seconds()

    log_content = f"=== stdout ===\n{stdout}\n=== stderr ===\n{stderr}\nexit:{exit_code}\n"
    log.write_text(log_content)

    return {
        "status": "success" if exit_code == 0 else "failed",
        "exit_code": exit_code,
        "elapsed_seconds": round(elapsed, 2),
        "log_path": str(log),
        "timed_out": exit_code == -1,
    }


def run_fallback(
    script_path: str,
    log_path: str,
    backend: str = "verible",
    alt_script_path: str = "",
    alt_log_path: str = "",
) -> dict:
    """Execute fallback parser with automatic backend switching.

    Args:
        script_path: Path to primary backend shell script.
        log_path: Path for primary backend log.
        backend: Primary backend name ('verible' or 'slang').
        alt_script_path: Path to alternate backend shell script (optional).
        alt_log_path: Path for alternate backend log (optional).

    Returns:
        Dict with backend_used, valid, and execution details.
    """
    # Try primary backend
    primary_result = run_shell_script(script_path, log_path)

    if primary_result["status"] == "success":
        return {
            "backend_used": backend,
            "valid": True,
            "error": None,
            "primary": primary_result,
            "fallback_used": False,
        }

    # Primary failed - try alternate if available
    if alt_script_path and alt_log_path:
        alt_backend = "slang" if backend == "verible" else "verible"
        alt_result = run_shell_script(alt_script_path, alt_log_path)

        if alt_result["status"] == "success":
            return {
                "backend_used": alt_backend,
                "valid": True,
                "error": None,
                "primary": primary_result,
                "fallback": alt_result,
                "fallback_used": True,
            }

        # Both failed
        return {
            "backend_used": "none",
            "valid": False,
            "error": "all AST backends failed",
            "primary": primary_result,
            "fallback": alt_result,
            "fallback_used": True,
        }

    # No alternate available
    return {
        "backend_used": "none",
        "valid": False,
        "error": f"{backend} failed and no alternate provided",
        "primary": primary_result,
        "fallback_used": False,
    }


def main():
    if len(sys.argv) < 3:
        print(
            f"Usage: {sys.argv[0]} <script_path> <log_path> [backend] [alt_script] [alt_log]",
            file=sys.stderr,
        )
        sys.exit(1)

    script_path = sys.argv[1]
    log_path = sys.argv[2]
    backend = sys.argv[3] if len(sys.argv) > 3 else "verible"
    alt_script = sys.argv[4] if len(sys.argv) > 4 else ""
    alt_log = sys.argv[5] if len(sys.argv) > 5 else ""

    if not Path(script_path).exists():
        print(f"ERROR: Script not found: {script_path}", file=sys.stderr)
        sys.exit(1)

    result = run_fallback(script_path, log_path, backend, alt_script, alt_log)
    print(json.dumps(result, indent=2))

    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
