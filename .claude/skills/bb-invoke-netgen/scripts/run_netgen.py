#!/usr/bin/env python3
"""
run_netgen.py -- Execute Netgen LVS check.

Phase 2 of bb-invoke-netgen: runs Netgen batch LVS, returns JSON status.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

EDA_ENV_PATH = "~/wrk/eda_opensources/eda_env.sh"
NETGEN_VERSION_REQUIRED = "1.5"
DEFAULT_TIMEOUT = 600


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


def validate_netgen_version(env: dict) -> tuple[bool, str | None]:
    """Check Netgen version."""
    try:
        result = subprocess.run(
            ['netgen', '--version'], env=env,
            capture_output=True, text=True, timeout=10,
        )
        output = result.stdout + result.stderr
        if NETGEN_VERSION_REQUIRED not in output:
            return False, f"VERSION_MISMATCH: got '{output.strip()}', need '{NETGEN_VERSION_REQUIRED}'"
        return True, None
    except FileNotFoundError:
        return False, 'NETGEN_NOT_FOUND'
    except subprocess.TimeoutExpired:
        return False, 'NETGEN_TIMEOUT_VERSION_CHECK'


def run_netgen(schematic: str, layout: str, setup_file: str,
               report_path: str, log_path: str,
               timeout: int, env: dict) -> dict:
    """Execute Netgen batch LVS."""
    start = time.time()
    try:
        with open(log_path, 'w') as log_f:
            cmd = [
                'netgen', '-batch', 'lvs',
                f'{layout}', f'{schematic}',
                setup_file, report_path,
            ]
            proc = subprocess.Popen(
                cmd, env=env,
                stdout=log_f, stderr=subprocess.STDOUT, text=True,
            )
            try:
                rc = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
                return {'success': False, 'error': 'LVS_TIMEOUT',
                        'elapsed': timeout, 'exit_code': -1}

            elapsed = time.time() - start
            with open(log_path, 'a') as log_f:
                log_f.write(f'\nexit:{rc}\n')
                log_f.write(f'elapsed:{elapsed:.2f}s\n')

            return {
                'success': rc == 0,
                'error': None if rc == 0 else f'NETGEN_EXIT_{rc}',
                'elapsed': round(elapsed, 2),
                'exit_code': rc,
            }
    except Exception as e:
        return {'success': False, 'error': str(e),
                'elapsed': 0, 'exit_code': -1}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Netgen LVS")
    parser.add_argument('--schematic', required=True, help='Schematic netlist')
    parser.add_argument('--layout', required=True, help='Layout netlist')
    parser.add_argument('--setup', required=True, help='Setup TCL file')
    parser.add_argument('--report', required=True, help='LVS report output')
    parser.add_argument('--log', required=True, help='Log output path')
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                        help=f'Timeout seconds (default: {DEFAULT_TIMEOUT})')
    args = parser.parse_args()

    for fpath, label in [(args.schematic, 'SCHEMATIC'), (args.layout, 'LAYOUT'),
                         (args.setup, 'SETUP')]:
        if not Path(fpath).exists():
            print(json.dumps({'success': False, 'error': f'{label}_NOT_FOUND'}))
            return 1

    env, err = source_eda_env()
    if err:
        print(json.dumps({'success': False, 'error': err}))
        return 1

    valid, err = validate_netgen_version(env)
    if not valid:
        print(json.dumps({'success': False, 'error': err}))
        return 1

    result = run_netgen(
        args.schematic, args.layout, args.setup,
        args.report, args.log, args.timeout, env,
    )
    print(json.dumps(result, indent=2))
    return 0 if result['success'] else 1


if __name__ == '__main__':
    sys.exit(main())
