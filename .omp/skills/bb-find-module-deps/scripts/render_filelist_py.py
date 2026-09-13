#!/usr/bin/env python3
"""Render dependency-ordered file list from module analysis."""
import json, sys
from pathlib import Path

def render(deps: dict) -> str:
    """Generate ordered file_list.f content."""
    lines = ["// Auto-generated dependency-ordered file list"]
    for inc in deps.get("includes", []):
        lines.append(f"+incdir+{inc}")
    for d in deps.get("defines", []):
        lines.append(f"+define+{d}")
    lines.append("")
    for f in deps.get("ordered_files", []):
        lines.append(f)
    return "\n".join(lines)

if __name__ == "__main__":
    with open(sys.argv[1]) as f:
        deps = json.load(f)
    print(render(deps))
