#!/usr/bin/env python3
"""
parse_magic.py -- Parse Magic DRC report and count violations.

Phase 3 of bb-invoke-magic: reads DRC report, outputs JSON with violation summary.
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_drc_report(report_path: str) -> dict:
    """Parse Magic DRC report and return structured results."""
    path = Path(report_path)
    if not path.exists():
        return {'valid': False, 'error': 'REPORT_NOT_FOUND'}

    content = path.read_text()

    # Count total violations
    count_match = re.search(r'(\d+)\s+error', content, re.IGNORECASE)
    total_violations = int(count_match.group(1)) if count_match else 0

    # Extract violation types
    violation_types = []
    type_pattern = re.findall(
        r'(\w[\w\s]*?):\s*(\d+)\s*error', content, re.IGNORECASE
    )
    for vtype, count in type_pattern:
        violation_types.append({
            'type': vtype.strip(),
            'count': int(count),
        })

    # Extract individual violations with coordinates
    violations = []
    coord_pattern = re.findall(
        r'(\w[\w\s]*?)\s+at\s+\((\d+),\s*(\d+)\).*?layer\s+(\S+)',
        content, re.IGNORECASE
    )
    for vtype, x, y, layer in coord_pattern:
        violations.append({
            'type': vtype.strip(),
            'x': int(x),
            'y': int(y),
            'layer': layer,
        })

    clean = total_violations == 0 and len(violations) == 0

    return {
        'valid': True,
        'clean': clean,
        'violations': total_violations if total_violations else len(violations),
        'violation_types': violation_types,
        'violation_list': violations,
        'error': None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse Magic DRC report")
    parser.add_argument('--report', required=True, help='DRC report file path')
    parser.add_argument('--out', required=True, help='Output JSON path')
    args = parser.parse_args()

    result = parse_drc_report(args.report)
    Path(args.out).write_text(json.dumps(result, indent=2))

    if result.get('valid'):
        status = 'CLEAN' if result['clean'] else f'{result["violations"]} violations'
        print(f"DRC parsed: {status}")
        return 0
    else:
        print(f"Parse error: {result.get('error')}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
