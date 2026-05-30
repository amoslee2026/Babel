#!/usr/bin/env python3
"""Render floorplan TCL from MAS spec and template."""
import json, sys
from pathlib import Path

def compute_die_area(mas: dict) -> tuple:
    cells = mas.get("estimated_cells", 10000)
    util = mas.get("target_utilization", 0.70)
    core_area = (cells * 0.5) / util
    ar = mas.get("aspect_ratio", 1.0)
    w = (core_area * ar) ** 0.5
    h = core_area / w
    margin = max(5.0, w * 0.1)
    return round(w + 2 * margin, 2), round(h + 2 * margin, 2)

if __name__ == "__main__":
    mas = json.loads(Path(sys.argv[1]).read_text())
    netlist = sys.argv[2]
    design = mas.get("design_name", "top")
    w, h = compute_die_area(mas)
    margin = max(5.0, w * 0.1)
    tmpl_path = Path(__file__).parent.parent / "assets" / "floorplan.tcl.tmpl"
    tmpl = tmpl_path.read_text()
    for k, v in {
        "{{DESIGN_NAME}}": design, "{{DIE_WIDTH_UM}}": str(w),
        "{{DIE_HEIGHT_UM}}": str(h), "{{CORE_MARGIN_UM}}": str(round(margin, 2)),
        "{{NETLIST_PATH}}": netlist, "{{TECH_FILE}}": mas.get("tech_file", "libs/asap7/asap7.tech"),
        "{{IO_PAD_PLACEMENT}}": "# Auto-generated",
    }.items():
        tmpl = tmpl.replace(k, v)
    out = Path(f"{design}_floorplan.tcl")
    out.write_text(tmpl)
    print(f"Rendered: {out}")
