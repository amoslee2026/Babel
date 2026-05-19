#!/usr/bin/env bash
# bb-hook-pipeline-advance.sh — v1.3 MVP
#
# PostToolUse hook on Write/Edit: when the just-written file is a handoff
# (designs/*/.handoff/<label>.md), emit the suggested next slash command.
# Falls back to scanning the whole tree when invoked manually (no stdin JSON).
#
# v1.3 MVP scope: notification only — NO auto-dispatch (Claude Code hooks
# cannot invoke Skill/Agent). A future v1.4 hook may auto-spawn next agent.

set -eu

label_to_next() {
  case "$1" in
    ready-for-rtl)           echo "/bb-guru-rtl" ;;
    ready-for-verification)  echo "/bb-guru-verification" ;;
    ready-for-synth)         echo "/bb-guru-synthesis" ;;
    ready-for-pd)            echo "/bb-guru-pd" ;;
    signoff)                 echo "(user signoff — no next agent)" ;;
    arch-needs-fix)          echo "/bb-architect" ;;
    rtl-needs-fix)           echo "/bb-guru-rtl" ;;
    synth-needs-fix)         echo "/bb-guru-synthesis" ;;
    escalate-user)           echo "(escalate-user — manual decision)" ;;
    pd-rework)               echo "/bb-guru-pd" ;;
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
