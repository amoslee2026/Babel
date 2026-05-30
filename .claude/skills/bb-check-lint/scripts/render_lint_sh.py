#!/usr/bin/env python3
"""Generate linting shell script from file list."""
import json, sys
from pathlib import Path

def render(file_list_path: str = None, target_dir: str = None,
           rules_config: str = None, lint_mode: str = "src_only") -> str:
    """Render a shell script for verible lint execution."""
    lines = [
        "#!/bin/bash",
        "# Auto-generated lint script by bb-check-lint",
        "set -eo pipefail",
        "source ~/wrk/eda_opensources/eda_env.sh",
        "",
    ]

    rules_flag = ""
    if rules_config:
        rules_flag = f"--rules_config {rules_config}"

    if file_list_path:
        lines.append(f"# Lint from file list: {file_list_path}")
        lines.append(f'files=$(cat "{file_list_path}" | grep -v "^#" | grep -v "^$")')
        lines.append(f"verible-verilog-lint {rules_flag} $files 2>&1")
    elif target_dir:
        if lint_mode == "src_only":
            lines.append(f'# Lint src files in {target_dir}')
            lines.append(f'src_files=$(find "{target_dir}" -path "*/src/*" -type f \\( -name "*.sv" -o -name "*.v" \\) | sort)')
            lines.append(f"verible-verilog-lint {rules_flag} $src_files 2>&1")
        elif lint_mode == "tb_only":
            lines.append(f'# Lint tb files in {target_dir}')
            lines.append(f'tb_files=$(find "{target_dir}" -path "*/tb/*" -type f \\( -name "*.sv" -o -name "*.v" \\) | sort)')
            lines.append(f"verible-verilog-lint {rules_flag} $tb_files 2>&1")
        else:  # src_and_tb
            lines.append(f'# Lint src files in {target_dir}')
            lines.append(f'src_files=$(find "{target_dir}" -path "*/src/*" -type f \\( -name "*.sv" -o -name "*.v" \\) | sort)')
            lines.append(f"verible-verilog-lint {rules_flag} $src_files 2>&1")
            lines.append("")
            lines.append(f'# Lint tb files in {target_dir}')
            lines.append(f'tb_files=$(find "{target_dir}" -path "*/tb/*" -type f \\( -name "*.sv" -o -name "*.v" \\) | sort)')
            lines.append(f"verible-verilog-lint {rules_flag} $tb_files 2>&1")
    else:
        lines.append('echo "ERROR: No file_list or target_dir specified" >&2')
        lines.append("exit 1")

    lines.append("")
    lines.append('echo "Lint complete"')
    return "\n".join(lines)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Generate lint shell script")
    parser.add_argument("--file-list", help="Path to file_list.f")
    parser.add_argument("--target-dir", help="Target directory to scan")
    parser.add_argument("--rules-config", help="Verible rules config path")
    parser.add_argument("--lint-mode", default="src_only",
                        choices=["src_only", "src_and_tb", "tb_only"])
    args = parser.parse_args()
    print(render(args.file_list, args.target_dir, args.rules_config, args.lint_mode))
