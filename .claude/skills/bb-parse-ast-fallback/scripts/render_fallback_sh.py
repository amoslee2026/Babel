#!/usr/bin/env python3
"""Generate fallback parsing shell script for verible or slang backend.

Renders a bash script that invokes the chosen backend parser
and normalizes the output to the common AST JSON schema.
"""
import json
import sys
from pathlib import Path


def render_verible_script(
    file_list: str,
    raw_output: str,
    artifact_path: str,
    normalize_script: str,
) -> str:
    """Render shell script for verible backend.

    Args:
        file_list: Path to file_list.f.
        raw_output: Path for raw verible output.
        artifact_path: Path for normalized AST JSON.
        normalize_script: Path to normalize_verible.py.

    Returns:
        Bash script content.
    """
    return f'''#!/usr/bin/env bash
# Auto-generated fallback parsing script (verible backend)
set -euo pipefail

FILE_LIST="{file_list}"
RAW_OUT="{raw_output}"
ARTIFACT="{artifact_path}"
NORMALIZE="{normalize_script}"

# Ensure output directory exists
mkdir -p "$(dirname "$RAW_OUT")"
mkdir -p "$(dirname "$ARTIFACT")"

# Clear raw output
> "$RAW_OUT"

# Run verible-verilog-syntax on each file
echo "=== verible-verilog-syntax ==="
while IFS= read -r f; do
    # Skip empty lines and comments
    [[ -z "$f" || "$f" == //* ]] && continue
    echo "Parsing: $f"
    verible-verilog-syntax --export_json "$f" >> "$RAW_OUT" 2>&1 || true
done < "$FILE_LIST"

# Normalize output
echo "=== Normalizing ==="
uv run python "$NORMALIZE" --input "$RAW_OUT" --output "$ARTIFACT"

echo "=== Done ==="
'''


def render_slang_script(
    file_list: str,
    raw_output: str,
    artifact_path: str,
    normalize_script: str,
) -> str:
    """Render shell script for slang backend.

    Args:
        file_list: Path to file_list.f.
        raw_output: Path for raw slang output.
        artifact_path: Path for normalized AST JSON.
        normalize_script: Path to normalize_slang.py.

    Returns:
        Bash script content.
    """
    return f'''#!/usr/bin/env bash
# Auto-generated fallback parsing script (slang backend)
set -euo pipefail

FILE_LIST="{file_list}"
RAW_OUT="{raw_output}"
ARTIFACT="{artifact_path}"
NORMALIZE="{normalize_script}"

# Ensure output directory exists
mkdir -p "$(dirname "$RAW_OUT")"
mkdir -p "$(dirname "$ARTIFACT")"

# Collect files
FILES=$(grep -v '^\\s*//' "$FILE_LIST" | grep -v '^\\s*$' | tr '\\n' ' ')

# Run slang
echo "=== slang ==="
echo "Parsing files: $FILES"
slang --ast-json "$RAW_OUT" $FILES 2>&1 || true

# Normalize output
echo "=== Normalizing ==="
uv run python "$NORMALIZE" --input "$RAW_OUT" --output "$ARTIFACT"

echo "=== Done ==="
'''


def render_fallback_sh(
    file_list: str,
    backend: str,
    raw_output: str,
    artifact_path: str,
    normalize_script: str,
) -> str:
    """Render fallback shell script for the specified backend.

    Args:
        file_list: Path to file_list.f.
        backend: 'verible' or 'slang'.
        raw_output: Path for raw backend output.
        artifact_path: Path for normalized AST JSON.
        normalize_script: Path to the normalization script.

    Returns:
        Bash script content.
    """
    if backend == "slang":
        return render_slang_script(file_list, raw_output, artifact_path, normalize_script)
    else:
        return render_verible_script(file_list, raw_output, artifact_path, normalize_script)


def main():
    if len(sys.argv) < 6:
        print(
            f"Usage: {sys.argv[0]} <file_list> <backend> <raw_output> <artifact_path> <normalize_script>",
            file=sys.stderr,
        )
        sys.exit(1)

    file_list = sys.argv[1]
    backend = sys.argv[2]
    raw_output = sys.argv[3]
    artifact_path = sys.argv[4]
    normalize_script = sys.argv[5]

    if backend not in ("verible", "slang"):
        print(f"ERROR: Unknown backend '{backend}'. Use 'verible' or 'slang'.", file=sys.stderr)
        sys.exit(1)

    script = render_fallback_sh(file_list, backend, raw_output, artifact_path, normalize_script)
    print(script)


if __name__ == "__main__":
    main()
