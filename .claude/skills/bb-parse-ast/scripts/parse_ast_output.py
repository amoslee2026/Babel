#!/usr/bin/env python3
"""Parse pyverilog/slang AST JSON output and extract modules, ports, instances."""
import sys
import json

def parse_ast(ast_json_file: str) -> dict:
    """Parse AST JSON and extract design elements."""
    with open(ast_json_file, 'r') as f:
        ast = json.load(f)

    result = {'modules': [], 'ports': {}, 'instances': {}, 'parameters': {}, 'status': 'pass'}

    for defn in ast.get('definitions', []):
        if defn.get('kind') != 'ModuleDefinition':
            continue
        name = defn['name']
        result['modules'].append(name)

        result['ports'][name] = [
            {'name': p['name'], 'direction': p.get('direction', 'inout'), 'width': p.get('width', 1)}
            for p in defn.get('ports', [])]

        result['instances'][name] = [
            {'name': m['name'], 'module': m.get('moduleName', 'unknown'), 'parameters': m.get('parameters', {})}
            for m in defn.get('members', []) if m.get('kind') == 'Instance']

        result['parameters'][name] = [
            {'name': p['name'], 'type': p.get('type', 'logic'), 'default': p.get('defaultValue')}
            for p in defn.get('parameters', [])]

    return result

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_ast_output.py <ast.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_ast(sys.argv[1]), indent=2))
