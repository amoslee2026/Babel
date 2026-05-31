#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bb-check-cdc: conservative CDC (Clock Domain Crossing) checker.

Job (per SKILL.md): "基于 AST 检查 CDC/RDC 违例：对比 MAS clock_domains 找跨域
信号，检查是否被 2ff-sync CBB 保护".

============================ IMPORTANT LIMITATION ============================
The normalized AST emitted by `bb-parse-ast` (see
.claude/skills/bb-parse-ast/lib/ast_serializer.py and the normalize_* scripts)
contains ONLY:
    - modules:     [module_name, ...]
    - ports:       {module_name: [{name, direction, width}, ...]}
    - instances:   {module_name: [{name, module, parameters}, ...]}
    - parameters:  {module_name: [...]}
    - status:      "pass" | "partial" | "fail"
It does NOT contain always_ff blocks, RHS/LHS of assignments, sensitivity
lists, or any per-register clock-domain tagging. The MAS `clock_domains` is a
flat array [{name, freq_mhz, source}] with NO module->domain mapping either.

Therefore a true register-to-register source->sink cross-domain reachability
analysis is NOT possible from the available data. This module implements the
most defensible *conservative* check that the data supports, and labels every
result with `method` and `confidence` so consumers know the analysis fidelity:

  Method "multiclk-port-heuristic + instance-sync + mas-waiver":
   1. Identify clock-domain clock names from MAS.clock_domains.
   2. A module whose port list references >= 2 distinct clock-domain clocks is
      a clock-crossing site (a crossing physically lives there).
   3. A crossing is PROTECTED if the module instantiates a recognized 2ff-sync
      CBB (instance whose target module name matches a synchronizer pattern),
      OR the relevant clock pair is covered by an explicit MAS.cdc_waivers[]
      entry. Otherwise it is an UNWAIVED violation.

This is conservative: it may over-report (safe — forces human/RTL attention)
but it never fakes a clean/pass and never blanket-waives.

Verdict:
  - status="error"/valid=false  ONLY when the AST is genuinely
    unavailable/unparseable or contains zero modules (true fail-closed).
  - status="pass", clean=true    only when analysis actually ran and found 0
    unwaived violations.
  - status="fail", clean=false   when unwaived violations exist.
=============================================================================
"""

import json
import os
import re
import sys
from datetime import datetime
from typing import Dict, List, Optional, Tuple

# Module-name patterns that identify a 2-flop (or deeper) synchronizer CBB.
# Matches sync_2ff, ff2_sync, cdc_synchronizer, sync2, demet, two_ff_sync, etc.
SYNC_MODULE_RE = re.compile(
    r"(?:^|_)(?:sync\w*|synchroniz\w+|2ff|ff2|two_?ff|cdc_?sync|demet\w*|metastab\w*)",
    re.IGNORECASE,
)

# Tokens that, when present in a port name, suggest it carries a clock.
_CLOCK_HINT_RE = re.compile(r"(?:^|_)(?:clk|clock|tck)(?:$|_)", re.IGNORECASE)


def load_json(path):
    # type: (str) -> Optional[dict]
    """Load JSON, returning None if the file is missing or unparseable."""
    try:
        with open(path) as f:
            return json.load(f)
    except (IOError, OSError, ValueError):
        return None


def extract_clock_names(mas):
    # type: (dict) -> List[str]
    """Return the list of clock-domain clock names declared in the MAS.

    MAS.clock_domains is a flat array [{name, freq_mhz, source}, ...].
    """
    names = []  # type: List[str]
    domains = mas.get("clock_domains", []) if isinstance(mas, dict) else []
    if isinstance(domains, list):
        for d in domains:
            if isinstance(d, dict) and d.get("name"):
                names.append(str(d["name"]))
    elif isinstance(domains, dict):
        # tolerate a legacy {name: {...}} mapping shape
        names.extend(str(k) for k in domains.keys())
    return names


def module_clock_ports(port_list, clock_names):
    # type: (List[dict], List[str]) -> List[str]
    """Return the distinct clock-domain clocks referenced by a module's ports.

    A port matches a clock domain when its name equals the domain clock name,
    or the domain clock name appears as a token in the port name (so a module
    port `clk_sys` matches domain `clk_sys`). Generic clock-looking ports
    (clk/clock/tck) that don't map to a known domain are ignored, because we
    cannot attribute them to a specific domain.
    """
    found = []  # type: List[str]
    lower_clocks = [(c, c.lower()) for c in clock_names]
    for p in port_list or []:
        if not isinstance(p, dict):
            continue
        pname = str(p.get("name", "")).lower()
        if not pname:
            continue
        for orig, low in lower_clocks:
            if pname == low or re.search(r"(?:^|_)" + re.escape(low) + r"(?:$|_)", pname):
                if orig not in found:
                    found.append(orig)
    return found


def has_synchronizer_instance(inst_list):
    # type: (List[dict]) -> List[str]
    """Return the names of instantiated synchronizer CBBs in a module."""
    syncs = []  # type: List[str]
    for inst in inst_list or []:
        if not isinstance(inst, dict):
            continue
        mod = str(inst.get("module", ""))
        if mod and SYNC_MODULE_RE.search(mod):
            syncs.append(mod)
    return syncs


def waiver_covers(waivers, clk_a, clk_b):
    # type: (List[dict], str, str) -> Optional[dict]
    """Return the first MAS cdc_waiver covering the (clk_a, clk_b) pair, or None.

    Direction-agnostic: a waiver from_clk/to_clk matching either ordering of the
    pair counts (a module sees both clocks; the crossing may go either way).
    """
    for w in waivers or []:
        if not isinstance(w, dict):
            continue
        fc = str(w.get("from_clk", ""))
        tc = str(w.get("to_clk", ""))
        if {fc, tc} == {clk_a, clk_b}:
            return w
    return None


def analyze(ast, mas):
    # type: (dict, dict) -> Tuple[List[dict], List[dict], List[dict]]
    """Conservative CDC analysis over normalized AST + MAS.

    Returns (violations, crossings, synchronizers) where:
      - crossings:      every detected clock-crossing site (module-level)
      - synchronizers:  every detected synchronizer instance
      - violations:     crossings that are neither synchronized nor waived
    """
    clock_names = extract_clock_names(mas)
    waivers = mas.get("cdc_waivers", []) if isinstance(mas, dict) else []

    ports = ast.get("ports", {}) if isinstance(ast, dict) else {}
    instances = ast.get("instances", {}) if isinstance(ast, dict) else {}
    modules = ast.get("modules", []) if isinstance(ast, dict) else []

    crossings = []      # type: List[dict]
    synchronizers = []  # type: List[dict]
    violations = []     # type: List[dict]

    for mod in modules:
        mod_ports = ports.get(mod, [])
        mod_insts = instances.get(mod, [])

        clk_ports = module_clock_ports(mod_ports, clock_names)
        syncs = has_synchronizer_instance(mod_insts)
        for s in syncs:
            synchronizers.append({"module": mod, "sync_module": s})

        # A crossing site requires >= 2 distinct domain clocks in one module.
        if len(clk_ports) < 2:
            continue

        # Enumerate every unordered clock pair in this module as a crossing.
        for i in range(len(clk_ports)):
            for j in range(i + 1, len(clk_ports)):
                clk_a, clk_b = clk_ports[i], clk_ports[j]
                waiver = waiver_covers(waivers, clk_a, clk_b)
                protected = len(syncs) > 0
                crossing = {
                    "module": mod,
                    "from_clk": clk_a,
                    "to_clk": clk_b,
                    "synchronized": protected,
                    "sync_instances": syncs,
                    "waived": waiver is not None,
                    "waive_reason": (waiver.get("justification") if waiver else None),
                }
                crossings.append(crossing)
                if not protected and waiver is None:
                    violations.append({
                        "type": "CDC_UNSYNCHRONIZED_CROSSING",
                        "module": mod,
                        "from_clk": clk_a,
                        "to_clk": clk_b,
                        "signal": mod,  # signal-level unavailable; report at module granularity
                        "line": "unknown",
                        "waived": False,
                        "waive_reason": None,
                    })
    return violations, crossings, synchronizers


def generate_cdc_report(design_name, ast_path, mas_path):
    # type: (str, str, str) -> dict
    """Generate the CDC report dict from an AST JSON path + MAS JSON path."""
    method = "multiclk-port-heuristic + instance-sync + mas-waiver"
    confidence = "low"  # AST lacks signal-level domain/assignment info; see module docstring.

    ast = load_json(ast_path)
    mas = load_json(mas_path)

    # True fail-closed: AST genuinely unavailable/unparseable.
    if ast is None:
        return _error_report(
            design_name, ast_path, mas_path, method, confidence,
            "AST unavailable or unparseable at %s" % ast_path)
    if not isinstance(ast, dict) or not ast.get("modules"):
        return _error_report(
            design_name, ast_path, mas_path, method, confidence,
            "AST contains no modules; cannot perform CDC analysis")
    if ast.get("status") == "fail":
        return _error_report(
            design_name, ast_path, mas_path, method, confidence,
            "AST parser reported status=fail; analysis cannot run on usable data")
    if mas is None:
        # MAS defines the clock domains and waivers — without it we cannot
        # classify crossings; fail closed rather than guess.
        return _error_report(
            design_name, ast_path, mas_path, method, confidence,
            "MAS unavailable or unparseable at %s" % mas_path)

    violations, crossings, synchronizers = analyze(ast, mas)
    unwaived = [v for v in violations if not v.get("waived", False)]

    clean = len(unwaived) == 0
    status = "pass" if clean else "fail"

    return {
        "design_name": design_name,
        "generated": datetime.now().isoformat(),
        "method": method,
        "confidence": confidence,
        "ast_path": ast_path,
        "mas_path": mas_path,
        "modules_analyzed": len(ast.get("modules", [])),
        "clock_domains": extract_clock_names(mas),
        "cdc_paths": crossings,
        "synchronizers_found": synchronizers,
        "violations": violations,
        "unwaived_count": len(unwaived),
        "total_violations": len(violations),
        "clean": clean,
        "valid": True,
        "status": status,
        "error": None,
    }


def _error_report(design_name, ast_path, mas_path, method, confidence, msg):
    # type: (str, str, str, str, str, str) -> dict
    """Build a fail-closed error report (valid=false, clean=false)."""
    return {
        "design_name": design_name,
        "generated": datetime.now().isoformat(),
        "method": method,
        "confidence": confidence,
        "ast_path": ast_path,
        "mas_path": mas_path,
        "modules_analyzed": 0,
        "clock_domains": [],
        "cdc_paths": [],
        "synchronizers_found": [],
        "violations": [],
        "unwaived_count": 0,
        "total_violations": 0,
        "clean": False,
        "valid": False,
        "status": "error",
        "error": msg,
    }


def main():
    # type: () -> int
    import argparse

    parser = argparse.ArgumentParser(description="Conservative AST-based CDC checker")
    parser.add_argument("--design", required=True, help="Design name")
    parser.add_argument("--ast", default=None, help="bb-parse-ast normalized AST JSON path")
    parser.add_argument("--mas", default=None, help="MAS JSON path (designs/<name>/mas/mas.json)")
    parser.add_argument("--out-dir", default=None, help="Output directory")
    args = parser.parse_args()

    ast_path = args.ast or ""
    mas_path = args.mas or os.environ.get("MAS_PATH", "")

    report = generate_cdc_report(args.design, ast_path, mas_path)

    out_path = args.out_dir or ("designs/%s/cdc" % args.design)
    try:
        os.makedirs(out_path)
    except OSError:
        pass
    report_file = os.path.join(out_path, "cdc_report.json")
    with open(report_file, "w") as f:
        f.write(json.dumps(report, indent=2))
    report["artifact_path"] = report_file

    print(json.dumps(report, indent=2))
    # Exit non-zero on error so callers fail closed; clean/fail both exit 0
    # (the verdict is carried by status/clean in the JSON).
    return 1 if report.get("status") == "error" else 0


if __name__ == "__main__":
    sys.exit(main())
