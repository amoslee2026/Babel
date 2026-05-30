#!/usr/bin/env python3
"""Initialize adaptive state for Babel architecture skills.

Called by bb-prd, bb-arch, bb-mas HARD-GATE to verify project readiness
and initialize iteration tracking.
"""
import argparse
import json
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize adaptive state for Babel skills")
    parser.add_argument("--skill", required=True, help="Skill name (e.g., bb-prd)")
    parser.add_argument("--project-dir", required=True, help="Project root directory")
    args = parser.parse_args()

    project_dir = Path(args.project_dir).resolve()
    skill = args.skill

    # Validate project directory
    if not project_dir.is_dir():
        print(json.dumps({"status": "error", "message": f"Project dir not found: {project_dir}"}))
        return 1

    # Check expected structure
    expected_dirs = ["rtl", "designs", "spec"]
    missing = [d for d in expected_dirs if not (project_dir / d).is_dir()]
    if missing:
        print(json.dumps({
            "status": "warning",
            "message": f"Missing dirs: {missing}",
            "skill": skill,
            "project_dir": str(project_dir)
        }))
        # Warning only, not blocking

    # Initialize adaptive state directory
    state_dir = project_dir / ".claude" / ".adaptive" / skill
    state_dir.mkdir(parents=True, exist_ok=True)

    state_file = state_dir / "state.json"
    if not state_file.exists():
        state = {
            "skill": skill,
            "project_dir": str(project_dir),
            "iteration": 0,
            "last_snapshot_hash": "",
            "status": "initialized"
        }
        state_file.write_text(json.dumps(state, indent=2))

    # Output ready status
    print(json.dumps({
        "status": "ready",
        "skill": skill,
        "project_dir": str(project_dir),
        "state_file": str(state_file)
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
