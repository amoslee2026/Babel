#!/usr/bin/env python3
"""Parse verible-verilog-lint output and generate JSON report.

Verible diagnostic formats handled:
  - Syntax errors:  <file>:<line>:<col>: syntax error[, ...] <detail>
  - Style lint:     <file>:<line>:<col>: <message> [<rule-name>]

Gating: `clean`/pass gates on ERRORS only (syntax errors). Style warnings are
reported but do not fail src. Fail CLOSED: if the log is non-empty but yields
ZERO parsed diagnostics, status is "error" (format mismatch), not clean.
"""
import sys
import re
import json

# <file>:<line>:<col>: <message>
DIAG_RE = re.compile(r'^(?P<file>[^:\n]+):(?P<line>\d+):(?P<col>\d+):\s+(?P<msg>.*)$',
                     re.MULTILINE)
# Trailing [rule-name] on a style-lint diagnostic.
RULE_RE = re.compile(r'\[([A-Za-z0-9_\-]+)\]\s*$')


def parse_verible_output(log_file: str) -> dict:
    """Parse verible-verilog-lint output file."""
    with open(log_file, 'r') as f:
        content = f.read()

    warnings = []
    errors = []
    categories = {}

    for match in DIAG_RE.finditer(content):
        file_ = match.group('file')
        line = int(match.group('line'))
        col = int(match.group('col'))
        msg = match.group('msg').strip()

        low = msg.lower()
        is_error = ('syntax error' in low) or low.startswith('error')

        if is_error:
            errors.append({'file': file_, 'line': line, 'col': col, 'message': msg})
        else:
            rule_match = RULE_RE.search(msg)
            rule = rule_match.group(1) if rule_match else 'style'
            warnings.append({'category': rule, 'rule': rule, 'file': file_,
                             'line': line, 'col': col, 'message': msg})
            categories[rule] = categories.get(rule, 0) + 1

    diag_count = len(errors) + len(warnings)
    log_nonempty = bool(content.strip())

    # Fail CLOSED on format mismatch: non-empty log, zero parsed diagnostics.
    if log_nonempty and diag_count == 0:
        return {
            'status': 'error',
            'clean': False,
            'error': 'lint log non-empty but no diagnostics parsed (format mismatch)',
            'warnings': [], 'errors': [], 'categories': {},
            'warning_count': 0, 'error_count': 0,
        }

    # ERROR-gating only: warnings do not fail src.
    return {
        'status': 'ok',
        'error': None,
        'clean': len(errors) == 0,
        'warnings': warnings, 'errors': errors, 'categories': categories,
        'warning_count': len(warnings), 'error_count': len(errors),
    }


# Backwards-compatible alias for existing callers.
def parse_verilator_output(log_file: str) -> dict:
    return parse_verible_output(log_file)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: parse_lint.py <lint_log_file>", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(parse_verible_output(sys.argv[1]), indent=2))
