#!/usr/bin/env python3
"""Execute protocol search and return matches."""
import json, sys
from pathlib import Path

def search(query: dict, project_dir: str) -> dict:
    search_paths = query.get("search_paths", ["wiki/protocols/"])
    keywords = query.get("query", "").lower().split()
    matches = []
    base = Path(project_dir)
    for sp in search_paths:
        search_dir = base / sp
        if not search_dir.exists():
            continue
        for f in search_dir.rglob("*.md"):
            content = f.read_text(errors="replace").lower()
            score = sum(1 for kw in keywords if kw in content)
            if score > 0:
                matches.append({"name": f.stem, "path": str(f.relative_to(base)), "score": score})
    matches.sort(key=lambda x: x["score"], reverse=True)
    return {"matches": matches[:query.get("max_results", 10)], "total": len(matches)}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <query.json> <project_dir>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        query = json.load(f)
    print(json.dumps(search(query, sys.argv[2]), indent=2))
