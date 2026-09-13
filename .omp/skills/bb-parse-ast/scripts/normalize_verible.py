#!/usr/bin/env python3
"""Normalize verible JSON AST to standard Babel AST format."""
import sys
import json

def normalize_verible(verible_ast: dict) -> dict:
    """Convert verible AST to Babel standard format."""
    result = {'modules': [], 'ports': {}, 'instances': {}, 'parameters': {}, 'status': 'pass'}

    def walk(node, context=None):
        if not isinstance(node, dict):
            return
        tag = node.get('tag', '')
        if tag == 'kModuleDeclaration':
            name = extract_module_name(node)
            if name:
                result['modules'].append(name)
                result['ports'][name] = extract_ports(node)
                context = name
        elif tag == 'kModuleInstantiation' and context:
            inst = extract_instance(node)
            if inst:
                result['instances'].setdefault(context, []).append(inst)
        for child in node.get('children', []):
            walk(child, context)

    walk(verible_ast)
    return result

def extract_module_name(node):
    for c in node.get('children', []):
        if c.get('tag') == 'SymbolIdentifier':
            return c.get('text', '')
    return ''

def extract_ports(node):
    ports = []
    def find(n):
        if n.get('tag') == 'kPortDeclaration':
            port = {'name': '', 'direction': 'inout', 'width': 1}
            for c in n.get('children', []):
                if c.get('tag') in ('input', 'output', 'inout'):
                    port['direction'] = c['tag']
                elif c.get('tag') == 'SymbolIdentifier':
                    port['name'] = c.get('text', '')
            if port['name']:
                ports.append(port)
        for c in n.get('children', []):
            find(c)
    find(node)
    return ports

def extract_instance(node):
    inst = {'name': '', 'module': '', 'parameters': {}}
    for c in node.get('children', []):
        if c.get('tag') == 'SymbolIdentifier':
            if not inst['module']:
                inst['module'] = c.get('text', '')
            else:
                inst['name'] = c.get('text', '')
    return inst if inst['name'] else None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: normalize_verible.py <verible_ast.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r') as f:
        print(json.dumps(normalize_verible(json.load(f)), indent=2))
