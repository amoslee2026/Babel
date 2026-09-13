#!/usr/bin/env python3
"""Render signal trace configuration from AST and signal name."""
import sys
import json

def render_trace_config(ast_file: str, signal_name: str, top_module: str) -> dict:
    """Generate signal trace configuration."""
    with open(ast_file, 'r') as f:
        ast = json.load(f)

    config = {
        'top_module': top_module, 'target_signal': signal_name, 'ast_file': ast_file,
        'trace_direction': 'both', 'max_depth': 10, 'include_timing': True
    }

    # Find which module contains the signal as a port
    for mod, ports in ast.get('ports', {}).items():
        for port in ports:
            if port['name'] == signal_name:
                config['source_module'] = mod
                config['source_type'] = 'port'

    # Check instances for parameter references
    related = []
    for mod, instances in ast.get('instances', {}).items():
        for inst in instances:
            if signal_name in str(inst.get('parameters', {})):
                related.append({'module': mod, 'instance': inst['name']})
    if related:
        config['related_instances'] = related

    return config

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: render_trace_py.py <ast.json> <signal_name> <top_module>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(render_trace_config(sys.argv[1], sys.argv[2], sys.argv[3]), indent=2))
