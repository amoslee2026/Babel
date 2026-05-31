#!/usr/bin/env python3
"""Compute sha256 of files for MAS inputs[]/outputs[] freshness records.

The bba-architect agent has no Bash tool (least-privilege), so it cannot run
`sha256sum`. This helper lets the bb-mas skill produce the `{path, sha256}`
entries that mas.schema.json requires for `inputs[]` (idea/spec files consumed)
and `outputs[]` (PRD / arch_spec / MAS markdown produced). Downstream RTL
recomputes these hashes and compares to detect stale handoffs (CR-5).

Usage:
    python hash_outputs.py <file> [<file> ...]
    python hash_outputs.py --base <dir> <file> [<file> ...]   # store paths relative to <dir>

Output (stdout): JSON array sorted by path, e.g.
    [{"path": "PRD.md", "sha256": "<64-hex>"}, ...]

Exit codes:
    0  all files hashed
    1  one or more files missing/unreadable (reported on stderr; NOT emitted as a fake hash)

Targets Python 3.6+ to match the rest of the Babel skill scripts.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def sha256_file(path: Path) -> str:
    """Stream-hash a file so large artifacts don't load fully into memory."""
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def hash_files(files: List[str], base: Optional[Path]) -> Tuple[List[Dict[str, str]], List[str]]:
    records = []  # type: List[Dict[str, str]]
    errors = []  # type: List[str]
    for raw in files:
        p = Path(raw)
        if not p.is_file():
            errors.append("missing or not a file: {}".format(raw))
            continue
        if base is not None and base in p.resolve().parents:
            rel = str(p.resolve().relative_to(base))
        else:
            rel = str(p)
        records.append({"path": rel, "sha256": sha256_file(p)})
    records.sort(key=lambda r: r["path"])
    return records, errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Hash files for MAS inputs[]/outputs[].")
    parser.add_argument("files", nargs="+", help="Files to hash")
    parser.add_argument("--base", help="Directory to make paths relative to", default=None)
    args = parser.parse_args()

    base = Path(args.base).resolve() if args.base else None
    records, errors = hash_files(args.files, base)

    for e in errors:
        sys.stderr.write("[hash_outputs] ERROR: {}\n".format(e))

    # Emit only successfully-hashed records; never fabricate a hash for a missing file.
    print(json.dumps(records, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
