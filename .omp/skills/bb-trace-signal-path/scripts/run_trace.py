#!/usr/bin/env python3
"""Execute signal tracing and return JSON status."""
import sys
import json
from pathlib import Path

def run_signal_trace(config_file: str) -> dict:
    """Run signal tracing through design hierarchy."""
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        with open(config['ast_file'], 'r') as f:
            ast = json.load(f)

        results = trace_signal(ast, config['target_signal'],
                               config.get('source_module'), config.get('max_depth', 10))
        output_file = f"{config['target_signal']}_trace.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)

        sys.path.insert(0, str(Path(__file__).parent))
        from parse_trace import parse_trace_results
        parsed = parse_trace_results(output_file)

        return {'status': 'pass', 'signal': config['target_signal'],
                'path_length': len(parsed['signal_path']),
                'fan_out_count': len(parsed['fan_out']), 'trace_file': output_file}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def trace_signal(ast, signal, source_module, max_depth):
    """Trace signal through hierarchy."""
    results = {'path': [], 'fan_out': {}, 'timing': {}}
    if source_module:
        results['path'].append({'module': source_module, 'signal': signal, 'type': 'port'})
        _trace_forward(ast, source_module, signal, results, 0, max_depth)
        _trace_backward(ast, source_module, signal, results, 0, max_depth)
    return results

def _trace_forward(ast, module, signal, results, depth, max_depth):
    if depth >= max_depth: return
    for inst in ast.get('instances', {}).get(module, []):
        results['path'].append({'module': inst['module'], 'signal': signal,
                                'type': 'instance', 'instance_name': inst['name']})
        _trace_forward(ast, inst['module'], signal, results, depth + 1, max_depth)

def _trace_backward(ast, module, signal, results, depth, max_depth):
    if depth >= max_depth: return
    for parent, instances in ast.get('instances', {}).items():
        for inst in instances:
            if inst['module'] == module:
                results['path'].append({'module': parent, 'signal': signal,
                                        'type': 'parent', 'instance_name': inst['name']})
                _trace_backward(ast, parent, signal, results, depth + 1, max_depth)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: run_trace.py <config.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_signal_trace(sys.argv[1]), indent=2))
