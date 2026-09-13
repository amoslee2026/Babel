#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Parse CDC analysis log and emit a normalized JSON report.

Consistency contract with run_cdc.py: the log embeds the full report between
`CDC_REPORT_JSON_BEGIN` / `CDC_REPORT_JSON_END` markers. When present, that
embedded report is authoritative and is returned verbatim (so `clean`,
`status`, `valid`, `unwaived_count`, `violations`, `cdc_paths` round-trip
exactly). If the markers are absent (legacy/plain log), fall back to parsing
the textual SYNCHRONIZED / UNRESOLVED / ASYNC_CROSSING markers.

Fail-closed: if neither an embedded report nor any recognizable markers are
found, the result is status="error"/valid=false/clean=false — never a fake
clean pass.
"""

import json
import re
import sys
from typing import Optional

_JSON_BLOCK_RE = re.compile(
    r"CDC_REPORT_JSON_BEGIN\s*(?P<body>\{.*\})\s*CDC_REPORT_JSON_END",
    re.DOTALL,
)


def _parse_embedded(content):
    # type: (str) -> Optional[dict]
    """Return the embedded report dict if the markers are present and valid."""
    m = _JSON_BLOCK_RE.search(content)
    if not m:
        return None
    try:
        report = json.loads(m.group("body"))
    except ValueError:
        return None
    if not isinstance(report, dict):
        return None
    # Normalize the consumer-facing keys, defaulting to fail-closed values.
    violations = report.get("violations", [])
    report.setdefault("unwaived_count",
                       sum(1 for v in violations if not v.get("waived", False)))
    report.setdefault("clean", report.get("status") == "pass")
    report.setdefault("valid", report.get("status") != "error")
    return report


def _parse_markers(content):
    # type: (str) -> dict
    """Fallback: parse textual CDC markers from a plain log."""
    async_crossings, synchronized, unresolved = [], [], []
    for m in re.finditer(r'ASYNC_CROSSING:\s+(.+?)\s+from\s+(\w+)\s+to\s+(\w+)', content):
        async_crossings.append({'signal': m.group(1),
                                 'source_clock': m.group(2), 'dest_clock': m.group(3)})
    for m in re.finditer(r'SYNCHRONIZED:\s+(.+?)\s+\((\d+)-FF\)', content):
        synchronized.append({'signal': m.group(1), 'sync_stages': int(m.group(2))})
    for m in re.finditer(r'UNRESOLVED:\s+(.+?)\s+from\s+(\w+)\s+to\s+(\w+)', content):
        unresolved.append({'signal': m.group(1),
                            'source_clock': m.group(2), 'dest_clock': m.group(3)})

    saw_any = bool(async_crossings or synchronized or unresolved)
    if "ERROR:" in content or not saw_any:
        # No usable analysis evidence in the log -> fail closed.
        return {
            "status": "error",
            "valid": False,
            "clean": False,
            "error": "No CDC report block or recognizable markers in log",
            "violations": unresolved,
            "unwaived_count": len(unresolved),
            "cdc_paths": synchronized,
            "async_crossings": async_crossings,
            "synchronized": synchronized,
            "unresolved": unresolved,
            "async_count": len(async_crossings),
            "sync_count": len(synchronized),
            "unresolved_count": len(unresolved),
        }

    clean = len(unresolved) == 0
    return {
        "status": "pass" if clean else "fail",
        "valid": True,
        "clean": clean,
        "violations": unresolved,
        "unwaived_count": len(unresolved),
        "cdc_paths": synchronized,
        "async_crossings": async_crossings,
        "synchronized": synchronized,
        "unresolved": unresolved,
        "async_count": len(async_crossings),
        "sync_count": len(synchronized),
        "unresolved_count": len(unresolved),
    }


def parse_cdc_output(log_file):
    # type: (str) -> dict
    """Parse a CDC analysis log into a normalized report dict."""
    try:
        with open(log_file, 'r') as f:
            content = f.read()
    except (IOError, OSError) as e:
        return {"status": "error", "valid": False, "clean": False,
                "error": "Cannot read log %s: %s" % (log_file, e),
                "violations": [], "unwaived_count": 0, "cdc_paths": []}

    embedded = _parse_embedded(content)
    if embedded is not None:
        return embedded
    return _parse_markers(content)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_cdc.py <cdc_log_file>", file=sys.stderr)
        sys.exit(1)
    result = parse_cdc_output(sys.argv[1])
    print(json.dumps(result, indent=2))
    sys.exit(1 if result.get("status") == "error" else 0)
