#!/usr/bin/env python3
"""Parse fallback parser (slang/verible) output into normalized AST JSON."""
import sys
import json
import re
from pathlib import Path

def parse_fallback_output(parser_type: str, output_file: str) -> dict:
    """Parse output from fallback parsers."""
    with open(output_file, 'r') as f:
        raw_output = f.read()

    if parser_type == 'slang':
        sys.path.insert(0, str(Path(__file__).parent))
        from normalize_slang import normalize_slang
        return normalize_slang(json.loads(raw_output))
    elif parser_type == 'verible':
        sys.path.insert(0, str(Path(__file__).parent))
        from normalize_verible import normalize_verible
        return normalize_verible(json.loads(raw_output))
    return parse_regex_fallback(raw_output)

def parse_regex_fallback(content: str) -> dict:
    """Regex-based fallback parser.

    Ports are scoped to each module's own text span (between `module ...` and the
    matching `endmodule`) so file-wide ports are not cross-contaminated across
    every module.
    """
    result = {'modules': [], 'ports': {}, 'instances': {}, 'status': 'partial'}

    port_re = re.compile(
        r'(input|output|inout)\s+(?:logic\s+)?(?:\[(\d+):(\d+)\]\s+)?(\w+)'
    )

    # Find each module header and slice its body up to the next endmodule.
    for mm in re.finditer(r'\bmodule\s+(\w+)', content):
        name = mm.group(1)
        result['modules'].append(name)
        span_start = mm.start()
        end_match = re.search(r'\bendmodule\b', content[span_start:])
        span_end = span_start + end_match.end() if end_match else len(content)
        module_text = content[span_start:span_end]

        ports = []
        for pm in port_re.finditer(module_text):
            direction, msb, lsb, port_name = pm.groups()
            width = int(msb) - int(lsb) + 1 if msb else 1
            ports.append({'name': port_name, 'direction': direction, 'width': width})
        result['ports'][name] = ports
    return result

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: parse_fallback_output.py <parser_type> <output_file>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_fallback_output(sys.argv[1], sys.argv[2]), indent=2))
