#!/usr/bin/env python3
"""Generate SVA assertions for register map validation."""
import json, sys
from pathlib import Path


def generate(mas_path: str, output_dir: str) -> list:
    with open(mas_path) as f:
        mas = json.load(f)
    registers = mas.get("registers", [])
    if not registers:
        return []

    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    module_name = mas.get("module_name", "unknown")
    lines = [
        f"// Auto-generated register assertions for {module_name}",
        f"// Source: {Path(mas_path).name}",
        ""
    ]
    for reg in registers:
        name = reg.get("name", "REG").upper()
        width = reg.get("width", 32)
        access = reg.get("access", "RW")
        if access == "RO":
            lines.append(f"// {name}: Read-only, width={width}")
        elif access == "RW":
            lines.append(f"// {name}: Read-write, width={width}")
            lines.append(f"property {name}_write_read;")
            lines.append(f"  @(posedge clk) disable iff (!rst_n)")
            lines.append(
                f"  (wr_en && addr == {reg.get('offset', 0)}) "
                f"|-> ##1 ({name}_reg == wr_data[{width-1}:0]);"
            )
            lines.append(f"endproperty")
            lines.append(f"assert property ({name}_write_read);")
            lines.append("")

    out_file = output / f"{module_name}_regmap_assertions.sv"
    out_file.write_text("\n".join(lines))
    return [str(out_file)]


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: generate_regmap_assertions.py <mas.json> <output_dir>", file=sys.stderr)
        sys.exit(1)
    files = generate(sys.argv[1], sys.argv[2])
    print(json.dumps({"generated": files}))
