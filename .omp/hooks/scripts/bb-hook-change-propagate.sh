#!/usr/bin/env bash
# bb-hook-change-propagate.sh — v1.3 MVP stub (fail-soft)
#
# PostToolUse hook on Write/Edit targeting upstream artifacts. Mark
# downstream artifacts as stale (notification only; no auto-rebuild).

set -euo pipefail
. "$(dirname "$0")/lib/common.sh"

# CWD anchor (D3-04): hooks must not depend on caller's working directory
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi

INPUT="$(cat 2>/dev/null || true)"
TARGET="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
[ -z "${TARGET:-}" ] && exit 0

DESIGN="$(printf '%s' "$TARGET" | sed -nE 's|.*designs/([^/]+)/.*|\1|p')"
# Path-traversal guard (D8-10): DESIGN must be a plain slug
case "$DESIGN" in
  ""|../*|*../*) exit 0 ;;
esac
if ! printf '%s' "$DESIGN" | grep -qE '^[a-z0-9][a-z0-9_-]{0,31}$'; then
  exit 0
fi

case "$TARGET" in
  *designs/*/mas/mas.json)            STAGE="mas";     DOWN="rtl verif synth pd" ;;
  *designs/*/rtl_artifact.json)        STAGE="rtl";     DOWN="verif synth pd"     ;;
  *designs/*/test_report.json)         STAGE="verif";   DOWN="synth pd"           ;;
  *designs/*/synth_report.json)        STAGE="synth";   DOWN="pd"                 ;;
  *) exit 0 ;;
esac

NEW_HASH="$(sha256sum "$TARGET" 2>/dev/null | awk '{print $1}')"

# Mark each downstream artifact as stale by touching .stale flags.
for d in $DOWN; do
  flag="designs/${DESIGN}/.stale/${d}.stale"
  mkdir -p "$(dirname "$flag")"
  cat > "$flag" <<EOF
upstream_artifact: $TARGET
upstream_sha256: $NEW_HASH
marked_stale_at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
EOF
done

cat >&2 <<EOF
⚠️  CHANGE_PROPAGATE: Upstream modified — $TARGET
    new sha256: $NEW_HASH
    Downstream marked stale: $DOWN
    Re-run downstream agents to rebuild.
EOF

exit 0
