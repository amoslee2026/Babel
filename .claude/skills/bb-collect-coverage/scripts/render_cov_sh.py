#!/usr/bin/env python3
"""Render coverage collection shell script."""
import json, sys

def render(params: dict) -> str:
    top = params.get("top_module", "dut")
    sim_dir = params.get("sim_dir", "sim")
    lines = [
        "#!/bin/bash",
        f"# Coverage collection for {top}",
        "set -euo pipefail",
        "",
        f"verilator --coverage --timing -cc {top}.sv --exe tb_{top}.cpp",
        f"make -C obj_dir -f V{top}.mk",
        f"./obj_dir/V{top}",
        f"verilator_coverage --annotate coverage.dat -o coverage_annotated",
        f"echo 'Coverage collection complete'",
    ]
    return "\n".join(lines)

if __name__ == "__main__":
    with open(sys.argv[1]) as f:
        params = json.load(f)
    print(render(params))
