#!/usr/bin/env python3
"""Run module dependency analysis and generate topologically-ordered file list.

Ordering: leaf modules first, top module last (Yosys/Verilator-friendly).
Uses sv_module_regex helpers to extract module definitions + instantiations,
builds a dependency graph, and topo-sorts via Kahn's algorithm with cycle
detection. On a cycle, returns status:"error" naming the cycle.
"""
import json
import sys
from pathlib import Path

# Import the shared SV regex helpers from the sibling lib/ directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))
from sv_module_regex import extract_modules, extract_instantiations


def _resolve_files(filelist_path: str, project_dir: str) -> list:
    base = Path(project_dir)
    files = []
    for line in Path(filelist_path).read_text().splitlines():
        line = line.strip()
        if not line.endswith((".v", ".sv")):
            continue
        fpath = Path(line) if Path(line).is_absolute() else base / line
        if fpath.exists():
            files.append(str(fpath))
    return files


def analyze(filelist_path: str, project_dir: str) -> dict:
    """Analyze module dependencies and return topologically ordered file list."""
    files = _resolve_files(filelist_path, project_dir)

    # Map each defined module name -> file that defines it.
    module_to_file = {}
    # Map each file -> set of module names it instantiates.
    file_instances = {}
    for fpath in files:
        source = Path(fpath).read_text(errors="replace")
        defined = [m["name"] for m in extract_modules(source) if m.get("name")]
        for name in defined:
            # First definition wins; ignore duplicates deterministically.
            module_to_file.setdefault(name, fpath)
        file_instances[fpath] = {
            i["module"] for i in extract_instantiations(source) if i.get("module")
        }

    # Build dependency graph between files (only edges to in-project modules).
    # deps[f] = set of files that f depends on (its instantiated submodules).
    deps = {f: set() for f in files}
    for fpath in files:
        for inst_mod in file_instances.get(fpath, set()):
            dep_file = module_to_file.get(inst_mod)
            if dep_file and dep_file != fpath:
                deps[fpath].add(dep_file)

    # Kahn's algorithm: emit a file only after all its dependencies are emitted,
    # so leaf modules appear first and the top module appears last.
    # in_degree counts unresolved dependencies of each file.
    in_degree = {f: len(deps[f]) for f in files}
    # dependents[d] = files that depend on d.
    dependents = {f: set() for f in files}
    for f in files:
        for d in deps[f]:
            dependents[d].add(f)

    # Use sorted order for deterministic output among equal-rank files.
    ready = sorted([f for f in files if in_degree[f] == 0])
    ordered = []
    while ready:
        node = ready.pop(0)
        ordered.append(node)
        new_ready = []
        for dep in sorted(dependents[node]):
            in_degree[dep] -= 1
            if in_degree[dep] == 0:
                new_ready.append(dep)
        # Merge keeping deterministic sorted order.
        ready = sorted(ready + new_ready)

    if len(ordered) != len(files):
        cycle_nodes = sorted(f for f in files if in_degree[f] > 0)
        return {
            "ordered_files": [],
            "total": len(files),
            "status": "error",
            "error": "dependency cycle detected",
            "cycle": cycle_nodes,
        }

    return {"ordered_files": ordered, "total": len(ordered), "status": "complete"}


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <file_list.f> <project_dir>", file=sys.stderr)
        sys.exit(1)
    result = analyze(sys.argv[1], sys.argv[2])
    print(json.dumps(result, indent=2))
