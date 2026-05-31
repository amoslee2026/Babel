#!/usr/bin/env python3
"""Run testbench generation from template and configuration."""
import json, sys
from pathlib import Path
from datetime import datetime, timezone

def _collect_ports(config: dict) -> list:
    """Collect DUT port descriptors from config interfaces/ports.

    Returns a list of {name, direction, width} dicts. Supports either a flat
    config['ports'] list or config['interfaces'] = [{ports: [...]}, ...].
    """
    ports = []
    seen = set()

    def add(p):
        if not isinstance(p, dict):
            return
        name = p.get("name")
        if not name or name in seen:
            return
        seen.add(name)
        ports.append({
            "name": name,
            "direction": (p.get("direction") or "input").lower(),
            "width": int(p.get("width", 1) or 1),
        })

    for p in config.get("ports", []) or []:
        add(p)
    for iface in config.get("interfaces", []) or []:
        if isinstance(iface, dict):
            for p in iface.get("ports", []) or []:
                add(p)
    return ports


def _decl(width: int) -> str:
    return "logic" if width <= 1 else f"logic [{width - 1}:0]"


def run(config_path: str, output_dir: str) -> dict:
    with open(config_path) as f:
        config = json.load(f)
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    top = config.get("top_module", "dut")
    tb_file = output / f"tb_{top}.sv"

    ports = _collect_ports(config)
    clk_names = {"clk", "clk_sys", "clock"}
    rst_names = {"rst_n", "reset_n", "rst", "reset"}

    # Signal declarations for DUT ports other than clk/rst (which are declared
    # explicitly below). Connect ALL ports, not just clk/rst.
    extra_decls = []
    conns = [".clk(clk)", ".rst_n(rst_n)"]
    for p in ports:
        name = p["name"]
        if name in clk_names:
            conns.append(f".{name}(clk)" if name != "clk" else None)
            continue
        if name in rst_names:
            conns.append(f".{name}(rst_n)" if name != "rst_n" else None)
            continue
        extra_decls.append(f"  {_decl(p['width'])} {name};")
        conns.append(f".{name}({name})")
    conns = [c for c in conns if c]
    # De-duplicate while preserving order.
    seen_c = set()
    conns = [c for c in conns if not (c in seen_c or seen_c.add(c))]

    decls_block = ("\n".join(extra_decls) + "\n") if extra_decls else ""
    conn_block = ",\n    ".join(conns)

    # Generate minimal testbench skeleton
    tb_content = f"""// Auto-generated testbench for {top}
// Generated: {datetime.now(timezone.utc).isoformat()}
`timescale 1ns/1ps

module tb_{top};
  // Clock and reset
  logic clk;
  logic rst_n;
{decls_block}
  initial clk = 0;
  always #{config.get('clock_period_ns', 10)/2} clk = ~clk;

  initial begin
    rst_n = 0;
    repeat({config.get('reset_cycles', 10)}) @(posedge clk);
    rst_n = 1;
  end

  // DUT instantiation (all ports connected)
  {top} dut (
    {conn_block}
  );

  // Smoke run: drive reset, run cycles, then finish.
  // NOTE: no functional checking here, so we do NOT claim PASS.
  initial begin
    @(posedge rst_n);
    repeat(100) @(posedge clk);
    $display("SIM DONE: smoke run completed (no functional checks)");
    $finish;
  end
endmodule
"""
    tb_file.write_text(tb_content)
    return {"status": "complete", "testbench": str(tb_file),
            "top_module": top, "ports_connected": len(conns)}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <config.json> <output_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run(sys.argv[1], sys.argv[2]), indent=2))
