#!/usr/bin/env bash
# bb-hook-validate-bash-cmd.sh — v1.4 (fail-closed on truly-dangerous patterns)
#
# PreToolUse hook on Bash. Two severity tiers:
#   BLOCK (exit 2): unambiguous destructive patterns (curl|sh, reverse shell,
#                   dd|mkfs on block devices, > /etc/passwd).
#   WARN  (exit 0, stderr): suspicious but possibly-intentional patterns
#                   (rm -rf, sudo, chmod 777). These proceed but the user
#                   sees a loud warning in the transcript.
#
# Secret stripping (D8-05 / S16): before logging, Bearer tokens, Authorization
# headers, token= query params, and password= literals are redacted.
#
# Limitations: regex-only, still bypassable by `$IFS`, quote-splitting,
# base64-pipe-to-sh, or env-var obfuscation. The REAL security boundary is
# the permission allow-list in settings.local.json; this hook is defense in
# depth for the cases that do get through.

set -euo pipefail
. "$(dirname "$0")/lib/common.sh"

# Anchor to project root
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
fi

INPUT="$(cat 2>/dev/null || true)"
[ -z "${INPUT:-}" ] && exit 0

CMD="$(printf '%s' "$INPUT" | python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    pass
" 2>/dev/null || true)"

[ -z "${CMD:-}" ] && exit 0

# Two tiers of patterns
BLOCK_PATTERNS=(
  'curl[^|]*\|[[:space:]]*(ba)?sh'
  'wget[^|]*\|[[:space:]]*(ba)?sh'
  'bash[[:space:]]+-i[^>]*>&[[:space:]]*/dev/tcp/'
  'nc[[:space:]]+-[a-z]*l'
  'mkfs\.[a-z0-9]+[[:space:]]+/dev/'
  'dd[[:space:]]+if=[^[:space:]]+[[:space:]]+of=/dev/[a-z]+'
  '>[[:space:]]*/etc/passwd'
  '>[[:space:]]*/etc/shadow'
  'chmod[[:space:]]+[0-7]*777[[:space:]]+/'
)
BLOCK_NAMES=(
  "curl|sh download-execute"
  "wget|sh download-execute"
  "bash reverse shell"
  "nc -l reverse shell"
  "mkfs on /dev/*"
  "dd overwrite block device"
  "> /etc/passwd"
  "> /etc/shadow"
  "chmod 777 / (recursive root)"
)

WARN_PATTERNS=(
  'rm[[:space:]]+-rf[[:space:]]+/'
  'rm[[:space:]]+-rf[[:space:]]+~'
  '\bsudo\b'
  'chmod[[:space:]]+777'
  '>[[:space:]]*/etc/'
  '~/\.ssh/'
  '~/\.aws/'
  '>.*~/\.claude/settings'
  'eval[[:space:]]+.*\$\('
)
WARN_NAMES=(
  "rm -rf / (root wipe)"
  "rm -rf ~ (home wipe)"
  "sudo (privilege escalation)"
  "chmod 777 (world-writable)"
  "> /etc/* (system config overwrite)"
  "~/.ssh/ access"
  "~/.aws/ access"
  "overwrite ~/.claude/settings"
  "eval with command substitution"
)

# Strip secrets before ANY logging
STRIPPED="$(printf '%s' "$CMD" | sed -E \
  -e 's|(Authorization:[[:space:]]*)(Bearer[[:space:]]+)[^[:space:]]+|\1\2***REDACTED***|gi' \
  -e 's|(token=)[^[:space:]&]+|\1***REDACTED***|gi' \
  -e 's|(password=)[^[:space:]&]+|\1***REDACTED***|gi' \
  -e 's|(api_?key=)[^[:space:]&]+|\1***REDACTED***|gi' \
  -e 's|(secret=)[^[:space:]&]+|\1***REDACTED***|gi' \
  -e 's|(sk-[a-zA-Z0-9]{20,})|***REDACTED***|g' \
)"
STRIPPED_SHORT="$(printf '%s' "$STRIPPED" | head -c 300)"

# Check BLOCK tier first
for i in "${!BLOCK_PATTERNS[@]}"; do
  if printf '%s' "$CMD" | grep -Eq "${BLOCK_PATTERNS[$i]}"; then
    printf "🛑 BASH_CMD_BLOCKED: %s\n    Command: %s\n    This pattern is unconditionally blocked (see ADR-A10).\n    If this is intentional, use a wrapper script under .claude/scripts/.\n" \
      "${BLOCK_NAMES[$i]}" "$STRIPPED_SHORT" >&2
    exit 2
  fi
done

# Recoverability ban (project rule): hard-block irrecoverable file deletion.
# Catches common literal forms of rm, git reset, and git checkout -- (file restore).
RECOVERABILITY_PATTERNS=(
  '(^|[[:space:];|&])(/bin/)?rm\b'
  '(^|[[:space:];|&])git[[:space:]]+reset\b'
  'git[[:space:]]+checkout[[:space:]].*[[:space:]]--[[:space:]]'
  'git[[:space:]]+checkout[[:space:]]+--[[:space:]]'
)
for p in "${RECOVERABILITY_PATTERNS[@]}"; do
  if printf '%s' "$CMD" | grep -Eq "$p"; then
    printf "🛑 BLOCKED: rm/git reset/git checkout -- are forbidden (irrecoverable). Use mv to ./temp/deleted/ instead.\n    Command: %s\n" \
      "$STRIPPED_SHORT" >&2
    exit 2
  fi
done

# Check WARN tier
hit=""
for i in "${!WARN_PATTERNS[@]}"; do
  if printf '%s' "$CMD" | grep -Eq "${WARN_PATTERNS[$i]}"; then
    hit="${hit}    - ${WARN_NAMES[$i]}\n"
  fi
done

if [ -n "${hit:-}" ]; then
  printf "⚠️  BASH_CMD_WARNING: Suspicious patterns (proceeds)\n    Command: %s\n%b    Review carefully.\n" \
    "$STRIPPED_SHORT" "$hit" >&2
fi

exit 0
