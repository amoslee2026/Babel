#!/usr/bin/env python3
"""
render_yosys_tcl.py — Render Yosys TCL synthesis script from parameters.

Phase 1 of bb-invoke-yosys: generates executable TCL script for ASAP7 synthesis.
"""

import argparse
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# Defense-in-depth identifier validation (D8-04 / D8-03).
# Primary boundary is the input-schema hook; this catches direct invocation.
_SLUG = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
_SV_ID = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,63}$")
_PATH = re.compile(r"^[A-Za-z0-9_/.,+\-]+$")


def _require_slug(v: str, field: str) -> str:
    if not _SLUG.fullmatch(str(v)):
        raise ValueError(f"{field} must be a slug; got {v!r}")
    return str(v)


def _require_sv_id(v: str, field: str) -> str:
    if not _SV_ID.fullmatch(str(v)):
        raise ValueError(f"{field} must be a SystemVerilog identifier; got {v!r}")
    return str(v)


def _require_path(v: str, field: str) -> str:
    if not _PATH.fullmatch(str(v)):
        raise ValueError(f"{field} contains unsafe characters; got {v!r}")
    return str(v)


def get_timestamp():
    """Generate timestamp for artifact naming."""
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def render_tcl(params: dict) -> str:
    """Render full TCL script from template."""
    # Validate BEFORE interpolation (defense-in-depth on top of schema hook)
    _require_slug(params['design_name'], "design_name")
    _require_sv_id(params['top_module'], "top_module")
    _require_path(params['tech_lib'], "tech_lib")
    _require_path(params['netlist_path'], "netlist_path")
    tcl_template = """
# Yosys ASAP7 Synthesis Script
# Generated: {timestamp}
# Design: {design_name}
# Top: {top_module}

# Phase 1: Read RTL sources
{read_verilog_cmds}

# Phase 2: Check hierarchy
hierarchy -check -top {top_module}

# Phase 3: Generic synthesis
synth -top {top_module}

# Phase 4: Technology mapping to ASAP7
dfflibmap -liberty {tech_lib}

# Phase 5: ABC optimization
abc -liberty {tech_lib} {abc_options}

# Optional: Retiming
{retime_cmd}

# Phase 6: Cleanup
opt_clean -purge

# Phase 7: Write netlist
write_verilog -noattr {netlist_path}

# Phase 8: Statistics
stat -liberty {tech_lib}

# Exit
exit 0
"""

    # Build read_verilog commands (validate each file path before embedding)
    read_cmds = []
    if params['file_list'] and os.path.exists(params['file_list']):
        with open(params['file_list'], 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    _require_path(line, f"file_list entry")
                    read_cmds.append(f"read_verilog -sv {line}")
    read_verilog_block = "\n".join(read_cmds)

    # Retiming option
    retime_cmd = ""
    if params.get('enable_retiming', False):
        retime_cmd = "abc -liberty {tech_lib} -script +retime"

    # Substitute template
    return tcl_template.format(
        timestamp=params.get('stamp', get_timestamp()),
        design_name=params['design_name'],
        top_module=params['top_module'],
        read_verilog_cmds=read_verilog_block,
        tech_lib=params['tech_lib'],
        abc_options=params.get('abc_options', '-g AND,OR,NAND,NOR,XOR'),
        retime_cmd=retime_cmd,
        netlist_path=params['netlist_path']
    )


def main():
    parser = argparse.ArgumentParser(
        description="Render Yosys TCL synthesis script"
    )
    parser.add_argument('--file-list', required=True,
                        help='Path to file_list.f')
    parser.add_argument('--sdc-path', required=True,
                        help='Path to SDC constraints')
    parser.add_argument('--tech-lib', required=True,
                        help='Path to ASAP7 Liberty library')
    parser.add_argument('--top', required=True,
                        help='Top module name')
    parser.add_argument('--design-name', required=True,
                        help='Design name for paths')
    parser.add_argument('--out', required=True,
                        help='Output TCL file path')
    parser.add_argument('--stamp', default=None,
                        help='Timestamp suffix')
    parser.add_argument('--abc-options', default='-g AND,OR,NAND,NOR,XOR',
                        help='ABC optimization options')
    parser.add_argument('--enable-retiming', action='store_true',
                        help='Enable retiming pass')

    args = parser.parse_args()

    # Determine paths
    stamp = args.stamp or get_timestamp()
    design_dir = Path(f"designs/{args.design_name}/synth")
    design_dir.mkdir(parents=True, exist_ok=True)

    netlist_path = str(design_dir / f"netlist_{stamp}.v")

    params = {
        'file_list': args.file_list,
        'sdc_path': args.sdc_path,
        'tech_lib': args.tech_lib,
        'top_module': args.top,
        'design_name': args.design_name,
        'stamp': stamp,
        'abc_options': args.abc_options,
        'enable_retiming': args.enable_retiming,
        'netlist_path': netlist_path
    }

    tcl_content = render_tcl(params)

    with open(args.out, 'w') as f:
        f.write(tcl_content)

    print(f"TCL script rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())