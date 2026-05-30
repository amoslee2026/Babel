#!/usr/bin/env python3
"""Run ABC logic optimization with given script."""
import subprocess, sys
from pathlib import Path

if __name__ == "__main__":
    script = Path(sys.argv[1])
    log = script.with_suffix(".log")
    cmd = ["abc", "-f", str(script)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    log.write_text(r.stdout + r.stderr)
    print(f"Log: {log}")
    sys.exit(r.returncode)
