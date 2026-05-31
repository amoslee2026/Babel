#!/usr/bin/env python3
"""
parse_qor.py — Parse Yosys synthesis log and generate QoR JSON.

Phase 3 of bb-invoke-yosys: extracts metrics from log file.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


def parse_chip_area(log_content: str, top_module: str):
    """Extract chip area from stat output. Returns None if not found."""
    pattern = rf"Chip area for module {top_module}:\s+([\d.]+)"
    match = re.search(pattern, log_content)
    if match:
        return float(match.group(1))
    return None


def parse_cell_count(log_content: str):
    """Extract cell count from stat output. Returns None if not found."""
    pattern = r"Number of cells:\s+(\d+)"
    match = re.search(pattern, log_content)
    if match:
        return int(match.group(1))
    return None


def parse_wire_count(log_content: str):
    """Extract wire count from stat output. Returns None if not found."""
    pattern = r"Number of wires:\s+(\d+)"
    match = re.search(pattern, log_content)
    if match:
        return int(match.group(1))
    return None


def parse_errors(log_content: str) -> list:
    """Extract ERROR messages from log."""
    errors = []
    pattern = r"(ERROR|Error):.*"
    matches = re.findall(pattern, log_content)
    return matches


def parse_warnings(log_content: str) -> list:
    """Extract warning types from log."""
    warnings = []
    warning_types = ['MULTIDRIVEN', 'WIDTHEXPAND', 'UNUSED', 'latch inferred']

    for wtype in warning_types:
        count = len(re.findall(wtype, log_content, re.IGNORECASE))
        if count > 0:
            warnings.append({'type': wtype, 'count': count})

    return warnings


def parse_qor(log_path: str, netlist_path: str, top_module: str) -> dict:
    """Parse Yosys log and return QoR dict."""

    if not os.path.exists(log_path):
        return {
            'valid': False,
            'error': 'LOG_NOT_FOUND',
            'netlist_path': netlist_path
        }

    with open(log_path, 'r') as f:
        log_content = f.read()

    # Check for exit code
    exit_match = re.search(r'exit:(\d+)', log_content)
    exit_code = int(exit_match.group(1)) if exit_match else 1

    if exit_code != 0:
        return {
            'valid': False,
            'error': f'YOSYS_EXIT_{exit_code}',
            'netlist_path': netlist_path
        }

    # Extract metrics
    chip_area = parse_chip_area(log_content, top_module)
    cell_count = parse_cell_count(log_content)
    wire_count = parse_wire_count(log_content)
    errors = parse_errors(log_content)
    warnings = parse_warnings(log_content)

    # Postcondition: a successful synthesis MUST produce a non-empty netlist
    # file. Existence + non-zero size is required before trusting any QoR.
    netlist_exists = os.path.exists(netlist_path)
    netlist_size = os.path.getsize(netlist_path) if netlist_exists else 0
    netlist_valid = netlist_exists and netlist_size > 0

    # Fail closed on each independent failure mode:
    #  - netlist missing or empty            -> not a real success
    #  - QoR (area/cells) could not be parsed -> metrics untrustworthy
    #  - cell_count == 0 on a "success"       -> empty/optimized-away design
    #  - any ERROR in the log
    qor_parse_ok = chip_area is not None and cell_count is not None
    cells_ok = cell_count is not None and cell_count > 0

    if not netlist_valid:
        fail_reason = 'NETLIST_MISSING' if not netlist_exists else 'NETLIST_EMPTY'
    elif not qor_parse_ok:
        fail_reason = 'QOR_PARSE_FAILED'
    elif not cells_ok:
        fail_reason = 'ZERO_CELLS'
    elif errors:
        fail_reason = errors[0]
    else:
        fail_reason = None

    valid = fail_reason is None

    return {
        'valid': valid,
        'parse_ok': qor_parse_ok,
        'netlist_path': netlist_path,
        'netlist_size': netlist_size,
        'chip_area_um2': chip_area,
        'cell_count': cell_count,
        'wire_count': wire_count,
        'errors': errors,
        'warnings': warnings,
        'error': fail_reason,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Parse Yosys QoR from log"
    )
    parser.add_argument('--log', required=True,
                        help='Log file path')
    parser.add_argument('--netlist', required=True,
                        help='Netlist file path')
    parser.add_argument('--top', required=True,
                        help='Top module name')
    parser.add_argument('--out', required=True,
                        help='Output JSON path')

    args = parser.parse_args()

    qor = parse_qor(args.log, args.netlist, args.top)

    # Write JSON output
    with open(args.out, 'w') as f:
        json.dump(qor, f, indent=2)

    # Also create canonical symlink/copy (without stamp)
    out_path = Path(args.out)
    canonical_name = out_path.name.split('_')[0] + '.json'
    canonical_path = out_path.parent / canonical_name

    # Copy to canonical location
    import shutil
    shutil.copy(args.out, str(canonical_path))

    # Same for netlist
    netlist_path = Path(args.netlist)
    canonical_netlist = netlist_path.parent / 'netlist.v'
    shutil.copy(args.netlist, str(canonical_netlist))

    print(f"QoR JSON saved: {args.out}")
    print(f"Canonical QoR: {canonical_path}")
    print(f"Canonical netlist: {canonical_netlist}")

    if qor['valid']:
        print(f"Cell count: {qor['cell_count']}")
        print(f"Chip area: {qor['chip_area_um2']:.2f} µm²")
        return 0
    else:
        print(f"Error: {qor['error']}")
        return 1


if __name__ == '__main__':
    sys.exit(main())