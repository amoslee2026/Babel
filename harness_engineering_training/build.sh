#!/usr/bin/env bash
# build.sh — 把 chapters/ + appendices/ 拼接成 harness-engineering-training.md 全文版
#
# 用法：
#   ./build.sh          # 重新生成全文版
#
# 文件顺序：
#   _preamble.md → 00..11 → 99-references.md → A → B
#
# 修改章节请编辑 chapters/<NN>-*.md，然后跑 ./build.sh

set -euo pipefail

cd "$(dirname "$0")"

OUT="harness-engineering-training.md"
TMP="${OUT}.tmp"

# 顺序：preamble → 章节（按文件名排序）→ References → Appendix A → Appendix B
{
    cat chapters/_preamble.md
    echo

    for f in $(ls chapters/[0-9]*.md | sort); do
        cat "$f"
        echo
        echo "---"
        echo
    done

    cat appendices/A-glossary.md
    echo
    echo "---"
    echo

    cat appendices/B-ask-claude.md
} > "$TMP"

# 移除连续多余空行（>2 → 2）
awk '
    /^$/ { blank++; next }
    {
        for (i = 0; i < (blank > 2 ? 2 : blank); i++) print ""
        blank = 0
        print
    }
    END {
        for (i = 0; i < (blank > 2 ? 2 : blank); i++) print ""
    }
' "$TMP" > "$OUT"
rm "$TMP"

LINES=$(wc -l < "$OUT")
SIZE=$(du -h "$OUT" | cut -f1)
MERMAID=$(grep -c '^```mermaid$' "$OUT" || true)
CHS=$(grep -c '^## 第 ' "$OUT" || true)

echo "✓ Built $OUT"
echo "  Lines:    $LINES"
echo "  Size:     $SIZE"
echo "  Chapters: $CHS"
echo "  Mermaid:  $MERMAID blocks"
