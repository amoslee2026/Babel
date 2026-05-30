#!/usr/bin/env python3
"""
parse_qrouter.py — Parse QRouter routing report.

Extracts routed nets, failed nets, DRC violations. Outputs JSON.
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_qrouter_report(report_path: str) -> dict:
    """Parse QRouter routing report and extract metrics."""
    if not Path(report_path).exists():
        return {
            'valid': False,
            'error': 'REPORT_NOT_FOUND',
            'routed': 0,
            'failed': 0,
            'violations': [],
            'complete': False
        }

    with open(report_path, 'r') as f:
        content = f.read()

    # Extract routed nets count
    routed_match = re.search(r'(\d+)\s+(?:nets?|routes?)\s+routed', content, re.IGNORECASE)
    routed = int(routed_match.group(1)) if routed_match else 0

    # Extract failed nets
    failed_match = re.search(r'(\d+)\s+(?:nets?|routes?)\s+(?:failed|unrouteable)', content, re.IGNORECASE)
    failed = int(failed_match.group(1)) if failed_match else 0

    # Extract DRC violations
    violations = []
    drc_pattern = r'(DRC|violation|error).*?(\w+_\w+).*?(\d+)'
    for match in re.finditer(drc_pattern, content, re.IGNORECASE):
        violations.append({
            'type': match.group(2),
            'count': int(match.group(3))
        })

    # Check completion
    complete_match = re.search(r'(completed|finished|done)', content, re.IGNORECASE)
    complete = bool(complete_match) and failed == 0

    return {
        'valid': True,
        'routed': routed,
        'failed': failed,
        'violations': violations,
        'complete': complete,
        'error': None
    }


def main():
    parser = argparse.ArgumentParser(
        description="Parse QRouter routing report"
    )
    parser.add_argument('--report', required=True,
                        help='QRouter report file path')
    parser.add_argument('--out', required=True,
                        help='Output JSON path')

    args = parser.parse_args()

    result = parse_qrouter_report(args.report)

    with open(args.out, 'w') as f:
        json.dump(result, f, indent=2)

    print(f"QRouter report parsed: {args.out}")
    print(f"Routed: {result['routed']}, Failed: {result['failed']}")
    print(f"Complete: {result['complete']}")

    return 0 if result['complete'] else 1


if __name__ == '__main__':
    sys.exit(main())
