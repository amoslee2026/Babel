#!/usr/bin/env python3
"""
render_magic_tcl.py -- Render Magic TCL script for DRC/place/extract.

Phase 1 of bb-invoke-magic: generates executable TCL by action type.
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path


def render_drc_tcl(params: dict) -> str:
    """Render TCL for DRC checking."""
    return '\n'.join([
        f'# Magic DRC script - {params["design_name"]}',
        f'# Generated: {datetime.now().strftime("%Y%m%d_%H%M%S")}',
        f'tech load {params["tech_file"]}',
        f'load {params["layout_input"]}',
        'select top cell',
        'drc check',
        'drc count',
        'drc find',
        f'drc catch {params["report_path"]}',
        'quit',
        '',
    ])


def render_place_tcl(params: dict) -> str:
    """Render TCL for placement."""
    return '\n'.join([
        f'# Magic placement script - {params["design_name"]}',
        f'# Generated: {datetime.now().strftime("%Y%m%d_%H%M%S")}',
        f'tech load {params["tech_file"]}',
        f'source {params["layout_input"]}',
        'place_design',
        f'write_def {params["output_path"]}',
        'quit',
        '',
    ])


def render_extract_tcl(params: dict) -> str:
    """Render TCL for SPICE extraction."""
    return '\n'.join([
        f'# Magic extraction script - {params["design_name"]}',
        f'# Generated: {datetime.now().strftime("%Y%m%d_%H%M%S")}',
        f'tech load {params["tech_file"]}',
        f'load {params["layout_input"]}',
        'select top cell',
        'extract all',
        f'ext2spice hierarchy',
        f'ext2spice -o {params["output_path"]}',
        'quit',
        '',
    ])


RENDERERS = {
    'drc': render_drc_tcl,
    'place': render_place_tcl,
    'extract': render_extract_tcl,
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Render Magic TCL script")
    parser.add_argument('--action', required=True, choices=['drc', 'place', 'extract'],
                        help='Action type')
    parser.add_argument('--tech-file', required=True, help='ASAP7 tech file path')
    parser.add_argument('--layout-input', required=True, help='Input layout/TCL path')
    parser.add_argument('--design-name', required=True, help='Design name')
    parser.add_argument('--report-path', default=None, help='DRC report output path')
    parser.add_argument('--output-path', default=None, help='Output file path (place/extract)')
    parser.add_argument('--out', required=True, help='Output TCL file path')

    args = parser.parse_args()

    params = {
        'action': args.action,
        'tech_file': args.tech_file,
        'layout_input': args.layout_input,
        'design_name': args.design_name,
        'report_path': args.report_path or '',
        'output_path': args.output_path or '',
    }

    renderer = RENDERERS.get(args.action)
    if not renderer:
        print(f"Unknown action: {args.action}")
        return 1

    tcl_content = renderer(params)
    Path(args.out).write_text(tcl_content)
    print(f"TCL rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
