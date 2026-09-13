#!/usr/bin/env python3
"""Run specification review workflow."""
import json, sys
from pathlib import Path
from datetime import datetime, timezone

def run(spec_dir: str, output_dir: str, role: str = "ruthless") -> dict:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    spec_files = list(Path(spec_dir).rglob("*.md"))
    if not spec_files:
        return {"status": "error", "message": f"No spec files found in {spec_dir}"}
    result = {
        "status": "ready_for_review",
        "spec_dir": spec_dir,
        "file_count": len(spec_files),
        "files": [str(f) for f in spec_files],
        "role": role,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    (output / "review_input.json").write_text(json.dumps(result, indent=2))
    return result

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <spec_dir> <output_dir> [role]", file=sys.stderr)
        sys.exit(1)
    role = sys.argv[3] if len(sys.argv) > 3 else "ruthless"
    print(json.dumps(run(sys.argv[1], sys.argv[2], role), indent=2))
