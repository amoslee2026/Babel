#!/usr/bin/env python3
"""Render Magic TCL floorplan from design parameters."""
import sys
import json

def render_floorplan_tcl(params: dict) -> str:
    """Generate Magic TCL floorplan script."""
    dw, dh = params['die_size']['width_um'], params['die_size']['height_um']
    cw, ch = params['core_area']['width_um'], params['core_area']['height_um']
    mx, my = (dw - cw) / 2, (dh - ch) / 2

    tcl = f"""# Magic floorplan for {params['top_module']}
tech load {params.get('tech', 'asap7')}
load {params['top_module']}
box values 0 0 {dw} {dh}
box values {mx} {my} {mx + cw} {my + ch}
"""
    for pad in params.get('io_pad_list', []):
        tcl += f"place {pad['cell']} {pad['x_um']} {pad['y_um']} {pad.get('orientation', 'N')}\n"
    tcl += "save\nquit\n"
    return tcl

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: render_fp_py.py <fp_config.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r') as f:
        print(render_floorplan_tcl(json.load(f)))
