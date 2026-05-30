#!/usr/bin/env python3
"""Run coverage collection and parse results."""
import json, subprocess, sys
from pathlib import Path
from datetime import datetime, timezone

def run(script_path: str, output_dir: str) -> dict:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    log = output / "coverage_run.log"

    try:
        result = subprocess.run(
            ["bash", script_path],
            capture_output=True, text=True, timeout=600,
            cwd=str(output)
        )
        log.write_text(result.stdout + "\n" + result.stderr)
        success = result.returncode == 0
    except subprocess.TimeoutExpired:
        return {"status": "timeout", "error": "Coverage collection timed out"}
    except Exception as e:
        return {"status": "error", "error": str(e)}

    return {
        "status": "complete" if success else "failed",
        "log": str(log),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <script.sh> <output_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run(sys.argv[1], sys.argv[2]), indent=2))
