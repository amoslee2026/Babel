#!/usr/bin/env python3
"""
render_abc.py — Render ABC script from parameters.

Generates ABC command script for logic optimization.
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path


def render_abc_script(params: dict) -> str:
    """Render ABC script from parameters."""
    lines = []
    lines.append("# ABC optimization script")
    lines.append(f"# Generated: {datetime.now().strftime('%Y%m%d_%H%M%S')}")
    lines.append(f"# Design: {params['design_name']}")
    lines.append("")

    # Read input
    if params.get('blif_path'):
        lines.append(f"read {params['blif_path']}")
    elif params.get('verilog_path'):
        lines.append(f"read {params['verilog_path']}")

    # Read liberty for technology mapping
    if params.get('liberty_path'):
        lines.append(f"read_lib {params['liberty_path']}")

    # Set effort level
    effort = params.get('effort', 'medium')
    lines.append("")
    lines.append(f"# Optimization effort: {effort}")

    # Target delay constraint
    if params.get('target_delay'):
        lines.append(f"set_delay {params['target_delay']}")

    # Apply optimization scripts based on effort
    lines.append("")
    lines.append("# Optimization passes")

    if effort == 'low':
        lines.append("resyn")
    elif effort == 'medium':
        lines.append("resyn2")
        if params.get('liberty_path'):
            lines.append("map -m")
    elif effort == 'high':
        lines.append("resyn3")
        if params.get('liberty_path'):
            lines.append("map -m")
        if params.get('enable_retime', False):
            lines.append("retime")
            lines.append("resyn2")

    # Custom script override
    if params.get('custom_script'):
        lines.append("# Custom script")
        lines.append(params['custom_script'])

    # Output
    lines.append("")
    if params.get('output_verilog'):
        lines.append(f"write {params['output_verilog']}")
    if params.get('output_blif'):
        lines.append(f"write_blif {params['output_blif']}")

    # Statistics
    lines.append("print_stats")
    lines.append("")
    lines.append("quit")

    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(
        description="Render ABC optimization script"
    )
    parser.add_argument('--design-name', required=True,
                        help='Design name')
    parser.add_argument('--blif-path', default=None,
                        help='Input BLIF file')
    parser.add_argument('--verilog-path', default=None,
                        help='Input Verilog file')
    parser.add_argument('--liberty-path', default=None,
                        help='Liberty library path')
    parser.add_argument('--effort', default='medium',
                        choices=['low', 'medium', 'high'],
                        help='Optimization effort level')
    parser.add_argument('--target-delay', type=float, default=None,
                        help='Target delay constraint (ns)')
    parser.add_argument('--enable-retime', action='store_true',
                        help='Enable retiming')
    parser.add_argument('--output-verilog', default=None,
                        help='Output Verilog path')
    parser.add_argument('--output-blif', default=None,
                        help='Output BLIF path')
    parser.add_argument('--out', required=True,
                        help='Output ABC script path')

    args = parser.parse_args()

    params = {
        'design_name': args.design_name,
        'blif_path': args.blif_path,
        'verilog_path': args.verilog_path,
        'liberty_path': args.liberty_path,
        'effort': args.effort,
        'target_delay': args.target_delay,
        'enable_retime': args.enable_retime,
        'output_verilog': args.output_verilog,
        'output_blif': args.output_blif
    }

    content = render_abc_script(params)

    with open(args.out, 'w') as f:
        f.write(content)

    print(f"ABC script rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
