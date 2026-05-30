#!/usr/bin/env python3
"""Execute linting and collect results."""
import json, subprocess, sys
from pathlib import Path
from datetime import datetime, timezone

def run(script_path: str, output_dir: str) -> dict:
    """Run lint script and collect results."""
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    log = output / "lint_run.log"

    try:
        result = subprocess.run(
            ["bash", script_path],
            capture_output=True, text=True, timeout=300,
            cwd=str(output),
        )
        log.write_text(result.stdout + "\n" + result.stderr)
        success = result.returncode == 0
    except subprocess.TimeoutExpired:
        return {"status": "timeout", "error": "Lint timed out after 300s", "valid": False}
    except Exception as e:
        return {"status": "error", "error": str(e), "valid": False}

    return {
        "status": "complete" if success else "failed",
        "log": str(log),
        "exit_code": result.returncode,
        "valid": True,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <script.sh> <output_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run(sys.argv[1], sys.argv[2]), indent=2))
