#!/usr/bin/env python3
"""Render shell script that tries slang, verible, then regex fallback."""
import sys

def render_fallback_script(top_module: str, files: list) -> str:
    """Generate fallback parser script."""
    file_list = ' '.join(files)
    return f"""#!/bin/bash
# Fallback parser for {top_module}: slang -> verible -> regex
set -euo pipefail
TOP_MODULE="{top_module}"
FILES="{file_list}"
OUTPUT="${{TOP_MODULE}}_ast.json"

echo "Attempting to parse ${{TOP_MODULE}}..."

# Try slang
if command -v slang &> /dev/null; then
    echo "Using slang..."
    slang --ast-json ${{FILES}} > slang_out.json 2>/dev/null || true
    if [ -s slang_out.json ]; then
        python3 .claude/skills/bb-parse-ast-fallback/scripts/normalize_slang.py slang_out.json > ${{OUTPUT}}
        echo "slang OK"; exit 0
    fi
fi

# Try verible
if command -v verible-verilog-syntax &> /dev/null; then
    echo "Using verible..."
    verible-verilog-syntax --printtree --export_json ${{FILES}} > verible_out.json 2>/dev/null || true
    if [ -s verible_out.json ]; then
        python3 .claude/skills/bb-parse-ast-fallback/scripts/normalize_verible.py verible_out.json > ${{OUTPUT}}
        echo "verible OK"; exit 0
    fi
fi

# Regex fallback
echo "Using regex fallback..."
cat ${{FILES}} | python3 .claude/skills/bb-parse-ast-fallback/scripts/parse_fallback_output.py regex - > ${{OUTPUT}}
echo "Regex fallback complete (partial)"
"""

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: render_fallback_sh.py <top_module> [files...]", file=sys.stderr)
        sys.exit(1)
    print(render_fallback_script(sys.argv[1], sys.argv[2:] or ['*.sv', '*.v']))
