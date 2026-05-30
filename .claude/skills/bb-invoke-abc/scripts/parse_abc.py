#!/usr/bin/env python3
"""
parse_abc.py — Parse ABC optimization report.

Extracts area, delay, gate count before/after. Outputs JSON.
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_abc_report(report_path: str) -> dict:
    """Parse ABC optimization log and extract metrics."""
    if not Path(report_path).exists():
        return {
            'valid': False,
            'error': 'REPORT_NOT_FOUND',
            'area_reduction': 0.0,
            'delay_improvement': 0.0,
            'gate_count': 0
        }

    with open(report_path, 'r') as f:
        content = f.read()

    # Extract area values (before/after)
    area_before = 0.0
    area_after = 0.0
    area_pattern = r'(?:i?O|Output|Area)\s*=?\s*([\d.]+)'
    area_matches = re.findall(area_pattern, content)
    if len(area_matches) >= 2:
        area_before = float(area_matches[0])
        area_after = float(area_matches[-1])

    # Extract delay values (before/after)
    delay_before = 0.0
    delay_after = 0.0
    delay_pattern = r'(?:D|Delay|delay)\s*=?\s*([\d.]+)'
    delay_matches = re.findall(delay_pattern, content)
    if len(delay_matches) >= 2:
        delay_before = float(delay_matches[0])
        delay_after = float(delay_matches[-1])

    # Extract gate count
    gate_count = 0
    gate_pattern = r'(?:gate|Gate|node|Node)s?\s*[:=]?\s*(\d+)'
    gate_matches = re.findall(gate_pattern, content)
    if gate_matches:
        gate_count = int(gate_matches[-1])

    # Also check for ABC's gate type stats
    for gate_type in ['and', 'xor', 'inv', 'buf', 'ff']:
        pat = rf'{gate_type}\s*=\s*(\d+)'
        m = re.search(pat, content, re.IGNORECASE)
        if m:
            gate_count += int(m.group(1))

    # Compute improvements
    area_reduction = 0.0
    if area_before > 0:
        area_reduction = ((area_before - area_after) / area_before) * 100

    delay_improvement = 0.0
    if delay_before > 0:
        delay_improvement = ((delay_before - delay_after) / delay_before) * 100

    return {
        'valid': True,
        'area_before': area_before,
        'area_after': area_after,
        'area_reduction': round(area_reduction, 2),
        'delay_before': delay_before,
        'delay_after': delay_after,
        'delay_improvement': round(delay_improvement, 2),
        'gate_count': gate_count,
        'error': None
    }


def main():
    parser = argparse.ArgumentParser(
        description="Parse ABC optimization report"
    )
    parser.add_argument('--report', required=True,
                        help='ABC report file path')
    parser.add_argument('--out', required=True,
                        help='Output JSON path')

    args = parser.parse_args()
    result = parse_abc_report(args.report)

    with open(args.out, 'w') as f:
        json.dump(result, f, indent=2)

    print(f"ABC report parsed: {args.out}")
    print(f"Area reduction: {result['area_reduction']}%")
    print(f"Delay improvement: {result['delay_improvement']}%")
    print(f"Gate count: {result['gate_count']}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
