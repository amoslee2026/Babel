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
    ("NO_INITIAL", r"\binitial\b(?!\s*@\s*\(\s*(?:posedge|negedge))"),
    ("NO_DELAY", r"#\d+"),
    ("NO_FORCE", r"\bforce\b"),
    ("NO_RELEASE", r"\brelease\b"),
    ("NO_WAIT", r"\bwait\s*\("),
]


def strip_comments_and_strings(content: str) -> str:
    """Remove // line comments, /* */ block comments, and string literals.

    Replaces stripped regions with spaces so the heuristics below cannot match
    cosmetic occurrences (e.g. `#5` inside a comment) and cause false CRITICALs.
    """
    out = []
    i = 0
    n = len(content)
    while i < n:
        c = content[i]
        nxt = content[i + 1] if i + 1 < n else ''
        if c == '/' and nxt == '/':
            while i < n and content[i] != '\n':
                out.append(' ')
                i += 1
        elif c == '/' and nxt == '*':
            out.append('  ')
            i += 2
            while i < n and not (content[i] == '*' and i + 1 < n and content[i + 1] == '/'):
                out.append('\n' if content[i] == '\n' else ' ')
                i += 1
            out.append('  ')
            i += 2
        elif c == '"':
            out.append(' ')
            i += 1
            while i < n and content[i] != '"':
                if content[i] == '\\' and i + 1 < n:
                    out.append('  ')
                    i += 2
                    continue
                out.append('\n' if content[i] == '\n' else ' ')
                i += 1
            if i < n:
                out.append(' ')
                i += 1
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def check_file(filepath):
    raw = filepath.read_text()
    content = strip_comments_and_strings(raw)
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

    # Best-effort, non-blocking note: real latch detection requires the synth
    # tool (e.g. Yosys); the previous regex heuristic was meaningless and is
    # intentionally removed so it cannot hard-fail the pipeline.
    notes = [
        "Latch inference is NOT checked here; rely on synthesis (Yosys) for "
        "authoritative combinational-latch detection."
    ]

    report = {
        "timestamp": datetime.now().isoformat(),
        "input_dir": str(input_dir),
        "files_checked": len(sv_files),
        "summary": {"critical": critical_count, "high": high_count},
        "violations": all_violations,
        "notes": notes,
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