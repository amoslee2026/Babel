#!/usr/bin/env python3
"""Run Magic to generate floorplan from rendered TCL."""
import subprocess, sys
from pathlib import Path

if __name__ == "__main__":
    tcl = Path(sys.argv[1])
    log = tcl.with_suffix(".log")
    cmd = ["magic", "-dnull", "-noconsole", "-rcfile", "libs/asap7/asap7.magicrc", str(tcl)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    log.write_text(r.stdout + r.stderr)
    print(f"Log: {log}")
    sys.exit(r.returncode)
