#!/usr/bin/env python3
"""
parse_lvs.py -- Parse Netgen LVS report and extract match status.

Phase 3 of bb-invoke-netgen: reads LVS report, outputs JSON with match/errors.
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_lvs_report(report_path: str) -> dict:
    """Parse Netgen LVS report and return structured results."""
    path = Path(report_path)
    if not path.exists():
        return {'valid': False, 'error': 'REPORT_NOT_FOUND'}

    content = path.read_text()

    # Check for unique match
    match_unique = bool(re.search(r'Circuits match uniquely', content))

    # Check for mismatch
    circuits_differ = bool(re.search(r'Circuits differ', content))

    # Extract error/discrepancy counts
    error_count = 0
    net_errors = len(re.findall(r'Net mismatch', content, re.IGNORECASE))
    device_errors = len(re.findall(r'Device mismatch', content, re.IGNORECASE))
    property_errors = len(re.findall(r'Property mismatch', content, re.IGNORECASE))
    error_count = net_errors + device_errors + property_errors

    # Extract specific discrepancies
    discrepancies = []
    if net_errors:
        for m in re.finditer(r'Net mismatch.*?(\S+)\s+(\S+)\s+(\S+)', content):
            discrepancies.append({
                'kind': 'net_mismatch',
                'instance': m.group(1),
                'schematic': m.group(2),
                'layout': m.group(3),
            })
    if device_errors:
        for m in re.finditer(r'Device mismatch.*?(\S+)\s+(\S+)\s+(\S+)', content):
            discrepancies.append({
                'kind': 'device_mismatch',
                'instance': m.group(1),
                'schematic': m.group(2),
                'layout': m.group(3),
            })

    match = match_unique and not circuits_differ

    return {
        'valid': True,
        'match': match,
        'errors': error_count,
        'net_errors': net_errors,
        'device_errors': device_errors,
        'property_errors': property_errors,
        'discrepancies': discrepancies,
        'error': None if match else 'LVS_MISMATCH',
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse Netgen LVS report")
    parser.add_argument('--report', required=True, help='LVS report file path')
    parser.add_argument('--out', required=True, help='Output JSON path')
    args = parser.parse_args()

    result = parse_lvs_report(args.report)
    Path(args.out).write_text(json.dumps(result, indent=2))

    if result.get('valid'):
        status = 'MATCH' if result['match'] else f'MISMATCH ({result["errors"]} errors)'
        print(f"LVS parsed: {status}")
        return 0 if result['match'] else 1
    else:
        print(f"Parse error: {result.get('error')}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
