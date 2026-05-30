#!/usr/bin/env bash
# bb-hook-session-summarize.sh — v1.3 MVP stub (fail-soft)
#
# SessionEnd hook: emit a brief summary of designs/handoffs touched
# this session. Reads handoff log from git working tree (best-effort,
# since the session transcript is not directly available to hooks).

set -euo pipefail
. "$(dirname "$0")/lib/common.sh"

# CWD anchor (D3-04)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi

STAMP="$(stamp_now)"
OUT_DIR="${BB_SESSION_SUMMARY_DIR:-.claude/session_summaries}"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/session_${STAMP}.md"

{
  echo "# Session Summary — $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo
  echo "## Designs touched (incremental, M-03)"
  LAST_RUN=".claude/session_summaries/.last_run"
  shopt -s nullglob globstar
  if [ -f "$LAST_RUN" ]; then
    for d in designs/*/; do
      [ -d "$d/.handoff" ] || continue
      if find "$d/.handoff" -newer "$LAST_RUN" -type f -name '*.md' | head -1 | grep -q .; then
        echo "- $d (delta)"
      fi
    done
  else
    for d in designs/*/; do
      [ -d "$d/.handoff" ] || continue
      echo "- $d"
    done
  fi
  touch "$LAST_RUN"

  echo
  echo "## Handoffs (open)"
  for h in designs/*/.handoff/*.md; do
    label="$(basename "$h" .md)"
    case "$label" in
      ready-for-rtl|ready-for-verification|ready-for-synth|ready-for-pd|signoff)
        echo "  - [open] $h ($label)" ;;
    esac
  done

  echo
  echo "## Fix issues (escalations)"
  for h in designs/*/.handoff/*-needs-fix.md; do
    [ -f "$h" ] || continue
    echo "  - $h"
  done

  echo
  echo "## Stale downstream markers"
  for s in designs/*/.stale/*.stale; do
    [ -f "$s" ] || continue
    echo "  - $s"
  done

  echo
  echo "## Next steps"
  echo "- Run \`bash .claude/hooks/pipeline-advance.sh\` to see suggested next agents."
} > "$OUT"

echo "[session-summarize] wrote $OUT" >&2

# Cleanup: keep only last 30 session summaries
# nullglob reset (B17): isolate per loop
SUMMARY_DIR="$(dirname "$0")/../session_summaries"
if [ -d "$SUMMARY_DIR" ]; then
  shopt -s nullglob
  mapfile -t ALL < <(ls -1t "$SUMMARY_DIR"/session_*.md 2>/dev/null)
  shopt -u nullglob
  if [ "${#ALL[@]}" -gt 30 ]; then
    ARCHIVE_DIR="${SUMMARY_DIR}/../.review/archived"
    mkdir -p "$ARCHIVE_DIR"
    for old in "${ALL[@]:30}"; do
      if ! mv "$old" "$ARCHIVE_DIR/" 2>>"${SUMMARY_DIR}/.cleanup_errors.log"; then
        echo "  [cleanup-error] failed to archive $old" >&2
      fi
    done
  fi
fi

# Retention: auto-delete archived sessions older than 14 days (C14/D2-04)
ARCHIVE_DIR="${SUMMARY_DIR}/../.review/archived"
if [ -d "$ARCHIVE_DIR" ]; then
  find "$ARCHIVE_DIR" -type f -name 'session_*.md' -mtime +14 -delete 2>/dev/null \
    || echo "  [retention] cleanup of $ARCHIVE_DIR failed" >&2
fi

exit 0
