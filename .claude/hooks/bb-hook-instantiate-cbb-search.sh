#!/usr/bin/env bash
# instantiate-cbb-search.sh — v1.3 MVP stub
#
# PreToolUse hook on Write/Edit: if file content matches CBB instantiation
# patterns, suggest invoking bb-search-cbb / bb-get-interface-template first.
# fail-soft (warning only).

set -eu

INPUT="$(cat || true)"
CONTENT="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json
d=json.load(sys.stdin)
ti=d.get("tool_input",{})
print(ti.get("content","") or ti.get("new_string",""))' 2>/dev/null || true)"

[ -z "${CONTENT:-}" ] && exit 0

# Detect candidate CBB names referenced in code/comments.
NAMES="$(printf '%s' "$CONTENT" | grep -oE '\b(sync[-_]?fifo|2ff[-_]?sync|clock[-_]?gate)\b' | sort -u | tr '\n' ' ')"

if [ -n "${NAMES:-}" ]; then
  cat >&2 <<EOF
💡 CBB_INSTANCE_HINT: Detected CBB references: $NAMES
    Run these skills first to verify template + port list:
      Skill(bb-search-cbb,            args="<name>")
      Skill(bb-get-interface-template, args="<name>")
EOF
fi

exit 0
