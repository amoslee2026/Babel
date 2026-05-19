#!/usr/bin/env bash
# bb-hook-validate-input-schema.sh — v1.3 MVP (BLOCKING)
#
# Triggered by UserPromptSubmit when user invokes /bb-guru-* slash command
# (registered in .claude/settings.json). Also callable directly as:
#   ./bb-hook-validate-input-schema.sh <agent> <design>
#
# Validates upstream artifact JSON against schema in .claude/schemas/.
# Blocks (exit 2) on schema fail and writes <upstream>-needs-fix handoff.

set -eu

AGENT="${1:-}"
DESIGN="${2:-}"
if [ -z "$AGENT" ] || [ -z "$DESIGN" ]; then
  INPUT="$(cat 2>/dev/null || true)"
  if [ -n "${INPUT:-}" ]; then
    PROMPT="$(printf '%s' "$INPUT" | python3 -c \
      'import sys,json; d=json.load(sys.stdin); print(d.get("prompt",""))' 2>/dev/null || echo "")"
    AGENT="$(printf '%s' "$PROMPT" | sed -nE 's|^/(bb-guru-[a-z]+)\b.*|\1|p')"
    DESIGN="$(printf '%s' "$PROMPT" | sed -nE 's|.*designs/([a-z0-9_-]+).*|\1|p')"
  fi
fi
[ -z "$AGENT" ] && exit 0
[ -z "$DESIGN" ] && exit 0

case "$AGENT" in
  bb-guru-rtl|bb-guru-verification|bb-guru-synthesis|bb-guru-pd) ;;
  *) exit 0 ;;
esac

declare -A ART SCHEMA UPSTREAM
ART["bb-guru-rtl"]="designs/$DESIGN/mas/mas.json"
ART["bb-guru-verification"]="designs/$DESIGN/rtl_artifact.json"
ART["bb-guru-synthesis"]="designs/$DESIGN/test_report.json"
ART["bb-guru-pd"]="designs/$DESIGN/synth_report.json"

SCHEMA["bb-guru-rtl"]=".claude/schemas/mas.schema.json"
SCHEMA["bb-guru-verification"]=".claude/schemas/rtl_artifact.schema.json"
SCHEMA["bb-guru-synthesis"]=".claude/schemas/test_report.schema.json"
SCHEMA["bb-guru-pd"]=".claude/schemas/synth_report.schema.json"

UPSTREAM["bb-guru-rtl"]="arch"
UPSTREAM["bb-guru-verification"]="rtl"
UPSTREAM["bb-guru-synthesis"]="rtl"
UPSTREAM["bb-guru-pd"]="synth"

A="${ART[$AGENT]}"
S="${SCHEMA[$AGENT]}"
U="${UPSTREAM[$AGENT]}"

[ -f "$A" ] || exit 0   # missing artifact → let agent itself report

if [ ! -f "$S" ]; then
  echo "⚠️  validate-input-schema: schema $S not found, skipping" >&2
  exit 0
fi

if ! uv run python -c "
import sys,json
from jsonschema import validate, ValidationError
try:
  validate(json.load(open('$A')), json.load(open('$S')))
except ValidationError as e:
  print(f'SCHEMA_FAIL: {e.message} (path: {list(e.path)})', file=sys.stderr); sys.exit(1)
" 2>&1; then
  mkdir -p "designs/$DESIGN/.handoff"
  cat > "designs/$DESIGN/.handoff/${U}-needs-fix.md" <<EOF
# ${U}-needs-fix
- timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
- artifact: $A
- schema: $S
- reason: schema validation failed
- triggered_by: bb-hook-validate-input-schema (agent=$AGENT)
EOF
  cat >&2 <<EOF
❌ AGENT_START_BLOCKED: input schema invalid
    artifact: $A
    schema:   $S
    handoff:  designs/$DESIGN/.handoff/${U}-needs-fix.md
EOF
  exit 2
fi

exit 0
