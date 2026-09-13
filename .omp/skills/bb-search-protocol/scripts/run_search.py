#!/usr/bin/env python3
"""Execute protocol search and return matches."""
import json, sys
from pathlib import Path

def search(query: dict, project_dir: str) -> dict:
    search_paths = query.get("search_paths", ["wiki/protocols/"])
    keywords = query.get("query", "").lower().split()
    matches = []
    base = Path(project_dir)
    searched_dirs = 0
    errors = []
    for sp in search_paths:
        search_dir = base / sp
        if not search_dir.exists():
            errors.append(f"missing search path: {sp}")
            continue
        try:
            for f in search_dir.rglob("*.md"):
                try:
                    content = f.read_text(errors="replace").lower()
                except OSError as e:
                    errors.append(f"unreadable file {f}: {e}")
                    continue
                score = sum(1 for kw in keywords if kw in content)
                if score > 0:
                    matches.append({"name": f.stem, "path": str(f.relative_to(base)), "score": score})
            searched_dirs += 1
        except OSError as e:
            errors.append(f"unreadable dir {sp}: {e}")
    matches.sort(key=lambda x: x["score"], reverse=True)

    # Distinguish: search_error (no dir searchable) vs not_found vs found.
    if searched_dirs == 0:
        status = "search_error"
    elif matches:
        status = "found"
    else:
        status = "not_found"

    return {
        "status": status,
        "matches": matches[:query.get("max_results", 10)],
        "total": len(matches),
        "errors": errors,
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <query.json> <project_dir>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        query = json.load(f)
    print(json.dumps(search(query, sys.argv[2]), indent=2))
