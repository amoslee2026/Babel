#!/usr/bin/env python3
"""
render_verilator_sh.py -- Generate shell script for Verilator compilation and simulation.

Phase 1 of bb-invoke-verilator: renders executable bash script from parameters.
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def render(params: dict) -> str:
    """Render Verilator simulation shell script."""
    design_name = params["design_name"]
    file_list = params["file_list"]
    tb_top = params["tb_top"]
    stamp = params.get("stamp", datetime.now().strftime("%Y%m%d-%H%M%S"))
    seed = params.get("seed", 1)
    enable_vcd = params.get("enable_vcd", True)
    sim_time = params.get("sim_time", "")

    obj_dir = f"designs/{design_name}/sim_results/obj_dir_{stamp}"
    sim_bin = f"designs/{design_name}/sim_results/obj_dir_{stamp}/sim_{stamp}"
    log_path = f"designs/{design_name}/sim_results/{stamp}.log"
    coverage_dat = f"designs/{design_name}/sim_results/coverage.dat"

    vcd_flag = "--trace --trace-structs" if enable_vcd else ""
    time_flag = f"--time-resolution-unit {sim_time}" if sim_time else ""

    script = f"""#!/bin/bash
set -euo pipefail
source ~/wrk/eda_opensources/eda_env.sh

# Verilator version check
verilator --version | grep -q "Verilator 5.012" \\
  || {{ echo "VERSION_MISMATCH"; exit 1; }}

# Phase 1: Compile RTL + TB
verilator --binary --coverage {vcd_flag} {time_flag} \\
  -f {file_list} {tb_top} \\
  --top-module tb_top \\
  -Mdir {obj_dir}/ \\
  -o sim_{stamp} -CFLAGS "-O2" -j 4

# Phase 2: Run simulation
./{sim_bin} \\
  +rand_seed={seed} 2>&1 | tee {log_path}

# Phase 3: Merge coverage data
verilator_coverage \\
  {obj_dir}/coverage.dat \\
  --write {coverage_dat}

echo "SIM_COMPLETE"
"""
    return script


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <params.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        params = json.load(f)

    script_content = render(params)

    # Write to output path if specified
    if len(sys.argv) >= 3:
        out_path = Path(sys.argv[2])
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(script_content)
        out_path.chmod(0o755)
        print(f"Script rendered: {out_path}", file=sys.stderr)
    else:
        print(script_content)
