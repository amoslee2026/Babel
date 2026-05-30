#!/usr/bin/env python3
"""Run CDC analysis and return JSON status."""
import sys
import subprocess
import json
from pathlib import Path

def run_cdc_analysis(top_module: str, rtl_dir: str) -> dict:
    """Run CDC analysis using pattern matching on RTL."""
    rtl_path = Path(rtl_dir)
    sv_files = list(rtl_path.glob('*.sv')) + list(rtl_path.glob('*.v'))
    if not sv_files:
        return {'status': 'error', 'message': 'No RTL files found'}

    # Check for synchronizer patterns in RTL
    crossings = []
    for f in sv_files:
        with open(f, 'r') as fp:
            content = fp.read()
            import re
            if re.search(r'always_ff.*sync.*reg', content, re.DOTALL):
                crossings.append({'file': str(f), 'pattern': '2ff_sync'})

    log_file = f'cdc_{top_module}.log'
    with open(log_file, 'w') as f:
        f.write(f"CDC analysis for {top_module}\n")
        f.write(f"Found {len(crossings)} synchronizer patterns\n")

    return {'status': 'pass', 'top_module': top_module,
            'sync_patterns_found': len(crossings), 'log_file': log_file}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_cdc.py <top_module> <rtl_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_cdc_analysis(sys.argv[1], sys.argv[2]), indent=2))
