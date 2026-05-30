#!/usr/bin/env python3
"""Parse Verible/linter output into structured findings."""
import json, re, sys
from pathlib import Path

def parse(log_path: str, lint_mode: str = "src_only") -> dict:
    """Parse verible-verilog-lint output into structured errors and warnings."""
    text = Path(log_path).read_text(errors="replace")
    errors = []
    warnings = []

    # Verible output format: file:line:col: message [rule]
    pattern = re.compile(
        r"^(\S+?):(\d+):(\d+):\s+(.+?)(?:\s+\[(\S+?)\])?\s*$"
    )

    for line in text.splitlines():
        m = pattern.match(line)
        if not m:
            continue

        file_path = m.group(1)
        line_num = int(m.group(2))
        col = int(m.group(3))
        msg = m.group(4)
        rule = m.group(5) or "unknown"

        entry = {
            "file": file_path,
            "line": line_num,
            "col": col,
            "rule": rule,
            "msg": msg,
        }

        # Classify: Style rules are warnings, others are errors
        is_tb = "/tb/" in file_path or file_path.startswith("tb_")
        if "Style" in rule or "style" in rule.lower():
            warnings.append(entry)
        elif is_tb and lint_mode != "src_only":
            # TB verification constructs are allowed
            warnings.append(entry)
        else:
            errors.append(entry)

    src_errors = [e for e in errors if "/src/" in e["file"] or not ("/tb/" in e["file"])]
    src_clean = len(src_errors) == 0

    return {
        "errors": errors,
        "warnings": warnings,
        "error_count": len(errors),
        "warning_count": len(warnings),
        "src_clean": src_clean,
        "clean": len(errors) == 0 and len(warnings) == 0,
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <lint.log> [lint_mode]", file=sys.stderr)
        sys.exit(1)
    mode = sys.argv[2] if len(sys.argv) > 2 else "src_only"
    print(json.dumps(parse(sys.argv[1], mode), indent=2))
