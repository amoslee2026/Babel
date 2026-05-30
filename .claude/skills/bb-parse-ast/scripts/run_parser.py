#!/usr/bin/env python3
"""Execute AST parser and return JSON status."""
import sys
import subprocess
import json
from pathlib import Path

def run_ast_parser(config_file: str) -> dict:
    """Run pyverilog AST parser."""
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)

        files_json = json.dumps(config['files'])
        cmd = ['python3', '-c',
               f'from pyverilog.vparser.parser import parse; import json; '
               f'ast = parse({files_json}); print(json.dumps(ast, indent=2, default=str))']

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            return {'status': 'error', 'message': 'Parser failed', 'error': result.stderr}

        ast_file = f"{config['top_module']}_ast.json"
        with open(ast_file, 'w') as f:
            f.write(result.stdout)

        sys.path.insert(0, str(Path(__file__).parent))
        from parse_ast_output import parse_ast
        ast_data = parse_ast(ast_file)

        return {'status': 'pass', 'top_module': config['top_module'],
                'modules_found': len(ast_data['modules']), 'ast_file': ast_file}
    except FileNotFoundError:
        return {'status': 'error', 'message': f'Config not found: {config_file}'}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'message': 'Parser timeout'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: run_parser.py <config.json>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(run_ast_parser(sys.argv[1]), indent=2))
