#!/usr/bin/env python3
"""Render verification plan configuration from MAS."""
import json, sys
from pathlib import Path

def render(mas_path: str, seed_path: str) -> dict:
    """Generate verification plan configuration from MAS and seed."""
    with open(mas_path) as f:
        mas = json.load(f)

    seed_text = Path(seed_path).read_text(errors="replace") if Path(seed_path).exists() else ""

    # Extract FSM states from MAS
    fsm_states = []
    for mod in mas.get("modules", []):
        for state in mod.get("fsm_states", []):
            fsm_states.append({"module": mod.get("name", ""), "state": state})

    # Extract interfaces for coverpoints
    interfaces = mas.get("interfaces", [])

    # Number FTPs from seed
    ftp_count = 0
    ftps = []
    for i, line in enumerate(seed_text.splitlines(), 1):
        line = line.strip()
        if line and not line.startswith("#"):
            ftp_count += 1
            ftps.append({"id": f"FTP-{ftp_count:03d}", "description": line})

    return {
        "fsm_states": fsm_states,
        "interfaces": interfaces,
        "ftps": ftps,
        "ftp_count": ftp_count,
        "coverage_groups": len(fsm_states) + len(interfaces),
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <mas.json> <verif_plan_seed.md>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(render(sys.argv[1], sys.argv[2]), indent=2))
