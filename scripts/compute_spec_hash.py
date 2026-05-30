#!/usr/bin/env python3
"""
Compute spec file SHA256 hash for @spec_hash annotation.

Usage:
    uv run scripts/compute_spec_hash.py <spec_file>
    uv run scripts/compute_spec_hash.py spec/MAS/M01_DataflowController/MAS.md

Output:
    sha256:abc123def456  (12-char prefix)
"""

import sys
import hashlib
import re
from pathlib import Path


def normalize_spec(content: str) -> str:
    """Normalize spec content by removing whitespace variations and comments."""
    lines = []
    for line in content.splitlines():
        # Strip trailing whitespace
        line = line.rstrip()
        # Skip HTML comments (MAS uses <!-- --> for REQ_ID)
        if line.strip().startswith('<!--') or line.strip().endswith('-->'):
            continue
        # Skip blank lines
        if not line.strip():
            continue
        lines.append(line)
    return '\n'.join(lines)


def compute_spec_hash(spec_file: str) -> str:
    """Compute SHA256 hash of spec file (normalized)."""
    path = Path(spec_file)
    if not path.exists():
        raise FileNotFoundError(f"Spec file not found: {spec_file}")

    content = path.read_text(encoding='utf-8')
    normalized = normalize_spec(content)
    full_hash = hashlib.sha256(normalized.encode('utf-8')).hexdigest()
    return f"sha256:{full_hash[:12]}"


def inject_spec_hash(rtl_file: str, spec_hash: str) -> str:
    """Inject @spec_hash into RTL file's Spec Header.

    Returns the modified content.
    """
    path = Path(rtl_file)
    content = path.read_text(encoding='utf-8')

    # Pattern: find "// Spec Hash:" line in Spec Header
    pattern = r'(// Spec Hash:\s*)(sha256:[a-f0-9]+|\{\{[^}]+\}\})'
    replacement = rf'\g<1>{spec_hash}'

    new_content, count = re.subn(pattern, replacement, content)

    if count == 0:
        raise ValueError(
            f"No 'Spec Hash:' line found in {rtl_file}. "
            "Ensure Spec Header is present before injecting hash."
        )

    return new_content


def main():
    if len(sys.argv) < 2:
        print("Usage: compute_spec_hash.py <spec_file> [--inject <rtl_file>]")
        return 1

    spec_file = sys.argv[1]

    try:
        spec_hash = compute_spec_hash(spec_file)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # --inject mode: write hash into RTL file
    if len(sys.argv) >= 4 and sys.argv[2] == '--inject':
        rtl_file = sys.argv[3]
        try:
            new_content = inject_spec_hash(rtl_file, spec_hash)
            Path(rtl_file).write_text(new_content, encoding='utf-8')
            print(f"✓ Injected {spec_hash} into {rtl_file}")
        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1
    else:
        # Default: print hash
        print(spec_hash)

    return 0


if __name__ == "__main__":
    sys.exit(main())
