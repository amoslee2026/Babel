#!/usr/bin/env python3
"""Parse CDC analysis results and generate JSON report."""
import sys
import re
import json

def parse_cdc_output(log_file: str) -> dict:
    """Parse CDC analysis log file."""
    with open(log_file, 'r') as f:
        content = f.read()

    async_crossings, synchronized, unresolved = [], [], []

    for m in re.finditer(r'ASYNC_CROSSING:\s+(.+?)\s+from\s+(\w+)\s+to\s+(\w+)', content):
        async_crossings.append({'signal': m.group(1), 'source_clock': m.group(2), 'dest_clock': m.group(3)})
    for m in re.finditer(r'SYNCHRONIZED:\s+(.+?)\s+\((\d+)-FF\)', content):
        synchronized.append({'signal': m.group(1), 'sync_stages': int(m.group(2))})
    for m in re.finditer(r'UNRESOLVED:\s+(.+?)\s+from\s+(\w+)\s+to\s+(\w+)', content):
        unresolved.append({'signal': m.group(1), 'source_clock': m.group(2), 'dest_clock': m.group(3)})

    return {'cdc_clean': len(unresolved) == 0, 'async_crossings': async_crossings,
            'synchronized': synchronized, 'unresolved': unresolved,
            'async_count': len(async_crossings), 'sync_count': len(synchronized),
            'unresolved_count': len(unresolved)}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_cdc.py <cdc_log_file>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_cdc_output(sys.argv[1]), indent=2))
