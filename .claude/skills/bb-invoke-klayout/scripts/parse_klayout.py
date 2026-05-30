#!/usr/bin/env python3
"""
parse_klayout.py — Parse KLayout DRC report (XML format).

Extracts violation counts by rule. Outputs JSON with clean bool.
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def parse_drc_report(report_path: str) -> dict:
    """Parse KLayout DRC XML report and extract violations."""
    if not Path(report_path).exists():
        return {
            'valid': False,
            'error': 'REPORT_NOT_FOUND',
            'clean': False,
            'violations': {},
            'total': 0
        }

    try:
        tree = ET.parse(report_path)
        root = tree.getroot()
    except ET.ParseError:
        return {
            'valid': False,
            'error': 'XML_PARSE_ERROR',
            'clean': False,
            'violations': {},
            'total': 0
        }

    violations = {}
    total = 0

    # KLayout DRC XML structure:
    # <report><categories><category><name>...</name><items><item>...
    for cat in root.iter('category'):
        name_elem = cat.find('name')
        if name_elem is None:
            continue
        rule_name = name_elem.text.strip() if name_elem.text else 'unknown'
        items = cat.findall('.//item')
        count = len(items)
        if count > 0:
            violations[rule_name] = count
            total += count

    # Alternative flat structure: <item><category>...</category>
    if not violations:
        for item in root.iter('item'):
            cat_elem = item.find('category')
            if cat_elem is not None and cat_elem.text:
                rule = cat_elem.text.strip()
                violations[rule] = violations.get(rule, 0) + 1
                total += 1

    return {
        'valid': True,
        'clean': total == 0,
        'violations': violations,
        'total': total,
        'error': None
    }


def main():
    parser = argparse.ArgumentParser(
        description="Parse KLayout DRC report"
    )
    parser.add_argument('--report', required=True,
                        help='DRC report XML path')
    parser.add_argument('--out', required=True,
                        help='Output JSON path')

    args = parser.parse_args()
    result = parse_drc_report(args.report)

    with open(args.out, 'w') as f:
        json.dump(result, f, indent=2)

    print(f"DRC report parsed: {args.out}")
    print(f"Clean: {result['clean']}, Total violations: {result['total']}")

    if result['violations']:
        for rule, count in sorted(result['violations'].items()):
            print(f"  {rule}: {count}")

    return 0 if result['clean'] else 1


if __name__ == '__main__':
    sys.exit(main())
