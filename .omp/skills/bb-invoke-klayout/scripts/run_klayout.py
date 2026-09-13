#!/usr/bin/env python3
"""
run_klayout.py — Execute KLayout in batch mode for DRC or GDSII export.

Returns JSON status with elapsed time and exit code.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


EDA_ENV_PATH = "~/wrk/eda_opensources/eda_env.sh"
DEFAULT_TIMEOUT = 1800  # seconds


def source_eda_env() -> tuple:
    """Source EDA environment and return env dict."""
    env = os.environ.copy()
    env_cmd = f"source {EDA_ENV_PATH} && env"
    result = subprocess.run(
        ['bash', '-c', env_cmd],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return None, "EDA_ENV_FAILED"

    for line in result.stdout.split('\n'):
        if '=' in line:
            key, _, value = line.partition('=')
            env[key] = value

    return env, None


def run_klayout(script_path: str, log_path: str, mode: str,
                timeout: int, env: dict) -> dict:
    """Execute KLayout in batch mode."""
    start_time = time.time()

    cmd = ['klayout', '-b']
    if mode == 'drc':
        cmd.extend(['-r', script_path])
    else:
        cmd.extend(['-rm', script_path])

    try:
        with open(log_path, 'w') as log_file:
            process = subprocess.Popen(
                cmd, env=env,
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
                    'error': 'KLAYOUT_TIMEOUT',
                    'elapsed': timeout
                }

            elapsed = time.time() - start_time

            with open(log_path, 'a') as lf:
                lf.write(f"\nexit:{returncode}\n")
                lf.write(f"elapsed:{elapsed:.2f}s\n")

            return {
                'success': returncode == 0,
                'error': None if returncode == 0 else f"KLAYOUT_EXIT_{returncode}",
                'elapsed': elapsed
            }

    except Exception as e:
        return {'success': False, 'error': str(e), 'elapsed': 0}


def main():
    parser = argparse.ArgumentParser(
        description="Run KLayout batch mode"
    )
    parser.add_argument('--script', required=True,
                        help='KLayout script path')
    parser.add_argument('--mode', required=True, choices=['drc', 'export'],
                        help='Operation mode')
    parser.add_argument('--log', required=True,
                        help='Log output path')
    parser.add_argument('--out', required=True,
                        help='Output JSON path')
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                        help=f'Timeout seconds (default: {DEFAULT_TIMEOUT})')

    args = parser.parse_args()

    if not os.path.exists(args.script):
        print(f"Error: script not found: {args.script}")
        return 1

    env, error = source_eda_env()
    if error:
        print(f"Error sourcing EDA env: {error}")
        return 1

    result = run_klayout(args.script, args.log, args.mode,
                         args.timeout, env)

    with open(args.out, 'w') as f:
        json.dump(result, f, indent=2)

    if result['success']:
        print(f"KLayout completed in {result['elapsed']:.2f}s")
    else:
        print(f"KLayout failed: {result['error']}")

    return 0 if result['success'] else 1


if __name__ == '__main__':
    sys.exit(main())
