#!/usr/bin/env python3
"""
run_synthesis_first_run.py — First Run Acceptable synthesis for tinystories_npu
Uses Yosys generic synthesis to verify pipeline reachability without ASAP7 library mapping.
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing

def get_idle_cpu_count():
    """Calculate idle CPU count from load average."""
    try:
        with open('/proc/loadavg', 'r') as f:
            load_avg_1min = float(f.read().split()[0])
        total_cpus = multiprocessing.cpu_count()
        idle_cpus = max(1, total_cpus - int(load_avg_1min))
        return min(idle_cpus, total_cpus)
    except:
        return max(1, multiprocessing.cpu_count() - 1)

def generate_yosys_tcl(module_name: str, rtl_file: str, output_dir: str) -> str:
    """Generate Yosys TCL script for module synthesis."""
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    tcl_path = Path(output_dir) / module_name / f"synth_{stamp}.tcl"
    tcl_path.parent.mkdir(parents=True, exist_ok=True)

    # Simple generic synthesis TCL
    tcl_content = f"""# Yosys synthesis script for {module_name}
# First Run Acceptable: Generic synthesis without library mapping

# Read RTL
read_verilog -sv {rtl_file}

# Elaborate hierarchy
hierarchy -check -top {module_name}

# Generic synthesis
synth -top {module_name}

# Optimize
opt_clean -purge

# Write netlist
write_verilog -noattr {tcl_path.parent / f"netlist_{stamp}.v"}

# Statistics
stat

exit
"""

    tcl_path.write_text(tcl_content)
    return str(tcl_path)

def run_single_synthesis(module_name: str, rtl_file: str, output_dir: str, timeout: int = 600) -> dict:
    """Run synthesis for a single module."""
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    module_dir = Path(output_dir) / module_name
    module_dir.mkdir(parents=True, exist_ok=True)

    log_path = module_dir / f"synth_{stamp}.log"
    netlist_path = module_dir / f"netlist_{stamp}.v"

    # Run Yosys with direct commands (not TCL)
    try:
        # Source EDA environment
        eda_env_cmd = "source ~/wrk/eda_opensources/eda_env.sh"

        # Build yosys command script (not TCL)
        yosys_cmds = f"""
read_verilog -sv {rtl_file}
hierarchy -check -top {module_name}
synth -top {module_name}
opt_clean -purge
write_verilog -noattr {netlist_path}
stat
"""

        cmd_file = module_dir / f"cmds_{stamp}.txt"
        cmd_file.write_text(yosys_cmds)

        result = subprocess.run(
            f"bash -c '{eda_env_cmd} && yosys -s {cmd_file}'",
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout
        )

        # Write log
        log_content = result.stdout + "\n" + result.stderr + f"\nexit:{result.returncode}"
        log_path.write_text(log_content)

        # Parse results
        cell_count = 0
        wire_count = 0
        error = None

        if "ERROR" in log_content or "Error" in log_content or result.returncode != 0:
            error_lines = [l for l in log_content.split('\n') if 'ERROR' in l or 'Error' in l]
            error = error_lines[0] if error_lines else f"Yosys exit code: {result.returncode}"

        # Extract stats from log
        for line in log_content.split('\n'):
            if "Number of cells:" in line:
                try:
                    cell_count = int(line.split(':')[1].strip())
                except:
                    pass
            if "Number of wires:" in line:
                try:
                    wire_count = int(line.split(':')[1].strip())
                except:
                    pass

        valid = result.returncode == 0 and error is None

        return {
            "module": module_name,
            "valid": valid,
            "cell_count": cell_count,
            "wire_count": wire_count,
            "chip_area_um2": 0,  # Not available without library
            "artifact_path": str(netlist_path) if netlist_path.exists() else None,
            "qor_path": str(log_path),
            "log_path": str(log_path),
            "cmd_path": str(cmd_file),
            "error": error,
            "stamp": stamp
        }

    except subprocess.TimeoutExpired:
        log_path.write_text(f"Yosys timeout after {timeout}s\nexit:timeout")
        return {
            "module": module_name,
            "valid": False,
            "error": "YOSYS_TIMEOUT",
            "stamp": stamp
        }
    except Exception as e:
        log_path.write_text(f"Exception: {str(e)}\nexit:error")
        return {
            "module": module_name,
            "valid": False,
            "error": str(e),
            "stamp": stamp
        }

def run_parallel_synthesis(rtl_files: list, output_dir: str, timeout: int = 600) -> dict:
    """Run parallel synthesis for all modules."""
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    idle_cpus = get_idle_cpu_count()

    results = []
    total_elapsed = 0

    # Prepare module list
    modules = []
    for rtl_file in rtl_files:
        if not Path(rtl_file).exists():
            continue
        basename = Path(rtl_file).name
        module_name = basename.replace('.sv', '').replace('.v', '')
        modules.append((module_name, rtl_file))

    print(f"Starting parallel synthesis for {len(modules)} modules")
    print(f"Idle CPUs: {idle_cpus}, Max parallel: {min(idle_cpus, len(modules))}")

    start_time = datetime.now()

    with ProcessPoolExecutor(max_workers=min(idle_cpus, len(modules))) as executor:
        futures = {
            executor.submit(run_single_synthesis, mod, file, output_dir, timeout): mod
            for mod, file in modules
        }

        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            status = "PASS" if result['valid'] else "FAIL"
            print(f"  [{status}] {result['module']}")

    end_time = datetime.now()
    total_elapsed = (end_time - start_time).total_seconds()

    # Generate summary
    modules_passed = sum(1 for r in results if r['valid'])
    modules_failed = len(results) - modules_passed

    summary = {
        "stamp": stamp,
        "total_elapsed": total_elapsed,
        "max_parallel": min(idle_cpus, len(modules)),
        "modules_total": len(modules),
        "modules_passed": modules_passed,
        "modules_failed": modules_failed,
        "results": results,
        "first_run_notes": [
            "Generic synthesis without ASAP7 library mapping",
            "Goal: Verify synthesis -> PD pipeline reachability",
            "Library mapping will be added in subsequent iterations"
        ]
    }

    return summary

def main():
    parser = argparse.ArgumentParser(description="First Run Parallel Synthesis")
    parser.add_argument("--rtl-dir", required=True, help="RTL directory")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    parser.add_argument("--timeout", type=int, default=600, help="Timeout per module (seconds)")

    args = parser.parse_args()

    # Collect RTL files
    rtl_path = Path(args.rtl_dir)
    rtl_files = []

    for module_dir in rtl_path.iterdir():
        if module_dir.is_dir():
            src_dir = module_dir / "src"
            if src_dir.exists():
                for sv_file in src_dir.glob("*.sv"):
                    rtl_files.append(str(sv_file))
                for v_file in src_dir.glob("*.v"):
                    rtl_files.append(str(v_file))

    print(f"Found {len(rtl_files)} RTL files")

    # Run parallel synthesis
    summary = run_parallel_synthesis(rtl_files, args.output_dir, args.timeout)

    # Write summary
    output_path = Path(args.output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    summary_file = output_path / "synthesis_summary.json"
    summary_file.write_text(json.dumps(summary, indent=2))

    print(f"\nSynthesis Summary:")
    print(f"  Total: {summary['modules_total']}")
    print(f"  Passed: {summary['modules_passed']}")
    print(f"  Failed: {summary['modules_failed']}")
    print(f"  Elapsed: {summary['total_elapsed']:.2f}s")
    print(f"  Summary: {summary_file}")

    return 0 if summary['modules_failed'] == 0 else 1

if __name__ == "__main__":
    sys.exit(main())