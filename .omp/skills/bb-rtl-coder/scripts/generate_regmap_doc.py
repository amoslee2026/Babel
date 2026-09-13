#!/usr/bin/env python3
"""Generate register map documentation from MAS JSON."""
import json, sys
from pathlib import Path


def generate(mas_path: str, output_dir: str) -> list:
    with open(mas_path) as f:
        mas = json.load(f)
    registers = mas.get("registers", [])
    if not registers:
        print(f"No registers found in {mas_path}", file=sys.stderr)
        return []

    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    lines = ["# Register Map", "", f"Auto-generated from {Path(mas_path).name}", ""]
    lines.append("| Offset | Name | Width | Access | Description |")
    lines.append("|--------|------|-------|--------|-------------|")
    for reg in registers:
        lines.append(
            f"| 0x{reg.get('offset', 0):04X} "
            f"| {reg.get('name', 'N/A')} "
            f"| {reg.get('width', 32)} "
            f"| {reg.get('access', 'RW')} "
            f"| {reg.get('description', '')} |"
        )

    out_file = output / "regmap.md"
    out_file.write_text("\n".join(lines))
    return [str(out_file)]


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: generate_regmap_doc.py <mas.json> <output_dir>", file=sys.stderr)
        sys.exit(1)
    files = generate(sys.argv[1], sys.argv[2])
    print(json.dumps({"generated": files}))
