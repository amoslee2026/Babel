#!/usr/bin/env python3
"""
render_verilator_sh.py -- Generate shell script for Verilator compilation and simulation.

Phase 1 of bb-invoke-verilator: renders executable bash script from parameters.
"""

import json
import re
import shlex
import sys
from datetime import datetime
from pathlib import Path

# Defense-in-depth identifier validation (D8-04 / D8-03).
# Schema validation at the input-schema hook is the primary boundary; these
# checks catch any case where a renderer is invoked outside that path (e.g.
# unit tests, ad-hoc scripts).
_SLUG = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
_SV_ID = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,63}$")
_PATH = re.compile(r"^[A-Za-z0-9_/.,+\-]+$")


def _require_slug(v: str, field: str) -> str:
    if not _SLUG.fullmatch(str(v)):
        raise ValueError(f"{field} must be a slug ([a-z0-9][a-z0-9_-]{{0,31}}); got {v!r}")
    return str(v)


def _require_sv_id(v: str, field: str) -> str:
    if not _SV_ID.fullmatch(str(v)):
        raise ValueError(f"{field} must be a SystemVerilog identifier; got {v!r}")
    return str(v)


def _require_path(v: str, field: str) -> str:
    if not _PATH.fullmatch(str(v)):
        raise ValueError(f"{field} contains unsafe characters; got {v!r}")
    return str(v)


def render(params: dict) -> str:
    """Render Verilator simulation shell script."""
    design_name = _require_slug(params["design_name"], "design_name")
    file_list = _require_path(params["file_list"], "file_list")
    tb_top = _require_sv_id(params["tb_top"], "tb_top")
    stamp = params.get("stamp", datetime.now().strftime("%Y%m%d-%H%M%S"))
    seed = int(params.get("seed", 1))
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
