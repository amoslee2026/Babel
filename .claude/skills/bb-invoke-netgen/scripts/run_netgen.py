#!/usr/bin/env python3
"""
run_netgen.py -- Execute Netgen LVS comparison and capture results.

Phase 2 of bb-invoke-netgen: runs Netgen with environment validation.
"""

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

EDA_ENV_PATH = "~/wrk/eda_opensources/eda_env.sh"
NETGEN_VERSION_REQUIRED = "1.5"
DEFAULT_TIMEOUT = 600  # 10 minutes


def source_eda_env() -> tuple[dict | None, str | None]:
    """Source EDA environment and return env dict."""
    env = os.environ.copy()
    env_cmd = f"source {EDA_ENV_PATH} && env"
    result = subprocess.run(
        ["bash", "-c", env_cmd], capture_output=True, text=True
    )
    if result.returncode != 0:
        return None, "EDA_ENV_FAILED"
    for line in result.stdout.split("\n"):
        if "=" in line:
            key, _, value = line.partition("=")
            env[key] = value
    return env, None


def validate_netgen_version(env: dict) -> tuple[bool, str | None]:
    """Validate Netgen version."""
    try:
        result = subprocess.run(
            ["netgen", "-batch", "lvs", "--version"],
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
        )
        version_text = result.stdout + result.stderr
        if NETGEN_VERSION_REQUIRED not in version_text:
            return False, f"VERSION_MISMATCH: got '{version_text[:100]}'"
        return True, None
    except subprocess.TimeoutExpired:
        return False, "NETGEN_TIMEOUT_VERSION_CHECK"
    except FileNotFoundError:
        return False, "NETGEN_NOT_FOUND"


def run(script_path: str, output_dir: str) -> dict:
    """Run Netgen LVS with the given script."""
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / "netgen.log"
    timestamp = datetime.now(timezone.utc).isoformat()

    # Source environment
    env, error = source_eda_env()
    if error:
        return {
            "status": "error",
            "error": error,
            "timestamp": timestamp,
        }

    # Validate version
    valid, error = validate_netgen_version(env)
    if not valid:
        return {
            "status": "error",
            "error": error,
            "timestamp": timestamp,
        }

    start_time = time.time()

    try:
        with open(log_path, "w") as log_file:
            proc = subprocess.Popen(
                ["bash", str(script_path)],
                env=env,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                rc = proc.wait(timeout=DEFAULT_TIMEOUT)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                with open(log_path, "a") as f:
                    f.write("\nLVS_TIMEOUT\nexit:124\n")
                return {
                    "status": "timeout",
                    "error": "LVS_TIMEOUT",
                    "elapsed": DEFAULT_TIMEOUT,
                    "timestamp": timestamp,
                }

        elapsed = time.time() - start_time

        with open(log_path, "a") as f:
            f.write(f"\nexit:{rc}\n")
            f.write(f"elapsed:{elapsed:.2f}s\n")

        return {
            "status": "complete" if rc == 0 else "failed",
            "valid": rc == 0,
            "exit_code": rc,
            "elapsed": elapsed,
            "log_path": str(log_path),
            "timestamp": timestamp,
            "error": None if rc == 0 else f"NETGEN_EXIT_{rc}",
        }

    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "timestamp": timestamp,
        }


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            f"Usage: {sys.argv[0]} <script_path> <output_dir>",
            file=sys.stderr,
        )
        sys.exit(1)
    result = run(sys.argv[1], sys.argv[2])
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("status") == "complete" else 1)
