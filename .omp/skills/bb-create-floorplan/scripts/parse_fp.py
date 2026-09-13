#!/usr/bin/env python3
"""Parse floorplan results and generate JSON report."""
import sys
import re
import json

def parse_floorplan_output(log_file: str) -> dict:
    """Parse Magic floorplan output."""
    with open(log_file, 'r') as f:
        content = f.read()

    result = {'die_area': None, 'core_area': None, 'utilization': None, 'io_pads': [], 'status': 'unknown'}

    die_match = re.search(r'Die area:\s+([\d.]+)\s+x\s+([\d.]+)\s+um', content)
    if die_match:
        w, h = float(die_match.group(1)), float(die_match.group(2))
        result['die_area'] = {'width_um': w, 'height_um': h, 'area_um2': w * h}

    core_match = re.search(r'Core area:\s+([\d.]+)\s+x\s+([\d.]+)\s+um', content)
    if core_match:
        w, h = float(core_match.group(1)), float(core_match.group(2))
        result['core_area'] = {'width_um': w, 'height_um': h, 'area_um2': w * h}

    if result['die_area'] and result['core_area']:
        result['utilization'] = round(result['core_area']['area_um2'] / result['die_area']['area_um2'] * 100, 2)

    for m in re.finditer(r'IO pad:\s+(\w+)\s+at\s+\(([\d.]+),\s*([\d.]+)\)', content):
        result['io_pads'].append({'name': m.group(1), 'x_um': float(m.group(2)), 'y_um': float(m.group(3))})

    result['status'] = 'pass' if result['die_area'] else 'fail'
    return result

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_fp.py <floorplan_log>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_floorplan_output(sys.argv[1]), indent=2))
