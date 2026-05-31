#!/usr/bin/env python3
"""Run CDC analysis and return JSON status."""
import sys
import re
import json
from pathlib import Path

# 2-stage synchronizer structure: a sync register chain inside an always_ff/always
# block. Anchored to a register assignment so it does not match any file that
# merely contains the word "sync" somewhere.
SYNC_REG_RE = re.compile(
    r'always(?:_ff)?\s*@\s*\(\s*posedge\s+\w+[^)]*\)[^;]*?'
    r'\b\w*sync\w*\s*<=\s*\w+\s*;',
    re.IGNORECASE,
)

def run_cdc_analysis(top_module: str, rtl_dir: str) -> dict:
    """Run CDC analysis using pattern matching on RTL.

    Fail CLOSED: this pattern-based pass only detects synchronizer *structures*.
    It does NOT perform source->sink cross-domain reachability analysis, so it
    cannot affirmatively certify the design as CDC-clean. It therefore never
    returns 'pass'; a full CDC backend must replace this to do so.
    """
    rtl_path = Path(rtl_dir)
    sv_files = list(rtl_path.glob('*.sv')) + list(rtl_path.glob('*.v'))
    if not sv_files:
        return {'status': 'error', 'message': 'No RTL files found'}

    # Detect synchronizer structures in RTL (per-block, anchored).
    crossings = []
    for f in sv_files:
        content = f.read_text(errors='replace')
        if SYNC_REG_RE.search(content):
            crossings.append({'file': str(f), 'pattern': '2ff_sync'})

    log_file = f'cdc_{top_module}.log'
    with open(log_file, 'w') as f:
        f.write(f"CDC analysis for {top_module}\n")
        f.write(f"Found {len(crossings)} synchronizer patterns\n")
        f.write("WARNING: structural detection only; not a CDC-clean certification\n")

    return {
        'status': 'error',
        'message': ('structural synchronizer detection only; cross-domain '
                    'reachability analysis unavailable, cannot certify CDC-clean'),
        'top_module': top_module,
        'sync_patterns_found': len(crossings),
        'analysis_complete': False,
        'log_file': log_file,
    }

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_cdc.py <top_module> <rtl_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_cdc_analysis(sys.argv[1], sys.argv[2]), indent=2))
