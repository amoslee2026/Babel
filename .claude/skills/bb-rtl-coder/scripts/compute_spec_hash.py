#!/usr/bin/env python3
"""Compute SHA-256 hash of specification files for traceability."""
import hashlib, json, sys
from pathlib import Path


def compute_spec_hash(spec_dir: str) -> str:
    h = hashlib.sha256()
    for f in sorted(Path(spec_dir).rglob("*.md")):
        h.update(f.read_bytes())
    return h.hexdigest()[:16]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: compute_spec_hash.py <spec_dir>", file=sys.stderr)
        sys.exit(1)
    result = compute_spec_hash(sys.argv[1])
    print(json.dumps({"spec_hash": result, "spec_dir": sys.argv[1]}))
