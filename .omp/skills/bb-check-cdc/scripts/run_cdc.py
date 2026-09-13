#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Run conservative CDC analysis and return JSON status.

This is the Phase-2 driver for bb-check-cdc. It runs the real analysis from
check_cdc.py over the normalized bb-parse-ast AST + MAS, writes a log that
parse_cdc.py can consume, and prints the resulting report as JSON.

Fidelity / limitation: see the module docstring of check_cdc.py. The AST does
not carry signal-level clock-domain info, so detection is conservative
(multi-clock-module + synchronizer-instance + MAS waiver). It NEVER fakes a
pass: status="error"/valid=false is returned only when the AST is genuinely
unavailable/unparseable.

CLI (backward compatible):
    run_cdc.py <top_module> <rtl_dir> [--ast AST_JSON] [--mas MAS_JSON]
The positional <rtl_dir> is retained for contract compatibility; the real
analysis uses --ast/--mas (or MAS_PATH env). If no AST path is supplied or the
AST is unavailable, the run fails closed with status="error".
"""

import json
import os
import sys
from typing import List, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_cdc import generate_cdc_report  # noqa: E402


def _write_log(log_file, report):
    # type: (str, dict) -> None
    """Write a log consistent with parse_cdc.py markers + embedded JSON."""
    lines = []  # type: List[str]
    lines.append("CDC analysis for %s" % report.get("design_name", "unknown"))
    lines.append("method: %s (confidence: %s)" % (
        report.get("method", ""), report.get("confidence", "")))
    lines.append("modules_analyzed: %d" % report.get("modules_analyzed", 0))

    for c in report.get("cdc_paths", []):
        sig = c.get("signal", c.get("module", "?"))
        if c.get("synchronized") or c.get("waived"):
            lines.append("SYNCHRONIZED: %s (2-FF)" % sig)
        # raw crossing record is also emitted below via violations
    for v in report.get("violations", []):
        lines.append("UNRESOLVED: %s from %s to %s" % (
            v.get("signal", "?"), v.get("from_clk", "?"), v.get("to_clk", "?")))

    if report.get("status") == "error":
        lines.append("ERROR: %s" % report.get("error"))

    # Embed the full report so parse_cdc.py can recover exact verdict fields.
    lines.append("CDC_REPORT_JSON_BEGIN")
    lines.append(json.dumps(report))
    lines.append("CDC_REPORT_JSON_END")

    with open(log_file, "w") as f:
        f.write("\n".join(lines) + "\n")


def run_cdc_analysis(top_module, rtl_dir, ast_path=None, mas_path=None):
    # type: (str, str, Optional[str], Optional[str]) -> dict
    """Run conservative CDC analysis; returns the report dict (fail-closed)."""
    ast_path = ast_path or ""
    mas_path = mas_path or os.environ.get("MAS_PATH", "")

    report = generate_cdc_report(top_module, ast_path, mas_path)

    log_file = "cdc_%s.log" % top_module
    _write_log(log_file, report)
    report["log_file"] = log_file
    return report


def main(argv):
    # type: (List[str]) -> int
    import argparse
    parser = argparse.ArgumentParser(description="CDC analysis Phase-2 driver")
    parser.add_argument("top_module")
    parser.add_argument("rtl_dir")
    parser.add_argument("--ast", default=None)
    parser.add_argument("--mas", default=None)
    args = parser.parse_args(argv)

    report = run_cdc_analysis(args.top_module, args.rtl_dir, args.ast, args.mas)
    print(json.dumps(report, indent=2))
    return 1 if report.get("status") == "error" else 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: run_cdc.py <top_module> <rtl_dir> [--ast AST] [--mas MAS]",
              file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1:]))
