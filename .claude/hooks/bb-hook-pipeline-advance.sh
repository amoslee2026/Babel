#!/usr/bin/env bash
# bb-hook-pipeline-advance.sh — v1.3 MVP (fail-soft)
#
# PostToolUse hook on Write/Edit: when the just-written file is a handoff
# (designs/*/.handoff/<label>.md), emit the suggested next slash command.
# Falls back to scanning the whole tree when invoked manually (no stdin JSON).
#
# v1.3 MVP scope: notification only — NO auto-dispatch (Claude Code hooks
# cannot invoke Skill/Agent). A future v1.4 hook may auto-spawn next agent.

set -euo pipefail
. "$(dirname "$0")/lib/common.sh"

label_to_next() {
  case "$1" in
    ready-for-rtl)           echo "/bba-guru-rtl" ;;
    ready-for-verification)  echo "/bba-guru-verification" ;;
    ready-for-synth)         echo "/bba-guru-synthesis" ;;
    ready-for-pd)            echo "/bba-guru-pd" ;;
    signoff)                 echo "(user signoff — no next agent)" ;;
    arch-needs-fix)          echo "/bba-architect" ;;
    rtl-needs-fix)           echo "/bba-guru-rtl" ;;
    synth-needs-fix)         echo "/bba-guru-synthesis" ;;
    escalate-user)           echo "(escalate-user — manual decision)" ;;
    pd-rework)               echo "/bba-guru-pd" ;;
    pd-needs-fix)            echo "/bba-guru-pd" ;;
    *)                       echo "(unknown label: $1)" ;;
  esac
}

# Try PostToolUse mode: read stdin JSON, only fire when the written file is a handoff
INPUT="$(cat 2>/dev/null || true)"
if [ -n "${INPUT:-}" ]; then
  TARGET="$(printf '%s' "$INPUT" | python3 -c \
    'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
  if [ -n "${TARGET:-}" ]; then
    case "$TARGET" in
      *designs/*/.handoff/*.md)
        label="$(basename "$TARGET" .md)"
        next="$(label_to_next "$label")"
        printf '[pipeline-advance] %s → %s\n' "$TARGET" "$next" >&2
        exit 0 ;;
      *) exit 0 ;;  # not a handoff write — stay silent
    esac
  fi
fi

# Manual mode: scan all
shopt -s nullglob globstar
for f in designs/**/.handoff/*.md; do
  label="$(basename "$f" .md)"
  next="$(label_to_next "$label")"
  printf '[pipeline-advance] %s → %s\n' "$f" "$next"
done
