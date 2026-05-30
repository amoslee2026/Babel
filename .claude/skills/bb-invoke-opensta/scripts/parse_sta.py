#!/usr/bin/env python3
"""
parse_sta.py -- Parse OpenSTA timing report and extract metrics.

Phase 3 of bb-invoke-opensta: reads STA log, outputs JSON with timing data.
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_corners(log_content: str) -> list:
    """Split log by corner markers and extract per-corner metrics."""
    corners = []
    sections = re.split(r'=== CORNER (\S+) ===', log_content)

    # sections[0] is preamble, then alternating (corner_name, content)
    for i in range(1, len(sections), 2):
        corner_name = sections[i]
        content = sections[i + 1] if i + 1 < len(sections) else ""

        wns = _extract_value(content, r'worst slack\s+([-\d.]+)')
        tns = _extract_value(content, r'tns\s+([-\d.]+)')
        critical_path = _extract_critical_path(content)

        corners.append({
            'corner': corner_name,
            'wns_ns': wns,
            'tns_ns': tns,
            'critical_path': critical_path,
            'timing_met': wns >= 0.0,
        })

    return corners


def _extract_value(text: str, pattern: str) -> float:
    """Extract a float timing value from text."""
    match = re.search(pattern, text)
    return float(match.group(1)) if match else 0.0


def _extract_critical_path(text: str) -> str:
    """Extract critical path endpoint from report_checks output."""
    match = re.search(r'endpoint:\s+(\S+)', text)
    return match.group(1) if match else ""


def parse_sta_report(log_path: str) -> dict:
    """Parse OpenSTA log file and return structured results."""
    path = Path(log_path)
    if not path.exists():
        return {'valid': False, 'error': 'LOG_NOT_FOUND'}

    content = path.read_text()

    # Check exit code appended by run_sta.py
    exit_match = re.search(r'exit:(\d+)', content)
    exit_code = int(exit_match.group(1)) if exit_match else 1
    if exit_code != 0:
        return {'valid': False, 'error': f'STA_EXIT_{exit_code}'}

    corners = parse_corners(content)
    if not corners:
        # Fallback: single-corner report without markers
        wns = _extract_value(content, r'worst slack\s+([-\d.]+)')
        tns = _extract_value(content, r'tns\s+([-\d.]+)')
        corners = [{
            'corner': 'default',
            'wns_ns': wns,
            'tns_ns': tns,
            'critical_path': _extract_critical_path(content),
            'timing_met': wns >= 0.0,
        }]

    worst_wns = min(c['wns_ns'] for c in corners)
    total_tns = sum(c['tns_ns'] for c in corners)
    timing_met = all(c['timing_met'] for c in corners)

    return {
        'valid': True,
        'wns_ns': worst_wns,
        'tns_ns': total_tns,
        'timing_met': timing_met,
        'corners': corners,
        'critical_path': next(
            (c['critical_path'] for c in corners if c['wns_ns'] == worst_wns), ""
        ),
        'error': None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse OpenSTA timing report")
    parser.add_argument('--log', required=True, help='STA log file path')
    parser.add_argument('--out', required=True, help='Output JSON path')
    args = parser.parse_args()

    result = parse_sta_report(args.log)
    Path(args.out).write_text(json.dumps(result, indent=2))

    if result.get('valid'):
        print(f"STA parsed: WNS={result['wns_ns']:.3f}ns, "
              f"TNS={result['tns_ns']:.3f}ns, met={result['timing_met']}")
        return 0
    else:
        print(f"Parse error: {result.get('error')}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
