#!/usr/bin/env python3
"""
render_netgen.py -- Render Netgen setup script for LVS comparison.

Phase 1 of bb-invoke-netgen: generates batch command for LVS.
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path


def render_lvs_command(params: dict) -> str:
    """Render Netgen batch LVS command."""
    lines = [
        '#!/bin/bash',
        f'# Netgen LVS script - {params["design_name"]}',
        f'# Generated: {datetime.now().strftime("%Y%m%d_%H%M%S")}',
        '#',
        f'# Layout:  {params["layout_netlist"]} ({params["top_module"]})',
        f'# Schematic: {params["schematic_netlist"]} ({params["top_module"]})',
        '#',
        '',
        'source ~/wrk/eda_opensources/eda_env.sh',
        '',
        'netgen -batch lvs \\',
        f'  "{params["layout_netlist"]} {params["top_module"]}" \\',
        f'  "{params["schematic_netlist"]} {params["top_module"]}" \\',
        f'  {params["setup_file"]} \\',
        f'  {params["report_path"]}',
        '',
    ]
    return '\n'.join(lines)


def render_setup_script(params: dict) -> str:
    """Render Netgen setup TCL for ASAP7 cell comparison."""
    lines = [
        f'# Netgen setup for {params["design_name"]}',
        f'# Generated: {datetime.now().strftime("%Y%m%d_%H%M%S")}',
        '',
        '# Ignore power/ground net name differences',
        'property {-circuit1} vdd',
        'property {-circuit1} gnd',
        'property {-circuit2} vdd',
        'property {-circuit2} gnd',
        '',
        '# Permit black-box cells',
        'permute default',
        '',
        '# Compare device properties',
        'property device all',
        '',
    ]
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render Netgen LVS script")
    parser.add_argument('--design-name', required=True, help='Design name')
    parser.add_argument('--top', required=True, help='Top module name')
    parser.add_argument('--schematic', required=True, help='Schematic netlist path')
    parser.add_argument('--layout', required=True, help='Layout netlist path')
    parser.add_argument('--setup-file', default=None,
                        help='Netgen setup TCL path (auto-generated if omitted)')
    parser.add_argument('--report', required=True, help='LVS report output path')
    parser.add_argument('--out', required=True, help='Output script path')
    parser.add_argument('--mode', choices=['command', 'setup'], default='command',
                        help='Render mode: batch command or setup TCL')

    args = parser.parse_args()

    params = {
        'design_name': args.design_name,
        'top_module': args.top,
        'schematic_netlist': args.schematic,
        'layout_netlist': args.layout,
        'setup_file': args.setup_file or 'setup.tcl',
        'report_path': args.report,
    }

    if args.mode == 'setup':
        content = render_setup_script(params)
    else:
        content = render_lvs_command(params)

    Path(args.out).write_text(content)
    print(f"Script rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
