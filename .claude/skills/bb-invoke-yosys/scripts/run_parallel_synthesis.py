#!/usr/bin/env python3
"""
run_parallel_synthesis.py — Execute parallel synthesis for multiple modules.

Core script for LLM-driven synthesis workflow:
1. Detect idle CPU count
2. Generate synthesis scripts for each module
3. Run parallel synthesis (max parallel = idle CPU count)
4. Collect results for LLM analysis

Usage:
    python3 run_parallel_synthesis.py --config synthesis_config.json

Config format:
{
    "modules": [
        {
            "name": "uart_tx",
            "file_list": "designs/uart/rtl/file_list.f",
            "sdc": "designs/uart/constraints/uart.sdc",
            "tech_lib": "libs/asap7/.../asap7sc7p5t.lib",
            "top": "uart_tx"
        },
        ...
    ],
    "design_name": "uart",
    "output_dir": "designs/uart/synth_parallel"
}
"""

import argparse
import json
import os
import subprocess
import sys
import time
import multiprocessing
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

import render_yosys_tcl
import run_yosys
import parse_qor


def get_idle_cpu_count():
    """Get number of idle CPUs for parallel synthesis."""
    total_cpus = multiprocessing.cpu_count()

    # Try to get actual load
    try:
        # Get 1-minute load average
        with open('/proc/loadavg', 'r') as f:
            load_avg = float(f.read().split()[0])

        idle_cpus = max(1, int(total_cpus - load_avg))
        return idle_cpus
    except:
        # Fallback: use 75% of total CPUs
        return max(1, int(total_cpus * 0.75))


def prepare_module(module: dict, output_dir: str, stamp: str) -> dict:
    """Prepare synthesis script for a module."""
    module_dir = Path(output_dir) / module['name']
    module_dir.mkdir(parents=True, exist_ok=True)

    tcl_path = str(module_dir / f"yosys_{stamp}.tcl")
    log_path = str(module_dir / f"yosys_{stamp}.log")
    netlist_path = str(module_dir / f"netlist_{stamp}.v")
    qor_path = str(module_dir / f"qor_{stamp}.json")

    params = {
        'file_list': module['file_list'],
        'sdc_path': module['sdc'],
        'tech_lib': module['tech_lib'],
        'top_module': module['top'],
        'design_name': module['name'],
        'stamp': stamp,
        'abc_options': module.get('abc_options', '-g AND,OR,NAND,NOR,XOR'),
        'enable_retiming': module.get('enable_retiming', False),
        'netlist_path': netlist_path
    }

    # Render TCL script
    tcl_content = render_yosys_tcl.render_tcl(params)
    with open(tcl_path, 'w') as f:
        f.write(tcl_content)

    return {
        'name': module['name'],
        'tcl_path': tcl_path,
        'log_path': log_path,
        'netlist_path': netlist_path,
        'qor_path': qor_path,
        'top': module['top']
    }


def synthesize_module(task: dict, timeout: int) -> dict:
    """Run synthesis for a single module."""
    name = task['name']
    tcl_path = task['tcl_path']
    log_path = task['log_path']
    netlist_path = task['netlist_path']
    qor_path = task['qor_path']
    top = task['top']

    print(f"[{name}] Starting synthesis...")

    # Source EDA env and run yosys
    env, error = run_yosys.source_eda_env()
    if error:
        return {
            'name': name,
            'valid': False,
            'error': f'EDA_ENV_FAILED: {error}'
        }

    # Validate version
    valid, error = run_yosys.validate_yosys_version(env)
    if not valid:
        return {
            'name': name,
            'valid': False,
            'error': error
        }

    # Run synthesis
    result = run_yosys.run_yosys(tcl_path, log_path, timeout, env)

    if not result['success']:
        return {
            'name': name,
            'valid': False,
            'error': result['error'],
            'elapsed': result['elapsed']
        }

    # Parse QoR
    qor = parse_qor.parse_qor(log_path, netlist_path, top)
    qor['name'] = name
    qor['elapsed'] = result['elapsed']

    # Save QoR JSON
    with open(qor_path, 'w') as f:
        json.dump(qor, f, indent=2)

    print(f"[{name}] Completed: cells={qor['cell_count']}, area={qor['chip_area_um2']:.2f}µm²")

    return qor


def run_parallel_synthesis(config: dict) -> dict:
    """Execute parallel synthesis for all modules."""
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = config['output_dir']
    modules = config['modules']
    timeout = config.get('timeout', 600)

    # Get idle CPU count
    max_parallel = get_idle_cpu_count()
    print(f"Idle CPUs: {max_parallel} / {multiprocessing.cpu_count()}")
    print(f"Modules to synthesize: {len(modules)}")

    # Prepare all scripts first (script generation phase)
    tasks = []
    for module in modules:
        task = prepare_module(module, output_dir, stamp)
        tasks.append(task)

    # Run parallel synthesis
    results = []
    start_time = time.time()

    with ProcessPoolExecutor(max_workers=max_parallel) as executor:
        futures = {
            executor.submit(synthesize_module, task, timeout): task['name']
            for task in tasks
        }

        for future in as_completed(futures):
            name = futures[future]
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                results.append({
                    'name': name,
                    'valid': False,
                    'error': str(e)
                })

    elapsed_total = time.time() - start_time

    # Generate summary report
    summary = {
        'stamp': stamp,
        'total_elapsed': elapsed_total,
        'max_parallel': max_parallel,
        'modules_total': len(modules),
        'modules_passed': sum(1 for r in results if r.get('valid', False)),
        'modules_failed': sum(1 for r in results if not r.get('valid', False)),
        'results': results
    }

    # Save summary
    summary_path = Path(output_dir) / f"synthesis_summary_{stamp}.json"
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2)

    # Create canonical summary.json
    canonical_path = Path(output_dir) / "synthesis_summary.json"
    with open(canonical_path, 'w') as f:
        json.dump(summary, f, indent=2)

    print(f"\n=== Synthesis Summary ===")
    print(f"Total time: {elapsed_total:.2f}s")
    print(f"Passed: {summary['modules_passed']} / {summary['modules_total']}")
    print(f"Summary: {summary_path}")

    return summary


def main():
    parser = argparse.ArgumentParser(
        description="Run parallel Yosys synthesis"
    )
    parser.add_argument('--config', required=True,
                        help='JSON config file path')
    parser.add_argument('--timeout', type=int, default=600,
                        help='Timeout per module (seconds)')

    args = parser.parse_args()

    if not os.path.exists(args.config):
        print(f"Error: Config file not found: {args.config}")
        return 1

    with open(args.config, 'r') as f:
        config = json.load(f)

    config['timeout'] = args.timeout

    summary = run_parallel_synthesis(config)

    return 0 if summary['modules_failed'] == 0 else 1


if __name__ == '__main__':
    sys.exit(main())