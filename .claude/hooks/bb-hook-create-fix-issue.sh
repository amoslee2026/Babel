#!/usr/bin/env bash
# bb-hook-create-fix-issue.sh — v1.3 MVP (fail-soft)
#
# PostToolUse hook triggered when a Write/Edit creates a `<upstream>-needs-fix.md`
# handoff file. Logs the escalation; the actual handoff was written by the agent.

set -euo pipefail
. "$(dirname "$0")/lib/common.sh"

INPUT="$(cat || true)"
TARGET="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "${TARGET:-}" ] && exit 0
case "$TARGET" in
  *-needs-fix.md) ;;
  *) exit 0 ;;
esac

DESIGN="$(printf '%s' "$TARGET" | sed -nE 's|.*designs/([^/]+)/.handoff/.*|\1|p')"
LABEL="$(basename "$TARGET" .md)"
[ -z "${DESIGN:-}" ] && exit 0

cat >&2 <<EOF
🔧 FIX_ISSUE_CREATED: escalation handoff written
    file:    $TARGET
    label:   $LABEL
    design:  $DESIGN
    next:    upstream agent should pick up this handoff
EOF

LOG=".claude/.review/escalations.log"
mkdir -p "$(dirname "$LOG")"
echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ')	$LABEL	$TARGET" >> "$LOG"

exit 0
