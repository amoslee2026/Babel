#!/usr/bin/env python3
"""Render testbench generation configuration from DUT parameters."""
import json, sys

def render(dut_params: dict) -> dict:
    return {
        "top_module": dut_params.get("top_module", "dut"),
        "clock_period_ns": dut_params.get("clock_period_ns", 10),
        "reset_cycles": dut_params.get("reset_cycles", 10),
        "testbench_style": dut_params.get("tb_style", "cocotb"),
        "coverage_enabled": dut_params.get("coverage", True),
        "interfaces": dut_params.get("interfaces", []),
    }

if __name__ == "__main__":
    with open(sys.argv[1]) as f:
        params = json.load(f)
    print(json.dumps(render(params), indent=2))
