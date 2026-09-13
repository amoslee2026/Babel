#!/usr/bin/env python3
"""
generate_synthesis_config.py — Generate parallel synthesis config from design inputs.

This script is the entry point for the LLM-driven synthesis workflow:
1. LLM calls this script to generate synthesis_config.json
2. LLM runs run_parallel_synthesis.py with the config
3. LLM analyzes results and iterates
"""

import argparse
import json
import os
import sys
from pathlib import Path


DEFAULT_TECH_LIB = "libs/asap7/asap7sc7p5t_28/lib/asap7sc7p5t_AO_RVT_TT_nldm_201020.lib"


def find_rtl_modules(file_list_path: str) -> list:
    """Parse file_list.f and identify modules."""
    modules = []

    if not os.path.exists(file_list_path):
        return modules

    with open(file_list_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                # Extract module name from file name convention
                # e.g., rtl/NPU_top/alu.v → alu
                basename = os.path.basename(line)
                module_name = basename.replace('.v', '').replace('.sv', '')
                modules.append({
                    'file': line,
                    'name': module_name
                })

    return modules


def generate_single_module_config(
    file_list: str,
    sdc: str,
    tech_lib: str,
    top_module: str,
    design_name: str,
    output_dir: str,
    abc_options: str = '-g AND,OR,NAND,NOR,XOR',
    enable_retiming: bool = False
) -> dict:
    """Generate config for single-module synthesis."""
    output_dir = output_dir or f"designs/{design_name}/synth_parallel"

    return {
        'modules': [
            {
                'name': design_name,
                'file_list': file_list,
                'sdc': sdc,
                'tech_lib': tech_lib or DEFAULT_TECH_LIB,
                'top': top_module,
                'abc_options': abc_options,
                'enable_retiming': enable_retiming
            }
        ],
        'design_name': design_name,
        'output_dir': output_dir,
        'timeout': 600
    }


def generate_hierarchical_config(
    file_list: str,
    sdc_dir: str,
    tech_lib: str,
    modules: list,
    design_name: str,
    output_dir: str,
    abc_options: str = '-g AND,OR,NAND,NOR,XOR',
    enable_retiming: bool = False
) -> dict:
    """Generate config for hierarchical (multi-module) synthesis."""
    tech_lib = tech_lib or DEFAULT_TECH_LIB
    output_dir = output_dir or f"designs/{design_name}/synth_parallel"

    config_modules = []
    for mod in modules:
        sdc_path = os.path.join(sdc_dir, f"{mod['name']}.sdc")
        if not os.path.exists(sdc_path):
            sdc_path = os.path.join(sdc_dir, f"{design_name}.sdc")

        config_modules.append({
            'name': mod['name'],
            'file_list': mod['file'] if isinstance(mod['file'], str) else file_list,
            'sdc': sdc_path,
            'tech_lib': tech_lib,
            'top': mod.get('top', mod['name']),
            'abc_options': abc_options,
            'enable_retiming': enable_retiming
        })

    return {
        'modules': config_modules,
        'design_name': design_name,
        'output_dir': output_dir,
        'timeout': 600
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate parallel synthesis config"
    )
    parser.add_argument('--file-list', required=True,
                        help='Path to file_list.f')
    parser.add_argument('--sdc', required=True,
                        help='SDC path (file or directory)')
    parser.add_argument('--top', required=True,
                        help='Top module name')
    parser.add_argument('--design-name', required=True,
                        help='Design name')
    parser.add_argument('--tech-lib', default=DEFAULT_TECH_LIB,
                        help='ASAP7 Liberty path')
    parser.add_argument('--output-dir', default=None,
                        help='Output directory for synthesis')
    parser.add_argument('--out', required=True,
                        help='Output config JSON path')
    parser.add_argument('--abc-options', default='-g AND,OR,NAND,NOR,XOR',
                        help='ABC optimization options')
    parser.add_argument('--enable-retiming', action='store_true',
                        help='Enable retiming')
    parser.add_argument('--mode', choices=['single', 'hierarchical'],
                        default='single',
                        help='Synthesis mode')
    parser.add_argument('--modules', default=None,
                        help='JSON file listing sub-modules (for hierarchical)')

    args = parser.parse_args()

    if args.mode == 'single':
        config = generate_single_module_config(
            file_list=args.file_list,
            sdc=args.sdc,
            tech_lib=args.tech_lib,
            top_module=args.top,
            design_name=args.design_name,
            output_dir=args.output_dir,
            abc_options=args.abc_options,
            enable_retiming=args.enable_retiming
        )
    else:
        # Hierarchical mode
        if args.modules and os.path.exists(args.modules):
            with open(args.modules, 'r') as f:
                modules = json.load(f)
        else:
            modules = find_rtl_modules(args.file_list)

        config = generate_hierarchical_config(
            file_list=args.file_list,
            sdc_dir=args.sdc if os.path.isdir(args.sdc) else os.path.dirname(args.sdc),
            tech_lib=args.tech_lib,
            modules=modules,
            design_name=args.design_name,
            output_dir=args.output_dir,
            abc_options=args.abc_options,
            enable_retiming=args.enable_retiming
        )

    # Write config
    with open(args.out, 'w') as f:
        json.dump(config, f, indent=2)

    print(f"Config generated: {args.out}")
    print(f"Modules: {len(config['modules'])}")

    return 0


if __name__ == '__main__':
    sys.exit(main())