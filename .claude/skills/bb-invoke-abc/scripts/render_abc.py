#!/usr/bin/env python3
"""Render ABC optimization script from design parameters."""
import json, sys
from pathlib import Path

def render_script(params: dict) -> str:
    opt = params.get("optimization", "balanced")
    lines = [f"read_blif {params.get('input_blif', 'input.blif')}"]
    if params.get("genlib"):
        lines.append(f"read_lib -m {params['genlib']}")
    lines.extend(["strash"])
    if opt == "area":
        lines.extend(["rewrite", "refactor", "resub", "rewrite", "map -a -B 0.9"])
    elif opt == "delay":
        lines.extend(["ifraig", "scorr", "dc2", "dretime", "map -d -B 0.95", "buffer", "upsize"])
    else:
        lines.extend(["rewrite", "refactor", "resub", "map -B 0.9"])
    lines.append(f"write_blif {params.get('output_blif', 'output.blif')}")
    return "\n".join(lines) + "\n"

if __name__ == "__main__":
    params = json.loads(Path(sys.argv[1]).read_text()) if len(sys.argv) > 1 else {}
    script = render_script(params)
    out = Path(params.get("script_name", "abc_opt.abc"))
    out.write_text(script)
    print(f"Rendered: {out}")
