#!/usr/bin/env python3
"""
render_klayout.py — Render KLayout DRC runset script from parameters.

Generates a KLayout batch-mode DRC runset or GDSII export script.
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path


def render_drc_runset(params: dict) -> str:
    """Render KLayout DRC runset Ruby script."""
    template = """# KLayout DRC Runset
# Generated: {timestamp}
# Design: {gds_path}
# Rule deck: {rule_deck}

source = "{gds_path}"
report_file = "{output_path}"

# Load layout
layout = RBA::Layout::new(source)

# Run DRC with rule deck
load("{rule_deck}")

# Write report
report = RBA::Report::new
{rule_includes}
report.save(report_file)

puts "DRC complete. Report: " + report_file
"""

    # Include specific rules or all
    rule_includes = ""
    if params.get('rules'):
        for rule in params['rules']:
            rule_includes += f'# Rule: {rule}\n'
    else:
        rule_includes = "# All rules from deck"

    return template.format(
        timestamp=datetime.now().strftime("%Y%m%d_%H%M%S"),
        gds_path=params['gds_path'],
        rule_deck=params['rule_deck'],
        output_path=params['output_path'],
        rule_includes=rule_includes
    )


def render_gdsii_export(params: dict) -> str:
    """Render KLayout GDSII export macro script."""
    template = """# KLayout GDSII Export
# Generated: {timestamp}

app = RBA::Application::instance
mw = app.main_window

# Load layout
layout_view = mw.load_layout("{input_path}")

# Set technology
layout_view.technology = "{technology}"

# Export GDSII
save_opts = RBA::SaveLayoutOptions::new
save_opts.format = "GDS2"
{layer_map}
layout_view.save_layout("{output_path}", save_opts)

puts "GDSII exported: {output_path}"
"""

    layer_map = ""
    if params.get('layer_map_path'):
        layer_map = f'save_opts.set_layer_map(RBA::LayerMap::from_string(File.read("{params["layer_map_path"]}")))'

    return template.format(
        timestamp=datetime.now().strftime("%Y%m%d_%H%M%S"),
        input_path=params['input_path'],
        technology=params.get('technology', 'ASAP7'),
        layer_map=layer_map,
        output_path=params['output_path']
    )


def main():
    parser = argparse.ArgumentParser(
        description="Render KLayout DRC/export script"
    )
    parser.add_argument('--mode', required=True, choices=['drc', 'export'],
                        help='Operation mode')
    parser.add_argument('--gds-path', '--input-path', required=True,
                        help='Input GDSII/layout path')
    parser.add_argument('--rule-deck', default=None,
                        help='DRC rule deck path (drc mode)')
    parser.add_argument('--output-path', required=True,
                        help='Output file path')
    parser.add_argument('--technology', default='ASAP7',
                        help='Technology name')
    parser.add_argument('--layer-map', default=None,
                        help='Layer map file path (export mode)')
    parser.add_argument('--out', required=True,
                        help='Output script file path')

    args = parser.parse_args()

    if args.mode == 'drc':
        params = {
            'gds_path': args.gds_path,
            'rule_deck': args.rule_deck or 'drc_runset.drc',
            'output_path': args.output_path,
            'rules': []
        }
        content = render_drc_runset(params)
    else:
        params = {
            'input_path': args.gds_path,
            'output_path': args.output_path,
            'technology': args.technology,
            'layer_map_path': args.layer_map
        }
        content = render_gdsii_export(params)

    with open(args.out, 'w') as f:
        f.write(content)

    print(f"KLayout script rendered: {args.out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
