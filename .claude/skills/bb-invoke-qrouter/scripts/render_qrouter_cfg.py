#!/usr/bin/env python3
"""
render_qrouter_cfg.py — Render QRouter configuration file.

Generates QRouter config from design parameters.
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path


def render_config(params: dict) -> str:
    """Render QRouter configuration script."""
    cfg_template = """# QRouter Configuration Script
# Generated: {timestamp}
# Design: {design_name}

# Read LEF files
{lef_reads}

# Read DEF file
read_def {def_path}

# Set routing layers
layers {min_layer} {max_layer}

# Pin assignments
{pin_assignments}

# Route design
route

# Write routed DEF
write_def {output_def}

# Generate report
report {report_path}

quit
"""

    # Build LEF read commands
    lef_reads = '\n'.join([f"read_lef {lef}" for lef in params['lef_paths']])

    # Build pin assignments
    pin_lines = []
    for pin, layer, x, y in params.get('pins', []):
        pin_lines.append(f"pin {pin} {layer} {x} {y}")
    pin_assignments = '\n'.join(pin_lines) if pin_lines else "# No explicit pin assignments"

    return cfg_template.format(
        timestamp=datetime.now().strftime("%Y%m%d_%H%M%S"),
        design_name=params['design_name'],
        lef_reads=lef_reads,
        def_path=params['def_path'],
        min_layer=params.get('min_layer', 'Metal2'),
        max_layer=params.get('max_layer', 'Metal7'),
        pin_assignments=pin_assignments,
        output_def=params['output_def'],
        report_path=params['report_path']
    )


def main():
    parser = argparse.ArgumentParser(
        description="Render QRouter configuration"
    )
    parser.add_argument('--design-name', required=True,
                        help='Design name')
    parser.add_argument('--lef-paths', nargs='+', required=True,
                        help='LEF file paths')
    parser.add_argument('--def-path', required=True,
                        help='Input DEF file path')
    parser.add_argument('--output-def', required=True,
                        help='Output routed DEF path')
    parser.add_argument('--report-path', required=True,
                        help='Report output path')
    parser.add_argument('--out', required=True,
                        help='Output config file path')
    parser.add_argument('--min-layer', default='Metal2',
                        help='Minimum routing layer')
    parser.add_argument('--max-layer', default='Metal7',
                        help='Maximum routing layer')

    args = parser.parse_args()

    params = {
        'design_name': args.design_name,
        'lef_paths': args.lef_paths,
        'def_path': args.def_path,
        'output_def': args.output_def,
        'report_path': args.report_path,
        'min_layer': args.min_layer,
        'max_layer': args.max_layer,
        'pins': []
    }

    cfg_content = render_config(params)

    with open(args.out, 'w') as f:
        f.write(cfg_content)

    print(f"QRouter config rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
