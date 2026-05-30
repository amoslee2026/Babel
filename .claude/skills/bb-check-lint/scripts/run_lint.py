#!/usr/bin/env python3
"""Execute Verilator lint check and return JSON status."""
import sys
import subprocess
import json
from pathlib import Path

def run_lint_check(top_module: str, rtl_dir: str) -> dict:
    """Run Verilator lint check."""
    rtl_path = Path(rtl_dir)
    sv_files = list(rtl_path.glob('*.sv')) + list(rtl_path.glob('*.v'))
    if not sv_files:
        return {'status': 'error', 'message': 'No RTL files found'}

    cmd = ['verilator', '--lint-only', '--sv', '-Wall', '-Wno-fatal',
           '--top-module', top_module] + [str(f) for f in sv_files]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        log_file = f'lint_{top_module}.log'
        with open(log_file, 'w') as f:
            f.write(result.stdout + result.stderr)
        sys.path.insert(0, str(Path(__file__).parent))
        from parse_lint import parse_verilator_output
        report = parse_verilator_output(log_file)
        return {'status': 'pass' if report['clean'] else 'fail', 'top_module': top_module,
                'warnings': report['warning_count'], 'errors': report['error_count'],
                'report_file': 'lint_report.json'}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'message': 'Lint check timeout'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_lint.py <top_module> <rtl_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_lint_check(sys.argv[1], sys.argv[2]), indent=2))
