#!/usr/bin/env python3
"""
run_yosys.py — Execute Yosys synthesis with environment validation.

Phase 2 of bb-invoke-yosys: runs TCL script and captures log output.
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path


EDA_ENV_PATH = "~/wrk/eda_opensources/eda_env.sh"
YOSYS_VERSION_REQUIRED = "0.35"
DEFAULT_TIMEOUT = 600  # seconds


def source_eda_env():
    """Source EDA environment and return env dict."""
    env = os.environ.copy()

    # Source the EDA environment script
    env_cmd = f"source {EDA_ENV_PATH} && env"
    result = subprocess.run(
        ['bash', '-c', env_cmd],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        return None, "EDA_ENV_FAILED"

    # Parse environment variables
    for line in result.stdout.split('\n'):
        if '=' in line:
            key, _, value = line.partition('=')
            env[key] = value

    return env, None


def validate_yosys_version(env):
    """Validate Yosys version matches requirement."""
    try:
        result = subprocess.run(
            ['yosys', '-V'],
            env=env,
            capture_output=True,
            text=True,
            timeout=10
        )

        version_line = result.stdout.split('\n')[0] if result.stdout else ""

        if YOSYS_VERSION_REQUIRED not in version_line:
            return False, f"VERSION_MISMATCH: got '{version_line}', need '{YOSYS_VERSION_REQUIRED}'"

        return True, None
    except subprocess.TimeoutExpired:
        return False, "YOSYS_TIMEOUT_VERSION_CHECK"
    except FileNotFoundError:
        return False, "YOSYS_NOT_FOUND"


def run_yosys(tcl_path: str, log_path: str, timeout: int, env: dict) -> dict:
    """Execute Yosys synthesis and capture output."""
    start_time = time.time()

    try:
        with open(log_path, 'w') as log_file:
            process = subprocess.Popen(
                ['yosys', '-c', tcl_path],
                env=env,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True
            )

            try:
                returncode = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                process.kill()
                return {
                    'success': False,
                    'error': 'YOSYS_TIMEOUT',
                    'elapsed': timeout
                }

            elapsed = time.time() - start_time

            # Append exit code to log
            with open(log_path, 'a') as log_file:
                log_file.write(f"\nexit:{returncode}\n")
                log_file.write(f"elapsed:{elapsed:.2f}s\n")

            return {
                'success': returncode == 0,
                'error': None if returncode == 0 else f"YOSYS_EXIT_{returncode}",
                'elapsed': elapsed
            }

    except Exception as e:
        return {
            'success': False,
            'error': str(e),
            'elapsed': 0
        }


def main():
    parser = argparse.ArgumentParser(
        description="Run Yosys synthesis"
    )
    parser.add_argument('--tcl', required=True,
                        help='TCL script path')
    parser.add_argument('--log', required=True,
                        help='Log output path')
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                        help=f'Timeout in seconds (default: {DEFAULT_TIMEOUT})')

    args = parser.parse_args()

    # Validate paths
    if not os.path.exists(args.tcl):
        print(f"Error: TCL file not found: {args.tcl}")
        return 1

    # Source EDA environment
    env, error = source_eda_env()
    if error:
        print(f"Error sourcing EDA env: {error}")
        return 1

    # Validate Yosys version
    valid, error = validate_yosys_version(env)
    if not valid:
        print(f"Error: {error}")
        return 1

    # Run synthesis
    result = run_yosys(args.tcl, args.log, args.timeout, env)

    if result['success']:
        print(f"Yosys completed in {result['elapsed']:.2f}s")
        print(f"Log saved: {args.log}")
        return 0
    else:
        print(f"Yosys failed: {result['error']}")
        return 1


if __name__ == '__main__':
    sys.exit(main())