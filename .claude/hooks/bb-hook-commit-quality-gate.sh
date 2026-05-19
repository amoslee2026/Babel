#!/usr/bin/env bash
# bb-hook-commit-quality-gate.sh — v1.3 MVP (BLOCKING)
#
# PreToolUse hook on Bash for `git commit`. If RTL/synth files changed,
# require the corresponding designs/<name>/{rtl,synth}/quality_gate_*.json
# to exist with pass=true (scoped per affected design — fix M-13).
# Block commit on failure. User can bypass via `git commit --no-verify`.

set -eu

INPUT="$(cat || true)"
CMD="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))' 2>/dev/null || true)"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Branch filter: only feature/* and dev/*
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
case "$BRANCH" in
  feature/*|dev/*) ;;
  *) exit 0 ;;
esac

CHANGED="$(git diff --cached --name-only 2>/dev/null || true)"

block_msg=""
needs_rtl=0; needs_synth=0
while IFS= read -r f; do
  case "$f" in
    designs/*/rtl/*) needs_rtl=1 ;;
    designs/*/synth/*) needs_synth=1 ;;
  esac
done <<< "$CHANGED"

# M-13 fix: scope gate check to the SPECIFIC designs touched by this commit,
# not "any design's latest quality_gate_*.json".
check_pass() {
  local stage="$1"
  local designs_changed
  designs_changed="$(printf '%s\n' "$CHANGED" | sed -nE 's|^designs/([^/]+)/.*|\1|p' | sort -u)"
  for n in $designs_changed; do
    local found_pass=0
    for d in designs/"$n"/"$stage"/quality_gate_*.json; do
      [ -f "$d" ] || continue
      if python3 -c "import json,sys; sys.exit(0 if json.load(open('$d')).get('pass') else 1)"; then
        found_pass=1
        break
      fi
    done
    if [ $found_pass -eq 0 ]; then
      block_msg="${block_msg}❌ design '$n' $stage quality gate NOT passing.\n"
    fi
  done
}

[ $needs_rtl   -eq 1 ] && check_pass "rtl"   || true
[ $needs_synth -eq 1 ] && check_pass "synth" || true

if [ -n "${block_msg}" ]; then
  printf "%b" "❌ COMMIT_BLOCKED: Quality gate failed\n$block_msg    Fix issues before commit, or use --no-verify (NOT recommended).\n" >&2
  exit 2
fi

exit 0
