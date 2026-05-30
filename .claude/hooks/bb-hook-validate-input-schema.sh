#!/usr/bin/env bash
# bb-hook-validate-input-schema.sh — v1.3 MVP (BLOCKING)
#
# Triggered by UserPromptSubmit when user invokes /bb-guru-* slash command
# (registered in .claude/settings.json). Also callable directly as:
#   ./bb-hook-validate-input-schema.sh <agent> <design>
#
# Validates upstream artifact JSON against schema in .claude/schemas/.
# Blocks (exit 2) on schema fail and writes <upstream>-needs-fix handoff.

set -euo pipefail

# Anchor to project root (D3-04: hooks must not depend on CWD)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi

# Fail-CLOSED if jsonschema is missing (D8-06 / X-11). Previously fail-soft,
# which silently disabled the ONLY layer between upstream JSON and renderers.
# Install: uv add --dev jsonschema
if ! uv run python -c "import jsonschema" >/dev/null 2>&1; then
  cat >&2 <<'EOF'
❌ validate-input-schema BLOCKED: python package 'jsonschema' not importable.
   The upstream-artifact → renderer chain depends on schema validation.
   Fix: `uv add --dev jsonschema` (or `uv pip install jsonschema`).
   Until fixed, /bb-guru-* slash commands are BLOCKED to prevent
   schema-laundered injection (D8-06).
EOF
  exit 2
fi

. "$(dirname "$0")/lib/common.sh"

AGENT="${1:-}"
DESIGN="${2:-}"
if [ -z "$AGENT" ] || [ -z "$DESIGN" ]; then
  INPUT="$(cat 2>/dev/null || true)"
  if [ -n "${INPUT:-}" ]; then
    PROMPT="$(printf '%s' "$INPUT" | python3 -c \
      'import sys,json; d=json.load(sys.stdin); print(d.get("prompt",""))' 2>/dev/null || echo "")"
    AGENT="$(printf '%s' "$PROMPT" | sed -nE 's|^/(bb-guru-[a-z]+)\b.*|\1|p')"
    DESIGN="$(printf '%s' "$PROMPT" | sed -nE 's|.*designs/([a-zA-Z0-9_-]+).*|\1|p')"
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

if [ ! -f "$A" ]; then
  # Missing artifact: fail-CLOSED with a clear handoff message (D3-05)
  mkdir -p "designs/$DESIGN/.handoff"
  cat > "designs/$DESIGN/.handoff/${U}-needs-fix.md" <<EOF
# ${U}-needs-fix
- timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
- artifact: $A (MISSING)
- schema: $S
- reason: upstream artifact not present; agent must produce it before /bb-guru-* proceeds.
- triggered_by: bb-hook-validate-input-schema (agent=$AGENT)
EOF
  cat >&2 <<EOF
❌ AGENT_START_BLOCKED: upstream artifact missing
    artifact: $A
    handoff:  designs/$DESIGN/.handoff/${U}-needs-fix.md
EOF
  exit 2
fi

if [ ! -f "$S" ]; then
  echo "⚠️  validate-input-schema: schema $S not found; skipping (no schema to enforce)" >&2
  exit 0
fi

# Size cap on artifact (D8-14: prevent 5 GB JSON DoSing the hook)
ART_SIZE=$(stat -c%s "$A" 2>/dev/null || stat -f%z "$A" 2>/dev/null || echo 0)
if [ "$ART_SIZE" -gt 10485760 ]; then
  echo "❌ validate-input-schema BLOCKED: artifact $A is ${ART_SIZE} bytes (>10MB cap)" >&2
  exit 2
fi

if ! ARTIFACT="$A" SCHEMA="$S" uv run python -c "
import sys, json, os
from jsonschema import validate, ValidationError
try:
    artifact = json.load(open(os.environ['ARTIFACT']))
    schema = json.load(open(os.environ['SCHEMA']))
    validate(artifact, schema)
    sys.exit(0)
except ValidationError as e:
    print(f'schema mismatch: {e.message}', file=sys.stderr)
    sys.exit(2)
except Exception as e:
    print(f'schema check error: {e}', file=sys.stderr)
    sys.exit(2)
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
