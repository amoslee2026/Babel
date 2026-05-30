#!/usr/bin/env python3
"""Render lint check shell script for Verilator."""
import sys
import json

def render_lint_script(top_module: str, files: list, includes: list = None) -> str:
    """Generate Verilator lint script."""
    includes = includes or []
    inc_flags = ''.join(f'  -I{inc} \\\n' for inc in includes)
    file_list = ''.join(f'  {f} \\\n' for f in files)

    return f"""#!/bin/bash
# Verilator lint check for {top_module}
set -euo pipefail
TOP_MODULE="{top_module}"
LOG_FILE="lint_${{TOP_MODULE}}.log"
source ~/wrk/eda_opensources/eda_env.sh
verilator --lint-only \\
  --sv -Wall -Wno-fatal \\
  --top-module ${{TOP_MODULE}} \\
{inc_flags}{file_list}  2>&1 | tee ${{LOG_FILE}}
python3 .claude/skills/bb-check-lint/scripts/parse_lint.py ${{LOG_FILE}} > lint_report.json
echo "Lint check complete. Report: lint_report.json"
"""

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: render_lint_sh.py <config.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r') as f:
        config = json.load(f)
    print(render_lint_script(config['top_module'], config['files'], config.get('includes', [])))
