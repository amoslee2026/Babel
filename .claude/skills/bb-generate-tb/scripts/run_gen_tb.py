#!/usr/bin/env python3
"""Run testbench generation from template and configuration."""
import json, sys
from pathlib import Path
from datetime import datetime, timezone

def run(config_path: str, output_dir: str) -> dict:
    with open(config_path) as f:
        config = json.load(f)
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    top = config.get("top_module", "dut")
    tb_file = output / f"tb_{top}.sv"

    # Generate minimal testbench skeleton
    tb_content = f"""// Auto-generated testbench for {top}
// Generated: {datetime.now(timezone.utc).isoformat()}
`timescale 1ns/1ps

module tb_{top};
  // Clock and reset
  logic clk;
  logic rst_n;

  initial clk = 0;
  always #{config.get('clock_period_ns', 10)/2} clk = ~clk;

  initial begin
    rst_n = 0;
    repeat({config.get('reset_cycles', 10)}) @(posedge clk);
    rst_n = 1;
  end

  // DUT instantiation
  {top} dut (
    .clk(clk),
    .rst_n(rst_n)
  );

  // Test sequences
  initial begin
    @(posedge rst_n);
    repeat(100) @(posedge clk);
    $display("PASS: Basic smoke test completed");
    $finish;
  end
endmodule
"""
    tb_file.write_text(tb_content)
    return {"status": "complete", "testbench": str(tb_file), "top_module": top}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <config.json> <output_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run(sys.argv[1], sys.argv[2]), indent=2))
