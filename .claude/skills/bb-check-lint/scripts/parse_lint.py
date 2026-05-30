#!/usr/bin/env python3
"""Parse Verilator lint output and generate JSON report."""
import sys
import re
import json

def parse_verilator_output(log_file: str) -> dict:
    """Parse Verilator lint output file."""
    with open(log_file, 'r') as f:
        content = f.read()

    warnings = []
    errors = []
    categories = {}

    warn_pattern = r'%Warning-(\w+):\s+(.+?):(\d+):\s+(.+)'
    for match in re.finditer(warn_pattern, content):
        category, file, line, msg = match.groups()
        warnings.append({'category': category, 'file': file, 'line': int(line), 'message': msg})
        categories[category] = categories.get(category, 0) + 1

    err_pattern = r'%Error:\s+(.+?):(\d+):\s+(.+)'
    for match in re.finditer(err_pattern, content):
        file, line, msg = match.groups()
        errors.append({'file': file, 'line': int(line), 'message': msg})

    return {
        'clean': len(errors) == 0 and len(warnings) == 0,
        'warnings': warnings, 'errors': errors, 'categories': categories,
        'warning_count': len(warnings), 'error_count': len(errors)
    }

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_lint.py <lint_log_file>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_verilator_output(sys.argv[1]), indent=2))
