#!/usr/bin/env python3
"""Execute CDC analysis workflow."""
import json, subprocess, sys
from pathlib import Path
from datetime import datetime, timezone

def run(script_path: str, output_dir: str) -> dict:
    """Run CDC analysis script and collect results."""
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    log = output / "cdc_run.log"

    try:
        result = subprocess.run(
            ["uv", "run", "python", script_path],
            capture_output=True, text=True, timeout=600,
            cwd=str(output),
        )
        log.write_text(result.stdout + "\n" + result.stderr)
        success = result.returncode == 0
    except subprocess.TimeoutExpired:
        return {"status": "timeout", "error": "CDC_TIMEOUT", "valid": False}
    except FileNotFoundError:
        return {"status": "error", "error": "uv not found", "valid": False}
    except Exception as e:
        return {"status": "error", "error": str(e), "valid": False}

    # Try to parse output JSON
    report_file = output / "cdc_report.json"
    violations = []
    if report_file.exists():
        try:
            report = json.loads(report_file.read_text())
            violations = report.get("violations", [])
        except json.JSONDecodeError:
            pass

    unwaived = [v for v in violations if not v.get("waived", False)]

    return {
        "status": "complete" if success else "failed",
        "log": str(log),
        "violations": violations,
        "clean": len(unwaived) == 0,
        "valid": success,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <script.py> <output_dir>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run(sys.argv[1], sys.argv[2]), indent=2))
