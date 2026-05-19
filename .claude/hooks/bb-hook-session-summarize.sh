#!/usr/bin/env bash
# session-summarize.sh — v1.3 MVP stub (fail-soft)
#
# SessionEnd hook: emit a brief summary of designs/handoffs touched
# this session. Reads handoff log from git working tree (best-effort,
# since the session transcript is not directly available to hooks).

set -eu

STAMP="$(date -u +'%Y%m%d-%H%M%SZ')"
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

echo "[session-summarize] wrote $OUT"
exit 0
