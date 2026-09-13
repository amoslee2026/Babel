#!/usr/bin/env python3
"""
run_sta.py -- Execute OpenSTA with timeout and capture output.

Phase 2 of bb-invoke-opensta: runs TCL script, returns JSON status.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

EDA_ENV_PATH = "~/wrk/eda_opensources/eda_env.sh"
STA_VERSION_REQUIRED = "2.5"
DEFAULT_TIMEOUT = 900


def source_eda_env() -> tuple[dict | None, str | None]:
    """Source EDA environment and return env dict."""
    env = os.environ.copy()
    result = subprocess.run(
        ['bash', '-c', f'source {EDA_ENV_PATH} && env'],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None, 'EDA_ENV_FAILED'
    for line in result.stdout.split('\n'):
        if '=' in line:
            key, _, value = line.partition('=')
            env[key] = value
    return env, None


def validate_sta_version(env: dict) -> tuple[bool, str | None]:
    """Check OpenSTA version."""
    try:
        result = subprocess.run(
            ['sta', '-version'], env=env,
            capture_output=True, text=True, timeout=10,
        )
        output = result.stdout + result.stderr
        if STA_VERSION_REQUIRED not in output:
            return False, f"VERSION_MISMATCH: got '{output.strip()}', need '{STA_VERSION_REQUIRED}'"
        return True, None
    except FileNotFoundError:
        return False, 'STA_NOT_FOUND'
    except subprocess.TimeoutExpired:
        return False, 'STA_TIMEOUT_VERSION_CHECK'


def run_sta(tcl_path: str, log_path: str, timeout: int, env: dict) -> dict:
    """Execute OpenSTA and capture results."""
    start = time.time()
    try:
        with open(log_path, 'w') as log_f:
            proc = subprocess.Popen(
                ['sta', '-exit', tcl_path],
                env=env, stdout=log_f, stderr=subprocess.STDOUT, text=True,
            )
            try:
                rc = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
                return {'success': False, 'error': 'STA_TIMEOUT',
                        'elapsed': timeout, 'exit_code': -1}

            elapsed = time.time() - start
            with open(log_path, 'a') as log_f:
                log_f.write(f'\nexit:{rc}\n')
                log_f.write(f'elapsed:{elapsed:.2f}s\n')

            return {
                'success': rc == 0,
                'error': None if rc == 0 else f'STA_EXIT_{rc}',
                'elapsed': round(elapsed, 2),
                'exit_code': rc,
            }
    except Exception as e:
        return {'success': False, 'error': str(e),
                'elapsed': 0, 'exit_code': -1}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run OpenSTA")
    parser.add_argument('--tcl', required=True, help='TCL script path')
    parser.add_argument('--log', required=True, help='Log output path')
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                        help=f'Timeout seconds (default: {DEFAULT_TIMEOUT})')
    args = parser.parse_args()

    if not Path(args.tcl).exists():
        print(json.dumps({'success': False, 'error': 'TCL_NOT_FOUND'}))
        return 1

    env, err = source_eda_env()
    if err:
        print(json.dumps({'success': False, 'error': err}))
        return 1

    valid, err = validate_sta_version(env)
    if not valid:
        print(json.dumps({'success': False, 'error': err}))
        return 1

    result = run_sta(args.tcl, args.log, args.timeout, env)
    print(json.dumps(result, indent=2))
    return 0 if result['success'] else 1


if __name__ == '__main__':
    sys.exit(main())
