#!/usr/bin/env python3
"""Build adversarial specification review prompt."""
import json, sys
from pathlib import Path

def build(spec_dir: str, role: str = "ruthless") -> dict:
    spec_files = list(Path(spec_dir).rglob("*.md"))
    contents = {}
    for f in spec_files:
        contents[str(f)] = f.read_text(errors="replace")[:3000]

    return {
        "role": role,
        "instruction": "Perform adversarial review: find contradictions, ambiguities, missing requirements, and inconsistencies between documents.",
        "specs": contents,
        "file_count": len(spec_files),
        "review_focus": ["completeness", "consistency", "ambiguity", "testability", "traceability"],
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <spec_dir> [role]", file=sys.stderr)
        sys.exit(1)
    role = sys.argv[2] if len(sys.argv) > 2 else "ruthless"
    print(json.dumps(build(sys.argv[1], role), indent=2))
