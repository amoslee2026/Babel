#!/usr/bin/env python3
"""
render_sta_tcl.py -- Render OpenSTA TCL script from parameters.

Phase 1 of bb-invoke-opensta: generates executable TCL for single/multi-corner STA.
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

# Default ASAP7 corner-to-Liberty mapping
CORNER_LIB_MAP = {
    'ss_0p63v_m40c': 'libs/asap7/asap7sc7p5t_28/lib/asap7sc7p5t_AO_RVT_SS_nldm_201020.lib',
    'tt_0p77v_25c':  'libs/asap7/asap7sc7p5t_28/lib/asap7sc7p5t_AO_RVT_TT_nldm_201020.lib',
    'ff_0p88v_125c': 'libs/asap7/asap7sc7p5t_28/lib/asap7sc7p5t_AO_RVT_FF_nldm_201020.lib',
}


def render_corner_block(corner: str, liberty_path: str, netlist: str,
                        top_module: str, sdc_path: str,
                        spef_path: str | None = None) -> str:
    """Render TCL block for a single PVT corner."""
    lines = [
        f'puts "=== CORNER {corner} ==="',
        f'read_liberty {liberty_path}',
        f'read_verilog {netlist}',
        f'link_design {top_module}',
        f'read_sdc {sdc_path}',
    ]
    if spef_path:
        lines.append(f'read_spef {spef_path}')
    lines += [
        'set_operating_conditions -analysis_type on_chip_variation',
        'report_checks -path_delay max -format full_clock_expanded -group_count 10',
        'report_wns',
        'report_tns',
        '',
    ]
    return '\n'.join(lines)


def render_sta_tcl(params: dict) -> str:
    """Render full TCL script for all corners."""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    header = [
        f'# OpenSTA TCL script',
        f'# Generated: {timestamp}',
        f'# Design: {params["design_name"]}',
        f'# Corners: {", ".join(params["corners"])}',
        '',
    ]

    blocks = []
    for corner in params['corners']:
        lib_path = params.get('liberty_map', {}).get(corner, CORNER_LIB_MAP.get(corner, ''))
        if not lib_path:
            lib_path = params.get('tech_lib', '')
        block = render_corner_block(
            corner, lib_path, params['netlist'],
            params['top_module'], params['sdc_path'],
            params.get('spef'),
        )
        blocks.append(block)

    footer = ['puts "=== ALL CORNERS DONE ==="', 'exit 0']
    return '\n'.join(header + blocks + footer)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render OpenSTA TCL script")
    parser.add_argument('--design-name', required=True, help='Design name')
    parser.add_argument('--top', required=True, help='Top module name')
    parser.add_argument('--netlist', required=True, help='Gate-level netlist path')
    parser.add_argument('--sdc', required=True, help='SDC constraints path')
    parser.add_argument('--corners', default='tt_0p77v_25c',
                        help='Comma-separated PVT corners')
    parser.add_argument('--spef', default=None, help='SPEF path (post-PD)')
    parser.add_argument('--tech-lib', default=None,
                        help='Single Liberty path (overrides corner map)')
    parser.add_argument('--liberty-map', default=None,
                        help='JSON string mapping corners to liberty paths')
    parser.add_argument('--out', required=True, help='Output TCL file path')

    args = parser.parse_args()

    liberty_map = json.loads(args.liberty_map) if args.liberty_map else {}

    params = {
        'design_name': args.design_name,
        'top_module': args.top,
        'netlist': args.netlist,
        'sdc_path': args.sdc,
        'corners': [c.strip() for c in args.corners.split(',')],
        'spef': args.spef,
        'tech_lib': args.tech_lib,
        'liberty_map': liberty_map,
    }

    tcl_content = render_sta_tcl(params)
    Path(args.out).write_text(tcl_content)
    print(f"TCL rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
