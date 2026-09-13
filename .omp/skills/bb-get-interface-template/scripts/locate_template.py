#!/usr/bin/env python3
"""Locate interface template matching a protocol specification."""
import json, sys
from pathlib import Path

def locate(protocol: str, project_dir: str) -> dict:
    wiki_dir = Path(project_dir) / "wiki" / "protocols"
    if not wiki_dir.exists():
        return {"found": False, "error": f"Protocol wiki not found: {wiki_dir}"}
    # Search for matching protocol doc
    for f in wiki_dir.rglob("*.md"):
        if protocol.lower() in f.stem.lower():
            return {"found": True, "path": str(f), "protocol": f.stem}
    return {"found": False, "error": f"No template found for protocol: {protocol}"}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <protocol> <project_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(locate(sys.argv[1], sys.argv[2]), indent=2))
