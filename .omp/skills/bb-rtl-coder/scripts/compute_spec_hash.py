#!/usr/bin/env python3
"""Compute SHA-256 hash of specification files for traceability."""
import sys
import json
import hashlib
from pathlib import Path

def compute_spec_hash(spec_dir: str) -> dict:
    """Compute a freshness hash over all spec files in a directory.

    Robust against reordering, renames, and rebalancing: every regular file is
    gathered in a single global sorted() pass and contributes
    `relative_path + "\\0" + sha256(content)` to the combined hasher. The sorted
    file list itself is also folded in so additions/removals change the hash.
    """
    spec_path = Path(spec_dir)
    if not spec_path.exists():
        return {'status': 'error', 'message': f'Directory not found: {spec_dir}'}

    # Single global pass over ALL files (any extension), recursively.
    all_files = sorted(p for p in spec_path.rglob('*') if p.is_file())
    if not all_files:
        return {'status': 'error', 'message': 'No spec files found'}

    rel_paths = [str(p.relative_to(spec_path)) for p in all_files]

    file_hashes = {}
    combined = hashlib.sha256()
    # Fold the file list itself into the hash (path-only manifest).
    combined.update(("\0".join(rel_paths) + "\0").encode('utf-8'))
    for p, rel in zip(all_files, rel_paths):
        content = p.read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        file_hashes[rel] = digest
        combined.update(rel.encode('utf-8'))
        combined.update(b"\0")
        combined.update(digest.encode('ascii'))
        combined.update(b"\0")

    return {'status': 'pass', 'spec_hash': combined.hexdigest(),
            'file_count': len(file_hashes), 'file_hashes': file_hashes}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: compute_spec_hash.py <spec_directory>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(compute_spec_hash(sys.argv[1]), indent=2))
