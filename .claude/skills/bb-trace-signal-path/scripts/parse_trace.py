#!/usr/bin/env python3
"""Parse signal trace results and generate JSON report."""
import sys
import json

def parse_trace_results(trace_file: str) -> dict:
    """Parse signal trace results."""
    with open(trace_file, 'r') as f:
        data = json.load(f)

    result = {'signal_path': [], 'fan_out': {}, 'timing': {}, 'status': 'pass'}

    for node in data.get('path', []):
        result['signal_path'].append({
            'module': node.get('module', ''), 'signal': node.get('signal', ''),
            'type': node.get('type', 'wire')})

    for signal, dests in data.get('fan_out', {}).items():
        result['fan_out'][signal] = {'count': len(dests), 'destinations': dests}

    for signal, info in data.get('timing', {}).items():
        result['timing'][signal] = {
            'delay_ps': info.get('delay_ps', 0), 'slew_ps': info.get('slew_ps', 0)}

    return result

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_trace.py <trace_results.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_trace_results(sys.argv[1]), indent=2))
