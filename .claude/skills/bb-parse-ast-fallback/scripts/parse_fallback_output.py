#!/usr/bin/env python3
"""Parse fallback parser (slang/verible) output into normalized AST JSON."""
import sys
import json
import re

def parse_fallback_output(parser_type: str, output_file: str) -> dict:
    """Parse output from fallback parsers."""
    with open(output_file, 'r') as f:
        raw_output = f.read()

    if parser_type == 'slang':
        sys.path.insert(0, str(Path(__file__).parent))
        from normalize_slang import normalize_slang
        return normalize_slang(json.loads(raw_output))
    elif parser_type == 'verible':
        from normalize_verible import normalize_verible
        return normalize_verible(json.loads(raw_output))
    return parse_regex_fallback(raw_output)

def parse_regex_fallback(content: str) -> dict:
    """Regex-based fallback parser."""
    result = {'modules': [], 'ports': {}, 'instances': {}, 'status': 'partial'}
    for m in re.finditer(r'module\s+(\w+)', content):
        result['modules'].append(m.group(1))
    for module in result['modules']:
        ports = []
        for m in re.finditer(r'(input|output|inout)\s+(?:logic\s+)?(?:\[(\d+):(\d+)\]\s+)?(\w+)', content):
            direction, msb, lsb, name = m.groups()
            width = int(msb) - int(lsb) + 1 if msb else 1
            ports.append({'name': name, 'direction': direction, 'width': width})
        result['ports'][module] = ports
    return result

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: parse_fallback_output.py <parser_type> <output_file>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_fallback_output(sys.argv[1], sys.argv[2]), indent=2))
