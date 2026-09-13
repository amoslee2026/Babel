#!/usr/bin/env python3
"""Execute verible-verilog-lint check and return JSON status.

Uses verible-verilog-lint with the ASAP7 rules config (and the testbench waiver
when checking tb files). Gating is ERROR-only: src is clean iff there are zero
errors; style warnings are reported but do not fail src.
"""
import sys
import subprocess
import json
from pathlib import Path

ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"
RULES_CONFIG = ASSETS_DIR / "asap7_rules.cfg"
TB_WAIVER = ASSETS_DIR / "tb_waiver.vbl"


def run_lint_check(top_module: str, rtl_dir: str, is_tb: bool = False) -> dict:
    """Run verible-verilog-lint check on RTL/TB files."""
    rtl_path = Path(rtl_dir)
    sv_files = list(rtl_path.glob('*.sv')) + list(rtl_path.glob('*.v'))
    if not sv_files:
        return {'status': 'error', 'message': 'No RTL files found'}

    cmd = ['verible-verilog-lint']
    if RULES_CONFIG.exists():
        cmd += ['--rules_config', str(RULES_CONFIG)]
    if is_tb and TB_WAIVER.exists():
        cmd += ['--waiver_files', str(TB_WAIVER)]
    cmd += [str(f) for f in sv_files]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        log_file = f'lint_{top_module}.log'
        with open(log_file, 'w') as f:
            f.write(result.stdout + result.stderr)
        sys.path.insert(0, str(Path(__file__).parent))
        from parse_lint import parse_verible_output
        report = parse_verible_output(log_file)
        if report['status'] == 'error':
            return {'status': 'error', 'top_module': top_module,
                    'message': report.get('error', 'lint parse error'),
                    'report_file': 'lint_report.json'}
        # ERROR-only gating: warnings are reported but do not fail src.
        status = 'pass' if report['clean'] else 'fail'
        return {'status': status, 'top_module': top_module,
                'warnings': report['warning_count'], 'errors': report['error_count'],
                'report_file': 'lint_report.json'}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'message': 'Lint check timeout'}
    except FileNotFoundError as e:
        return {'status': 'error', 'message': f'verible-verilog-lint not found: {e}'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_lint.py <top_module> <rtl_dir> [--tb]", file=sys.stderr)
        sys.exit(1)
    is_tb = '--tb' in sys.argv[3:]
    print(json.dumps(run_lint_check(sys.argv[1], sys.argv[2], is_tb), indent=2))
