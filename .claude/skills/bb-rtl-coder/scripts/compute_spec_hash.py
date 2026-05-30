#!/usr/bin/env python3
"""Compute SHA-256 hash of specification files for traceability."""
import sys
import json
import hashlib
from pathlib import Path

def compute_spec_hash(spec_dir: str) -> dict:
    """Compute hashes for all spec files in directory."""
    spec_path = Path(spec_dir)
    if not spec_path.exists():
        return {'status': 'error', 'message': f'Directory not found: {spec_dir}'}

    spec_files = []
    for ext in ['*.md', '*.json', '*.yaml', '*.yml']:
        spec_files.extend(sorted(spec_path.glob(ext)))
    if not spec_files:
        return {'status': 'error', 'message': 'No spec files found'}

    file_hashes = {}
    combined_content = b''
    for sf in spec_files:
        with open(sf, 'rb') as f:
            content = f.read()
            file_hashes[str(sf.relative_to(spec_path))] = hashlib.sha256(content).hexdigest()
            combined_content += content

    return {'status': 'pass', 'spec_hash': hashlib.sha256(combined_content).hexdigest(),
            'file_count': len(file_hashes), 'file_hashes': file_hashes}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: compute_spec_hash.py <spec_directory>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(compute_spec_hash(sys.argv[1]), indent=2))
