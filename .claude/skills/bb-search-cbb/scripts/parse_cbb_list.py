#!/usr/bin/env python3
"""Parse CBB search results into structured list."""
import json, sys
from pathlib import Path

def parse(results_path: str) -> dict:
    with open(results_path) as f:
        data = json.load(f)
    matches = []
    for item in data.get("matches", []):
        matches.append({
            "name": item.get("name", ""),
            "path": item.get("path", ""),
            "relevance": item.get("score", 0),
            "category": item.get("category", "unknown"),
        })
    matches.sort(key=lambda x: x["relevance"], reverse=True)
    status = data.get("status")
    if not status:
        status = "found" if matches else "not_found"
    return {"status": status, "matches": matches, "total": len(matches),
            "errors": data.get("errors", [])}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <results.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse(sys.argv[1]), indent=2))
