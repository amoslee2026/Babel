#!/usr/bin/env python3
"""
synthesis_check.py - SystemVerilog 可综合性检查

检查 RTL 文件是否符合可综合性规则
"""

import re
import sys
import json
from pathlib import Path
from datetime import datetime

CRITICAL_RULES = [
    ("NO_INITIAL", r"initial\s+(?!@(posedge|negedge))"),
    ("NO_DELAY", r"#\d+"),
    ("NO_FORCE", r"force\s+"),
    ("NO_RELEASE", r"release\s+"),
    ("NO_WAIT", r"wait\s*\("),
]

HIGH_RULES = [
    ("NO_LATCH", r"always_comb.*if.*[^;]*;[^e]*end"),
]


def check_file(filepath):
    content = filepath.read_text()
    violations = []

    for rule_name, pattern in CRITICAL_RULES:
        matches = re.findall(pattern, content, re.MULTILINE)
        if matches:
            violations.append({
                "rule": rule_name,
                "severity": "CRITICAL",
                "count": len(matches),
                "file": str(filepath)
            })

    for rule_name, pattern in HIGH_RULES:
        matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
        if matches:
            violations.append({
                "rule": rule_name,
                "severity": "HIGH",
                "count": len(matches),
                "file": str(filepath)
            })

    return violations


def main():
    if len(sys.argv) < 3:
        print("Usage: synthesis_check.py <input_dir> <report_file>")
        sys.exit(1)

    input_dir = Path(sys.argv[1])
    report_file = Path(sys.argv[2])

    all_violations = []
    sv_files = list(input_dir.glob("**/*.sv"))

    for sv_file in sv_files:
        violations = check_file(sv_file)
        all_violations.extend(violations)

    critical_count = sum(1 for v in all_violations if v["severity"] == "CRITICAL")
    high_count = sum(1 for v in all_violations if v["severity"] == "HIGH")

    report = {
        "timestamp": datetime.now().isoformat(),
        "input_dir": str(input_dir),
        "files_checked": len(sv_files),
        "summary": {"critical": critical_count, "high": high_count},
        "violations": all_violations,
        "status": "FAIL" if critical_count > 0 else "PASS"
    }

    report_file.parent.mkdir(parents=True, exist_ok=True)
    report_file.write_text(json.dumps(report, indent=2))

    print(f"\n=== Synthesis Check ===")
    print(f"Files: {len(sv_files)}, CRITICAL: {critical_count}, HIGH: {high_count}")
    print(f"Status: {report['status']}")
    print(f"Report: {report_file}")

    if report["status"] == "FAIL":
        sys.exit(1)


if __name__ == "__main__":
    main()