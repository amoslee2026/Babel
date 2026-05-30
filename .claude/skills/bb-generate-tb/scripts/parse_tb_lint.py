#!/usr/bin/env python3
"""Lint generated testbench for common issues."""
import json, re, sys
from pathlib import Path

def lint(tb_path: str) -> dict:
    text = Path(tb_path).read_text(errors="replace")
    issues = []
    if "initial begin" not in text and "initial begin" not in text.replace(" ", ""):
        issues.append({"severity": "HIGH", "message": "No initial block found"})
    if "$finish" not in text and "$stop" not in text:
        issues.append({"severity": "HIGH", "message": "No simulation termination ($finish/$stop)"})
    if "timescale" not in text:
        issues.append({"severity": "MEDIUM", "message": "No `timescale directive"})
    if re.search(r'#\d+', text) and "timescale" not in text:
        issues.append({"severity": "MEDIUM", "message": "Delay used without timescale"})
    return {"issues": issues, "issue_count": len(issues), "clean": len(issues) == 0}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <testbench.sv>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(lint(sys.argv[1]), indent=2))
