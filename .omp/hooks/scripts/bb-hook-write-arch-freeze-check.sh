#!/usr/bin/env bash
# bb-hook-write-arch-freeze-check.sh — v1.3 MVP stub
#
# PreToolUse hook on Write/Edit targeting designs/*/{rtl,mas}/**.
# Warn (non-blocking) when MAS is frozen (a `ready-for-rtl` handoff exists)
# and the user is editing RTL/MAS directly.

set -euo pipefail
. "$(dirname "$0")/lib/common.sh"

# CWD anchor (D3-04)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi

# Read tool_input JSON from stdin (claude-code hook protocol).
INPUT="$(cat 2>/dev/null || true)"
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
    Recovery: bb-create-issue --label arch-needs-fix --artifact $TARGET
EOF
fi

exit 0
