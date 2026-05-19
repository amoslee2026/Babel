#!/usr/bin/env bash
# write-arch-freeze-check.sh — v1.3 MVP stub
#
# PreToolUse hook on Write/Edit targeting designs/*/{rtl,mas}/**.
# Warn (non-blocking) when MAS is frozen (a `ready-for-rtl` handoff exists)
# and the user is editing RTL/MAS directly.

set -eu

# Read tool_input JSON from stdin (claude-code hook protocol).
INPUT="$(cat || true)"
TARGET="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "${TARGET:-}" ] && exit 0

# Only fire on designs/<name>/{rtl,mas}/...
case "$TARGET" in
  *designs/*/rtl/*|*designs/*/mas/*) ;;
  *) exit 0 ;;
esac

# Extract design name
DESIGN="$(printf '%s' "$TARGET" | sed -E 's|.*designs/([^/]+)/.*|\1|')"
HANDOFF="designs/${DESIGN}/.handoff/ready-for-rtl.md"

if [ -f "$HANDOFF" ]; then
  cat >&2 <<EOF
⚠️  ARCH_FREEZE_WARNING: $TARGET
    MAS frozen (handoff: $HANDOFF).
    Direct edits may invalidate downstream artifacts.
    Consider creating a handoff with label 'arch-needs-fix' instead.
EOF
fi

exit 0
