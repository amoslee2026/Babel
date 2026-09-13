#!/usr/bin/env python3
"""Normalize slang JSON AST to standard Babel AST format."""
import sys
import json

def normalize_slang(slang_ast: dict) -> dict:
    """Convert slang AST to Babel standard format."""
    result = {'modules': [], 'ports': {}, 'instances': {}, 'parameters': {}, 'status': 'pass'}

    for member in slang_ast.get('members', []):
        kind = member.get('kind', '')
        name = member.get('name', 'unknown')

        if kind in ('Instance', 'ModuleDeclaration'):
            result['modules'].append(name)

            if kind == 'Instance' and 'connections' in member:
                result['ports'][name] = [
                    {'name': c.get('portName', ''), 'signal': c.get('expr', {}).get('value', '')}
                    for c in member['connections']]
            elif kind == 'ModuleDeclaration':
                ports = []
                for sub in member.get('members', []):
                    if sub.get('kind') == 'PortDeclaration':
                        ports.append({
                            'name': sub.get('name', ''),
                            'direction': sub.get('direction', 'inout'),
                            'width': extract_width(sub)})
                result['ports'][name] = ports
    return result

def extract_width(port_node: dict) -> int:
    """Extract bit width from port declaration."""
    type_info = port_node.get('type', {})
    range_info = type_info.get('range', {})
    if range_info:
        return abs(range_info.get('left', 0) - range_info.get('right', 0)) + 1
    return 1

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: normalize_slang.py <slang_ast.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r') as f:
        print(json.dumps(normalize_slang(json.load(f)), indent=2))
