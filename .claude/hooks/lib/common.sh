#!/usr/bin/env bash
# Shared helpers for .claude/hooks/*.sh
# Source this file: . "$(dirname "$0")/lib/common.sh"
set -euo pipefail

# Read stdin JSON safely
read_stdin_json() {
  cat 2>/dev/null || echo '{}'
}

# Parse PostToolUse / PreToolUse stdin JSON -> echo a field from tool_input.
# usage: ti_field <field_name>
# SECURITY (D8-07): field name is passed via os.environ, NEVER interpolated
# into the Python source. This eliminates the latent code-injection footgun
# where a future caller passing a user-derived field name would give an
# attacker full Python execution inside the hook.
ti_field() {
  TI_FIELD="$1" python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get(os.environ['TI_FIELD'], ''))
except Exception:
    pass
" 2>/dev/null
}

# Extract field from JSON via python (safe, no eval).
# SECURITY (D8-07): field name passed via os.environ, never interpolated.
json_field() {
  local json="$1" field="$2" default="${3:-}"
  printf '%s' "$json" | JSON_FIELD="$field" python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    f = os.environ['JSON_FIELD']
    print(d.get('tool_input', {}).get(f, '') or d.get(f, ''))
except Exception:
    pass
" 2>/dev/null || printf '%s' "$default"
}

# Extract design name from a path like designs/<name>/...
design_from_path() {
  printf '%s' "$1" | sed -nE 's|.*designs/([^/]+)/.*|\1|p'
}

# UTC ISO8601 timestamp
iso_now() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
stamp_now() { date -u +'%Y%m%d_%H%M%S'; }
