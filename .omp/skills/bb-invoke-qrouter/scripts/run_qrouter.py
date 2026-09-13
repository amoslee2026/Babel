#!/usr/bin/env python3
"""
run_qrouter.py — Execute QRouter with config file.

Runs QRouter detailed routing and returns JSON status.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


EDA_ENV_PATH = "~/wrk/eda_opensources/eda_env.sh"
DEFAULT_TIMEOUT = 3600  # seconds


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


def run_qrouter(cfg_path: str, log_path: str, timeout: int, env: dict) -> dict:
    """Execute QRouter and capture output."""
    start_time = time.time()

    try:
        with open(log_path, 'w') as log_file:
            process = subprocess.Popen(
                ['qrouter', '-c', cfg_path],
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
                    'error': 'QROUTER_TIMEOUT',
                    'elapsed': timeout
                }

            elapsed = time.time() - start_time

            with open(log_path, 'a') as lf:
                lf.write(f"\nexit:{returncode}\n")
                lf.write(f"elapsed:{elapsed:.2f}s\n")

            return {
                'success': returncode == 0,
                'error': None if returncode == 0 else f"QROUTER_EXIT_{returncode}",
                'elapsed': elapsed
            }

    except Exception as e:
        return {'success': False, 'error': str(e), 'elapsed': 0}


def main():
    parser = argparse.ArgumentParser(description="Run QRouter")
    parser.add_argument('--cfg', required=True, help='Config file path')
    parser.add_argument('--log', required=True, help='Log output path')
    parser.add_argument('--out', required=True, help='Output JSON path')
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                        help=f'Timeout in seconds (default: {DEFAULT_TIMEOUT})')

    args = parser.parse_args()

    if not os.path.exists(args.cfg):
        print(f"Error: config not found: {args.cfg}")
        return 1

    env, error = source_eda_env()
    if error:
        print(f"Error sourcing EDA env: {error}")
        return 1

    result = run_qrouter(args.cfg, args.log, args.timeout, env)

    with open(args.out, 'w') as f:
        json.dump(result, f, indent=2)

    if result['success']:
        print(f"QRouter completed in {result['elapsed']:.2f}s")
    else:
        print(f"QRouter failed: {result['error']}")

    return 0 if result['success'] else 1


if __name__ == '__main__':
    sys.exit(main())
