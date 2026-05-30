#!/usr/bin/env python3
"""
run_verilator.py -- Execute Verilator simulation and capture results.

Phase 2 of bb-invoke-verilator: runs the rendered shell script with timeout.
"""

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_TIMEOUT = 1800  # 30 minutes


def run(script_path: str, output_dir: str) -> dict:
    """Run Verilator simulation script and capture output."""
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    script = Path(script_path)
    if not script.exists():
        return {
            "status": "error",
            "error": "SCRIPT_NOT_FOUND",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    log_path = output / "run.log"
    timestamp = datetime.now(timezone.utc).isoformat()

    try:
        with open(log_path, "w") as log_file:
            proc = subprocess.Popen(
                ["bash", str(script)],
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(Path.cwd()),
            )
            try:
                rc = proc.wait(timeout=DEFAULT_TIMEOUT)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                # Append timeout marker
                with open(log_path, "a") as f:
                    f.write("\nSIM_TIMEOUT\nexit:124\n")
                return {
                    "status": "timeout",
                    "error": "SIM_TIMEOUT",
                    "exit_code": 124,
                    "timestamp": timestamp,
                }

        # Append exit code to log
        with open(log_path, "a") as f:
            f.write(f"\nexit:{rc}\n")

        if rc == 0:
            return {
                "status": "complete",
                "valid": True,
                "exit_code": rc,
                "timestamp": timestamp,
            }
        else:
            return {
                "status": "failed",
                "valid": False,
                "exit_code": rc,
                "error": f"EXIT_CODE_{rc}",
                "timestamp": timestamp,
            }

    except Exception as e:
        return {
            "status": "error",
            "valid": False,
            "error": str(e),
            "timestamp": timestamp,
        }


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            f"Usage: {sys.argv[0]} <script_path> <output_dir>", file=sys.stderr
        )
        sys.exit(1)
    result = run(sys.argv[1], sys.argv[2])
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("status") == "complete" else 1)
