#!/usr/bin/env bash
# validate-wiki.sh — v1.3 MVP stub (fail-soft)
#
# PreToolUse hook on Read for wiki/** paths. Warn (non-blocking) if the
# file's frontmatter `content_hash` differs from the value recorded in
# wiki/.hashes.txt (format: <relpath> <sha256>).

set -eu

INPUT="$(cat || true)"
TARGET="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
[ -z "${TARGET:-}" ] && exit 0

# Only check wiki/** paths.
case "$TARGET" in
  *wiki/*) ;;
  *) exit 0 ;;
esac
[ -f "$TARGET" ] || exit 0

# Pull content_hash from frontmatter (between first two `---` fences).
FM_HASH="$(awk '/^---$/{c++; next} c==1{print}' "$TARGET" \
  | sed -nE 's/^content_hash:[[:space:]]*([A-Fa-f0-9]+).*/\1/p' | head -1)"

[ -z "${FM_HASH:-}" ] && exit 0   # No hash declared → skip

REL="${TARGET#./}"
HASHES_FILE="wiki/.hashes.txt"
[ -f "$HASHES_FILE" ] || exit 0
EXPECTED="$(awk -v p="$REL" '$1==p {print $2}' "$HASHES_FILE")"
[ -z "${EXPECTED:-}" ] && exit 0

if [ "$FM_HASH" != "$EXPECTED" ]; then
  cat >&2 <<EOF
⚠️  WIKI_HASH_WARNING: Content hash mismatch
    File: $TARGET
    Frontmatter: $FM_HASH
    Expected:    $EXPECTED  ($HASHES_FILE)
    Wiki content may be modified/outdated. Verify before trusting.
EOF
fi

exit 0
