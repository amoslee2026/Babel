#!/usr/bin/env python3
"""Render parser configuration for pyverilog."""
import sys
import json
from pathlib import Path

def render_parser_config(rtl_dir: str, top_module: str) -> dict:
    """Generate parser configuration."""
    rtl_path = Path(rtl_dir)
    sv_files = []
    for ext in ['*.sv', '*.v', '*.svh', '*.vh']:
        sv_files.extend([str(f) for f in rtl_path.rglob(ext)])

    include_dirs = set()
    for ext in ['*.svh', '*.vh']:
        for f in rtl_path.rglob(ext):
            include_dirs.add(str(f.parent))

    return {
        'top_module': top_module, 'files': sorted(sv_files),
        'includes': sorted(list(include_dirs)),
        'defines': ['ASAP7', 'SYNTHESIS'],
        'parser': 'pyverilog', 'output_format': 'json'
    }

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: render_parser_py.py <rtl_dir> <top_module>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(render_parser_config(sys.argv[1], sys.argv[2]), indent=2))
