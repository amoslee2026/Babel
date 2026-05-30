#!/usr/bin/env python3
"""Execute floorplan generation and return JSON status."""
import sys
import subprocess
import json
from pathlib import Path

def run_floorplan_gen(top_module: str, config_file: str) -> dict:
    """Run Magic floorplan generation."""
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)

        sys.path.insert(0, str(Path(__file__).parent))
        from render_fp_py import render_floorplan_tcl
        tcl_content = render_floorplan_tcl(config)

        tcl_file = f'{top_module}_fp.tcl'
        with open(tcl_file, 'w') as f:
            f.write(tcl_content)

        result = subprocess.run(['magic', '-dnull', '-noconsole', '-rcfile', tcl_file],
                                capture_output=True, text=True, timeout=300)
        log_file = f'floorplan_{top_module}.log'
        with open(log_file, 'w') as f:
            f.write(result.stdout + result.stderr)

        from parse_fp import parse_floorplan_output
        fp_result = parse_floorplan_output(log_file)
        return {'status': fp_result['status'], 'top_module': top_module,
                'die_area': fp_result['die_area'], 'utilization': fp_result['utilization']}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'message': 'Floorplan generation timeout'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_fp_gen.py <top_module> <config.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_floorplan_gen(sys.argv[1], sys.argv[2]), indent=2))
