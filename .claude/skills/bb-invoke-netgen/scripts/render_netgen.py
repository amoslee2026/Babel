#!/usr/bin/env python3
"""
render_netgen.py -- Generate Netgen LVS comparison command/script.

Phase 1 of bb-invoke-netgen: renders the batch LVS command
from schematic and layout netlist paths.
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def render(params: dict) -> str:
    """Render Netgen LVS batch command."""
    schematic = params["schematic_netlist"]
    layout = params["layout_netlist"]
    tech_file = params["tech_file"]
    top_module = params["top_module"]
    design_name = params.get("design_name", "unknown")

    report_path = f"designs/{design_name}/pd/lvs_report.txt"
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")

    # Generate the batch command script
    script = f"""#!/bin/bash
# Netgen LVS Comparison Script
# Generated: {timestamp}
# Design: {design_name}
# Top Module: {top_module}

set -euo pipefail
source ~/wrk/eda_opensources/eda_env.sh

# Version check
netgen -batch lvs --version 2>&1 | grep "1.5" \\
  || {{ echo "VERSION_MISMATCH"; exit 1; }}

# Run LVS comparison
netgen -batch lvs \\
  "{layout} {top_module}" \\
  "{schematic} {top_module}" \\
  {tech_file} \\
  {report_path}

echo "LVS_COMPLETE"
"""
    return script


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <params.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        params = json.load(f)

    script_content = render(params)

    if len(sys.argv) >= 3:
        out_path = Path(sys.argv[2])
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(script_content)
        out_path.chmod(0o755)
        print(f"Script rendered: {out_path}", file=sys.stderr)
    else:
        print(script_content)
