#!/usr/bin/env python3
"""Extract structured test points from Babel verification sources.

Inputs (all optional except design name):
  --seed  designs/<name>/mas/verif_plan_seed.md
  --plan  designs/<name>/verif/verification_plan.md
  --mas   designs/<name>/mas/mas.json

Outputs:
  <out_dir>/test_points.json
  <out_dir>/test_points.md

No third-party dependencies; deterministic ordering and IDs.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, OrderedDict
from datetime import datetime, timezone, timedelta
from pathlib import Path

CST = timezone(timedelta(hours=8))
MODULE_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
PLAN_SECTION_RE = re.compile(r"^###\s+\d+\.\d+\s+([A-Za-z0-9_]+)\s*:")
SEED_SECTION_RE = re.compile(r"^###\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
CHECK_BY_CATEGORY = {
    "functional": "scoreboard compares DUT output against the golden model",
    "branch": "observe the branch side effect (output/flags) after forcing the selector",
    "boundary": "no truncation/overflow; error flags match spec",
    "cdc": "destination-domain sample stable after the sync latency",
    "reset": "outputs hold reset values; first post-reset cycle correct",
}


def module_code(name: str) -> str:
    m = re.match(r"^([A-Za-z]+\d+)", name)
    if m:
        return m.group(1)
    return name.split("_")[0] if "_" in name else "TOP"


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def split_row(line: str) -> list[str]:
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    return cells


def is_table_header(cells: list[str], first: str = "id") -> bool:
    return bool(cells) and cells[0].strip().lower() == first


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def parse_seed(path: Path) -> list[dict]:
    """Seed tables: ### Module / | ID | Test | Priority | Method |."""
    points: list[dict] = []
    module = None
    in_table = False
    for line in read_lines(path):
        sec = SEED_SECTION_RE.match(line)
        if sec and MODULE_NAME_RE.match(sec.group(1)):
            module = sec.group(1)
            in_table = False
            continue
        if line.startswith("### ") or line.startswith("## "):
            if not SEED_SECTION_RE.match(line):
                module = None
            in_table = False
            continue
        if not line.startswith("|") or module is None:
            continue
        cells = split_row(line)
        if is_table_header(cells) and "test" in [c.lower() for c in cells]:
            in_table = True
            continue
        if set("".join(cells)) <= {"-", ":", " "}:
            continue
        if not in_table or len(cells) < 4:
            continue
        source_id, title, priority, method = cells[:4]
        if not title:
            continue
        points.append(
            {
                "module": module,
                "module_code": module_code(module),
                "source_id": source_id,
                "title": title,
                "priority": priority.upper() or "MEDIUM",
                "method": method,
                "category": "functional",
                "stimulus": method or "directed stimulus",
                "source": "seed",
            }
        )
    return points


def parse_plan(path: Path) -> list[dict]:
    """Plan: ### N.M CODE: Name + Functional/Branch coverage tables."""
    points: list[dict] = []
    code = None
    block = None
    for line in read_lines(path):
        sec = PLAN_SECTION_RE.match(line)
        if sec:
            code = sec.group(1)
            block = None
            continue
        if line.startswith("### ") and not PLAN_SECTION_RE.match(line):
            code = None
            block = None
            continue
        low = line.lower()
        if "functional coverage points" in low:
            block = "functional"
            continue
        if "branch coverage points" in low:
            block = "branch"
            continue
        if not line.startswith("|") or code is None or block is None:
            continue
        cells = split_row(line)
        if is_table_header(cells) and "feature" not in low and "branch" not in low:
            continue
        if set("".join(cells)) <= {"-", ":", " "}:
            continue
        if block == "functional" and len(cells) >= 4:
            tp_id, feature, test_case, priority = cells[:4]
            if not re.match(r"^F-", tp_id):
                continue
            points.append(
                {
                    "module": code,
                    "module_code": code,
                    "source_id": tp_id,
                    "title": feature,
                    "priority": priority.upper() or "MEDIUM",
                    "method": test_case,
                    "category": "functional",
                    "stimulus": test_case or "directed stimulus",
                    "source": "plan",
                }
            )
        elif block == "branch" and len(cells) >= 3:
            tp_id, branch, condition = cells[:3]
            if not re.match(r"^B-", tp_id):
                continue
            points.append(
                {
                    "module": code,
                    "module_code": code,
                    "source_id": tp_id,
                    "title": branch,
                    "priority": "HIGH",
                    "method": condition,
                    "category": "branch",
                    "stimulus": condition or "force selector to target value",
                    "source": "plan",
                }
            )
    return points


def parse_mas(path: Path) -> tuple[list[dict], list[dict], list[str]]:
    """Return (module list, derived points, modules_without_points placeholder)."""
    mas = json.loads(path.read_text(encoding="utf-8"))
    modules = mas.get("modules") or []
    derived: list[dict] = []

    for mod in modules:
        name = mod.get("name")
        if not name:
            continue
        ports = ((mod.get("interface") or {}).get("ports")) or []
        rst = next(
            (p for p in ports if re.match(r"^rst", str(p.get("name", "")))),
            None,
        )
        wide = [
            p
            for p in ports
            if p.get("dir") == "input" and int(p.get("width", 1) or 1) >= 8
        ]
        if rst:
            derived.append(
                {
                    "module": name,
                    "module_code": module_code(name),
                    "title": "Reset behavior",
                    "priority": "HIGH",
                    "method": f"assert {rst['name']} for 2 cycles, then release",
                    "category": "reset",
                    "stimulus": f"assert {rst['name']} for 2 cycles while driving random inputs, then release",
                    "source": "mas-derived",
                }
            )
        if wide:
            widest = max(wide, key=lambda p: int(p.get("width", 1) or 1))
            derived.append(
                {
                    "module": name,
                    "module_code": module_code(name),
                    "title": "Input boundary values",
                    "priority": "MEDIUM",
                    "method": f"drive 0 / max on {widest['name']}",
                    "category": "boundary",
                    "stimulus": f"drive all-0, all-1 and max+1 on {widest['name']} ({widest.get('width')} bit)",
                    "source": "mas-derived",
                }
            )

    clocks = mas.get("clock_domains") or []
    if len(clocks) >= 2:
        for src in clocks:
            for dst in clocks:
                if src.get("name") == dst.get("name"):
                    continue
                derived.append(
                    {
                        "module": mas.get("top_module") or "TOP",
                        "module_code": module_code(mas.get("top_module") or "TOP"),
                        "title": f"CDC {src['name']} -> {dst['name']}",
                        "priority": "HIGH",
                        "method": "toggle source-domain stimulus and sample in destination domain",
                        "category": "cdc",
                        "stimulus": f"toggle inputs at {src['name']} ({src.get('freq_mhz')} MHz), sample at {dst['name']}",
                        "source": "mas-derived",
                    }
                )

    return modules, derived, []


def dedupe(points: list[dict]) -> list[dict]:
    seen: dict[tuple[str, str], dict] = OrderedDict()
    for p in points:
        key = (p["module_code"], slug(p["title"]))
        if key in seen:
            srcs = seen[key].setdefault("also_in", [])
            if p["source"] not in srcs and p["source"] != seen[key]["source"]:
                srcs.append(p["source"])
            continue
        seen[key] = p
    return list(seen.values())


def order_points(points: list[dict], module_order: list[str]) -> list[dict]:
    rank = {m: i for i, m in enumerate(module_order)}
    category_rank = {"functional": 0, "branch": 1, "boundary": 2, "reset": 3, "cdc": 4}
    return sorted(
        points,
        key=lambda p: (
            rank.get(p["module"], len(rank)),
            p["module"],
            category_rank.get(p["category"], 9),
            slug(p["title"]),
        ),
    )


def assign_ids(points: list[dict]) -> None:
    per_mod: Counter = Counter()
    for p in points:
        per_mod[p["module_code"]] += 1
        p["id"] = f"TP-{p['module_code']}-{per_mod[p['module_code']]:03d}"
        p.setdefault("source_id", "derived")
        p.setdefault("check", CHECK_BY_CATEGORY.get(p["category"], "observe DUT behavior"))


def validate(points: list[dict], modules: list[dict]) -> tuple[bool, list[str], list[str]]:
    errors: list[str] = []
    ids = [p["id"] for p in points]
    if not points:
        errors.append("no test points extracted")
    if len(ids) != len(set(ids)):
        errors.append("duplicate test point ids")
    for p in points:
        if not re.match(r"^TP-[A-Z0-9]+-\d{3}$", p["id"]):
            errors.append(f"bad id format: {p['id']}")
        for field in ("module", "title", "priority", "category", "check"):
            if not p.get(field):
                errors.append(f"{p['id']}: missing {field}")
        if p["priority"] not in {"HIGH", "MEDIUM", "LOW"}:
            errors.append(f"{p['id']}: bad priority {p['priority']}")
    covered = {p["module"] for p in points}
    missing = [m.get("name") for m in modules if m.get("name") and m["name"] not in covered]
    return (not errors), errors, [m for m in missing if m]


def render_markdown(doc: dict) -> str:
    lines = [
        f"# Test Points — {doc['design_name']}",
        "",
        f"> 生成时间：{doc['generated']} ｜ 共 {doc['counts']['total']} 点 ｜ "
        f"类别 {doc['counts']['by_category']} ｜ 优先级 {doc['counts']['by_priority']}",
        "",
        f"来源：seed={doc['sources'].get('seed')} ｜ plan={doc['sources'].get('plan')} ｜ mas={doc['sources'].get('mas')}",
        "",
        "| ID | Module | Category | Priority | Title | Stimulus | Check | Source |",
        "|----|--------|----------|----------|-------|----------|-------|--------|",
    ]
    for p in doc["points"]:
        cells = [
            p["id"],
            p["module"],
            p["category"],
            p["priority"],
            p["title"],
            p["stimulus"],
            p["check"],
            p["source"] + ("+" + ",".join(p["also_in"]) if p.get("also_in") else ""),
        ]
        lines.append("| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |")
    if doc.get("modules_without_points"):
        lines += ["", "## 无测试点模块", "", ", ".join(doc["modules_without_points"])]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--design-name", required=True)
    ap.add_argument("--seed")
    ap.add_argument("--plan")
    ap.add_argument("--mas")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    points: list[dict] = []
    sources: dict = {}
    modules: list[dict] = []
    sources_missing: list[str] = []

    if args.seed and Path(args.seed).is_file():
        points += parse_seed(Path(args.seed))
        sources["seed"] = args.seed
    else:
        sources_missing.append("seed")

    if args.plan and Path(args.plan).is_file():
        points += parse_plan(Path(args.plan))
        sources["plan"] = args.plan
    else:
        sources_missing.append("plan")

    if args.mas and Path(args.mas).is_file():
        modules, derived, _ = parse_mas(Path(args.mas))
        points += derived
        sources["mas"] = args.mas
    else:
        sources_missing.append("mas")

    code_to_name = {
        module_code(m["name"]): m["name"] for m in modules if m.get("name")
    }
    for p in points:
        p["module"] = code_to_name.get(p["module"], p["module"])
        p["module_code"] = module_code(p["module"])

    points = dedupe(points)
    module_order = [m["name"] for m in modules if m.get("name")]
    points = order_points(points, module_order)
    assign_ids(points)

    valid, errors, missing = validate(points, modules)

    doc = {
        "design_name": args.design_name,
        "generated": datetime.now(CST).isoformat(timespec="seconds"),
        "sources": sources,
        "sources_missing": sources_missing,
        "counts": {
            "total": len(points),
            "by_category": dict(Counter(p["category"] for p in points)),
            "by_priority": dict(Counter(p["priority"] for p in points)),
        },
        "modules_without_points": missing,
        "points": points,
        "valid": valid and not missing,
        "error": "; ".join(errors) if errors else (f"modules without points: {missing}" if missing else None),
    }

    json_path = out_dir / "test_points.json"
    md_path = out_dir / "test_points.md"
    json_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text(render_markdown(doc), encoding="utf-8")

    summary = {
        "artifact_path": str(json_path),
        "markdown_path": str(md_path),
        "total": doc["counts"]["total"],
        "by_category": doc["counts"]["by_category"],
        "by_priority": doc["counts"]["by_priority"],
        "modules_without_points": missing,
        "valid": doc["valid"],
        "error": doc["error"],
    }
    print(json.dumps(summary, ensure_ascii=False))
    if args.strict and not doc["valid"]:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
