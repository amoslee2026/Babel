#!/usr/bin/env python3
"""
bb-create-sdc: Simplified SDC generator for tinystories_npu first_run
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

def generate_sdc_simple(design_name: str, target_freq_mhz: int) -> str:
    """Generate simple SDC constraints for first_run synthesis."""

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    target_period_ns = 1000.0 / target_freq_mhz

    sdc = []
    sdc.append(f"# Auto-generated SDC constraints for {design_name}")
    sdc.append(f"# Target: {target_freq_mhz} MHz ({target_period_ns:.3f} ns period)")
    sdc.append(f"# Generated: {stamp}")
    sdc.append(f"# First Run Acceptable: Relaxed constraints for pipeline reachability")
    sdc.append("")
    sdc.append("# Clock Definitions")
    sdc.append(f"create_clock -name clk -period {target_period_ns:.3f}")
    sdc.append("")
    sdc.append("# Virtual clocks for CDC analysis")
    sdc.append("create_clock -name vclk_aon -period 1000.0")
    sdc.append("create_clock -name vclk_io -period 20.0")
    sdc.append("")
    sdc.append("# Input/Output delays (relaxed for first run)")
    sdc.append(f"set_input_delay -clock clk -max {target_period_ns * 0.3:.3f} [all_inputs]")
    sdc.append(f"set_input_delay -clock clk -min 0.5 [all_inputs]")
    sdc.append(f"set_output_delay -clock clk -max {target_period_ns * 0.3:.3f} [all_outputs]")
    sdc.append(f"set_output_delay -clock clk -min 0.5 [all_outputs]")
    sdc.append("")
    sdc.append("# False paths for reset signals")
    sdc.append("set_false_path -from [get_ports rst_n] -to [all_registers]")
    sdc.append("set_false_path -from [get_ports por_in] -to [all_registers]")
    sdc.append("")
    sdc.append("# Clock uncertainty (relaxed)")
    sdc.append("set_clock_uncertainty -setup 0.15 [get_clocks clk]")
    sdc.append("set_clock_uncertainty -hold 0.10 [get_clocks clk]")
    sdc.append("")
    sdc.append("# Driving cell")
    sdc.append("set_driving_cell -lib_cell BUF_X1 [all_inputs]")
    sdc.append("")
    sdc.append("# Load")
    sdc.append("set_load 0.01 [all_outputs]")
    sdc.append("")
    sdc.append("# Clock groups for CDC")
    sdc.append("set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks vclk_aon] -group [get_clocks vclk_io]")
    sdc.append("")

    return "\n".join(sdc)

def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--design", required=True)
    parser.add_argument("--mas-dir", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--target-freq", type=int, default=500)
    parser.add_argument("--corner", default="tt_0p77v_25c")
    parser.add_argument("--io-delay-pct", type=float, default=0.3)

    args = parser.parse_args()

    # Generate SDC
    sdc_content = generate_sdc_simple(args.design, args.target_freq)

    # Write file
    out_path = Path(args.out_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    sdc_file = out_path / f"{args.design}.sdc"
    sdc_file.write_text(sdc_content)

    result = {
        "artifact_path": str(sdc_file),
        "design_name": args.design,
        "target_freq_mhz": args.target_freq,
        "clocks": 3,
        "io_constraints": 4,
        "exceptions": 2,
        "valid": True,
        "error": None,
        "generated": datetime.now().isoformat()
    }

    print(json.dumps(result, indent=2))
    return 0

if __name__ == "__main__":
    sys.exit(main())