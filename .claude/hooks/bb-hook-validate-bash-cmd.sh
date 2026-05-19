#!/usr/bin/env bash
# bb-hook-validate-bash-cmd.sh — v1.3 MVP (fail-soft)
#
# PreToolUse hook on Bash. Warn (non-blocking) on dangerous patterns.
# Per ADR-A10 soft-boundary: trust user judgment, surface risk.

set -eu

INPUT="$(cat || true)"
CMD="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))' 2>/dev/null || true)"

[ -z "${CMD:-}" ] && exit 0

PATTERNS=(
  'rm[[:space:]]+-rf'
  '\bsudo\b'
  'chmod[[:space:]]+777'
  '>[[:space:]]*/etc/'
  '~/\.ssh/'
  '~/\.aws/'
  '>[[:space:]]*~/\.claude/settings'
  'mkfs\.'
  'dd[[:space:]]+if='
  'curl.*\|[[:space:]]*(ba)?sh'
  'wget.*\|[[:space:]]*(ba)?sh'
  '\bnc\b.*-l'
  'bash[[:space:]]+-i.*>&[[:space:]]*/dev/tcp/'
  'eval[[:space:]]+.*\$\('
)

hit=""
for p in "${PATTERNS[@]}"; do
  if printf '%s' "$CMD" | grep -Eq "$p"; then
    hit="${hit}    - $p\n"
  fi
done

if [ -n "${hit:-}" ]; then
  printf "⚠️  BASH_CMD_WARNING: Dangerous patterns detected\n    Command: %s\n%b    fail-soft (ADR-A10): command will proceed.\n    Review carefully.\n" \
    "$CMD" "$hit" >&2
fi

exit 0
