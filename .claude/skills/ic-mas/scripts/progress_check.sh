#!/bin/bash
# progress_check.sh - 检查 MAS 文档生成进度

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <impl_spec_dir>"
    echo "Options:"
    echo "  --verbose    显示详细进度"
    echo "  --json       输出 JSON 格式"
    exit 1
}

# 参数解析
VERBOSE=false
JSON_OUTPUT=false
IMPL_SPEC_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
        ;;
        --json)
            JSON_OUTPUT=true
            shift
        ;;
        -*)
            echo "Unknown option: $1"
            usage
        ;;
        *)
            IMPL_SPEC_DIR="$1"
            shift
        ;;
    esac
done

if [[ -z "$IMPL_SPEC_DIR" ]]; then
    usage
fi

# 验证目录存在
if [[ ! -d "$IMPL_SPEC_DIR" ]]; then
    echo -e "${RED}Error: Directory not found: $IMPL_SPEC_DIR${NC}"
    exit 1
fi

# 统计函数
count_files() {
    local pattern="$1"
    find "$IMPL_SPEC_DIR" -name "$pattern" -path "*/M*" 2>/dev/null | wc -l
}

count_complete() {
    local pattern="$1"
    find "$IMPL_SPEC_DIR" -name "$pattern" -path "*/M*" -exec grep -l "^status: complete$" {} \; 2>/dev/null | wc -l
}

# 统计各类文档
MAS_TOTAL=$(count_files "MAS.md")
MAS_COMPLETE=$(count_complete "MAS.md")

FSM_TOTAL=$(count_files "FSM.md")
FSM_COMPLETE=$(count_complete "FSM.md")

DATAPATH_TOTAL=$(count_files "datapath.md")
DATAPATH_COMPLETE=$(count_complete "datapath.md")

VERIF_TOTAL=$(count_files "verification.md")
VERIF_COMPLETE=$(count_complete "verification.md")

DFT_TOTAL=$(count_files "DFT.md")
DFT_COMPLETE=$(count_complete "DFT.md")

TASKS_TOTAL=$(count_files "tasks.md")
TASKS_COMPLETE=$(count_complete "tasks.md")

# 模块统计
MODULE_COUNT=$(find "$IMPL_SPEC_DIR" -type d -name "M*" 2>/dev/null | wc -l)
LEAF_COUNT=$(find "$IMPL_SPEC_DIR" -type d -name "M*" 2>/dev/null | while read dir; do
    if [[ ! -d "$dir/M*" ]]; then
        echo "$dir"
    fi
done | wc -l)

# 总计
TOTAL_DOCS=$((MAS_TOTAL + FSM_TOTAL + DATAPATH_TOTAL + VERIF_TOTAL + DFT_TOTAL + TASKS_TOTAL))
COMPLETE_DOCS=$((MAS_COMPLETE + FSM_COMPLETE + DATAPATH_COMPLETE + VERIF_COMPLETE + DFT_COMPLETE + TASKS_COMPLETE))

# 计算百分比
calculate_progress() {
    local total=$1
    local complete=$2
    if [[ $total -eq 0 ]]; then
        echo "0"
    else
        echo $(( complete * 100 / total ))
    fi
}

MAS_PROGRESS=$(calculate_progress $MAS_TOTAL $MAS_COMPLETE)
FSM_PROGRESS=$(calculate_progress $FSM_TOTAL $FSM_COMPLETE)
DATAPATH_PROGRESS=$(calculate_progress $DATAPATH_TOTAL $DATAPATH_COMPLETE)
VERIF_PROGRESS=$(calculate_progress $VERIF_TOTAL $VERIF_COMPLETE)
DFT_PROGRESS=$(calculate_progress $DFT_TOTAL $DFT_COMPLETE)
TASKS_PROGRESS=$(calculate_progress $TASKS_TOTAL $TASKS_COMPLETE)
OVERALL_PROGRESS=$(calculate_progress $TOTAL_DOCS $COMPLETE_DOCS)

# 输出
if [[ "$JSON_OUTPUT" == "true" ]]; then
    cat <<EOF
{
  "impl_spec_dir": "$IMPL_SPEC_DIR",
  "timestamp": "$(date -u +%Y%m%dT%H%M%SZ)",
  "summary": {
    "module_count": $MODULE_COUNT,
    "leaf_count": $LEAF_COUNT,
    "total_docs": $TOTAL_DOCS,
    "complete_docs": $COMPLETE_DOCS,
    "overall_progress": $OVERALL_PROGRESS
  },
  "details": {
    "MAS": {"total": $MAS_TOTAL, "complete": $MAS_COMPLETE, "progress": $MAS_PROGRESS},
    "FSM": {"total": $FSM_TOTAL, "complete": $FSM_COMPLETE, "progress": $FSM_PROGRESS},
    "datapath": {"total": $DATAPATH_TOTAL, "complete": $DATAPATH_COMPLETE, "progress": $DATAPATH_PROGRESS},
    "verification": {"total": $VERIF_TOTAL, "complete": $VERIF_COMPLETE, "progress": $VERIF_PROGRESS},
    "DFT": {"total": $DFT_TOTAL, "complete": $DFT_COMPLETE, "progress": $DFT_PROGRESS},
    "tasks": {"total": $TASKS_TOTAL, "complete": $TASKS_COMPLETE, "progress": $TASKS_PROGRESS}
  }
}
EOF
else
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    ic.mas Progress Report${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "目录: ${YELLOW}$IMPL_SPEC_DIR${NC}"
    echo -e "时间: $(date -u +%Y%m%dT%H%M%SZ)"
    echo ""
    echo -e "${GREEN}总体进度:${NC}"
    echo -e "  模块数: $MODULE_COUNT (叶子: $LEAF_COUNT)"
    echo -e "  文档数: $COMPLETE_DOCS / $TOTAL_DOCS (${OVERALL_PROGRESS}%)"
    echo ""
    echo -e "${GREEN}各类文档进度:${NC}"

    printf "  %-12s %3d / %3d (%3d%%)\n" "MAS" "$MAS_COMPLETE" "$MAS_TOTAL" "$MAS_PROGRESS"
    printf "  %-12s %3d / %3d (%3d%%)\n" "FSM" "$FSM_COMPLETE" "$FSM_TOTAL" "$FSM_PROGRESS"
    printf "  %-12s %3d / %3d (%3d%%)\n" "datapath" "$DATAPATH_COMPLETE" "$DATAPATH_TOTAL" "$DATAPATH_PROGRESS"
    printf "  %-12s %3d / %3d (%3d%%)\n" "verification" "$VERIF_COMPLETE" "$VERIF_TOTAL" "$VERIF_PROGRESS"
    printf "  %-12s %3d / %3d (%3d%%)\n" "DFT" "$DFT_COMPLETE" "$DFT_TOTAL" "$DFT_PROGRESS"
    printf "  %-12s %3d / %3d (%3d%%)\n" "tasks" "$TASKS_COMPLETE" "$TASKS_TOTAL" "$TASKS_PROGRESS"

    # 详细模式
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo -e "${GREEN}未完成模块:${NC}"
        find "$IMPL_SPEC_DIR" -name "MAS.md" -path "*/M*" ! -exec grep -q "^status: complete$" {} \; -print 2>/dev/null | while read file; do
            module_dir=$(dirname "$file")
            module_name=$(basename "$module_dir")
            echo -e "  ${YELLOW}$module_name${NC}"

            for doc in FSM.md datapath.md verification.md DFT.md tasks.md; do
                if [[ -f "$module_dir/$doc" ]]; then
                    status=$(grep "^status:" "$module_dir/$doc" 2>/dev/null | cut -d: -f2 | tr -d ' ')
                    if [[ "$status" == "complete" ]]; then
                        echo -e "    ${GREEN}✓${NC} $doc"
                    else
                        echo -e "    ${RED}✗${NC} $doc"
                    fi
                else
                    echo -e "    ${RED}✗${NC} $doc (缺失)"
                fi
            done
        done
    fi

    echo ""
    echo -e "${BLUE}========================================${NC}"
fi

# 返回状态码
if [[ $OVERALL_PROGRESS -eq 100 ]]; then
    exit 0  # 完成
elif [[ $OVERALL_PROGRESS -ge 50 ]]; then
    exit 0  # 进行中
else
    exit 1  # 需关注
fi