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

    # Fail closed: the DRC report MUST contain a recognizable summary anchor.
    # Magic's DRC summary always reports an error count (e.g. "0 errors" /
    # "Total errors: N" / "N error(s)"). If no such anchor exists, the report
    # is unparseable and must NOT be treated as a clean (0-violation) result.
    count_match = re.search(r'(\d+)\s+error', content, re.IGNORECASE)
    if count_match is None:
        return {
            'valid': False,
            'parse_ok': False,
            'clean': False,
            'violations': None,
            'error': 'DRC_SUMMARY_NOT_FOUND',
        }

    # Count total violations
    total_violations = int(count_match.group(1))

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
        'parse_ok': True,
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
