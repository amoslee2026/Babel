#!/bin/bash
# analyze_spec.sh - 分析 MAS 文档质量

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <impl_spec_dir> [options]"
    echo ""
    echo "Options:"
    echo "  --fix          自动修复格式问题"
    echo "  --report       输出详细报告"
    echo "  --json         输出 JSON 格式"
    exit 1
}

# 参数解析
FIX_MODE=false
REPORT_MODE=false
JSON_OUTPUT=false
IMPL_SPEC_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
        ;;
        --report)
            REPORT_MODE=true
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

# 验证目录
if [[ ! -d "$IMPL_SPEC_DIR" ]]; then
    echo -e "${RED}Error: Directory not found: $IMPL_SPEC_DIR${NC}"
    exit 1
fi

# 检查函数
check_frontmatter() {
    local file="$1"
    local issues=""

    # 检查 YAML frontmatter
    if ! head -1 "$file" | grep -q "^---$"; then
        issues+="missing_frontmatter_start;"
    fi

    if ! grep -q "^---$" "$file" | head -2 | tail -1; then
        issues+="missing_frontmatter_end;"
    fi

    # 检查必需字段
    if ! grep -q "^module:" "$file"; then
        issues+="missing_module;"
    fi

    if ! grep -q "^type:" "$file"; then
        issues+="missing_type;"
    fi

    if ! grep -q "^status:" "$file"; then
        issues+="missing_status;"
    fi

    # 检查 status 值
    local status=$(grep "^status:" "$file" | cut -d: -f2 | tr -d ' ')
    if [[ "$status" != "complete" && "$status" != "pending" ]]; then
        issues+="invalid_status_value;"
    fi

    return $([[ -z "$issues" ]] && echo 0 || echo 1)
}

check_section_quality() {
    local file="$1"
    local doc_type=$(grep "^type:" "$file" | cut -d: -f2 | tr -d ' ')
    local issues=""

    case "$doc_type" in
        MAS)
            # MAS 特定检查
            if grep -q "\[具体\]" "$file" || grep -q "\[边界值\]" "$file"; then
                issues+="placeholder_values;"
            fi
            if ! grep -q "## 2\. 接口定义" "$file"; then
                issues+="missing_interface_section;"
            fi
            if ! grep -q "## 3\. 数据通路" "$file"; then
                issues+="missing_datapath_section;"
            fi
            ;;
        FSM)
            # FSM 特定检查
            if ! grep -q "stateDiagram" "$file"; then
                issues+="missing_mermaid_diagram;"
            fi
            if ! grep -q "| 当前状态" "$file"; then
                issues+="missing_transition_table;"
            fi
            ;;
        datapath)
            if ! grep -q "graph TB" "$file" && ! grep -q "graph LR" "$file"; then
                issues+="missing_block_diagram;"
            fi
            ;;
        verification)
            if ! grep -q "assert property" "$file"; then
                issues+="missing_assertion;"
            fi
            if ! grep -q "coverpoint" "$file"; then
                issues+="missing_coverage;"
            fi
            ;;
        DFT)
            if ! grep -q "扫描链" "$file" && ! grep -q "Scan Chain" "$file"; then
                issues+="missing_scan_chain;"
            fi
            ;;
    esac

    return $([[ -z "$issues" ]] && echo 0 || echo 1)
}

check_chiplet_specific() {
    local file="$1"
    local issues=""

    # 检查是否标记为 D2D/CDC/PWR
    if grep -q "@D2D" "$file" || grep -q "chiplet_features:.*D2D" "$file"; then
        # D2D 模块需要特定章节
        if ! grep -q "D2D 接口" "$file"; then
            issues+="missing_d2d_section;"
        fi
        if ! grep -q "UCIe\|BoW\|AIB" "$file"; then
            issues+="missing_d2d_protocol;"
        fi
    fi

    if grep -q "@CDC" "$file" || grep -q "chiplet_features:.*CDC" "$file"; then
        if ! grep -q "CDC" "$file"; then
            issues+="missing_cdc_section;"
        fi
    fi

    return $([[ -z "$issues" ]] && echo 0 || echo 1)
}

# 收集所有文档
docs=$(find "$IMPL_SPEC_DIR" -name "*.md" -path "*/M*" 2>/dev/null)

total_docs=0
issues_count=0
issues_list=""

for doc in $docs; do
    total_docs=$((total_docs + 1))

    doc_issues=""

    # 检查 frontmatter
    if ! check_frontmatter "$doc"; then
        doc_issues+="frontmatter_issue;"
    fi

    # 检查章节质量
    if ! check_section_quality "$doc"; then
        doc_issues+="quality_issue;"
    fi

    # 检查 Chiplet 特定
    if ! check_chiplet_specific "$doc"; then
        doc_issues+="chiplet_issue;"
    fi

    if [[ -n "$doc_issues" ]]; then
        issues_count=$((issues_count + 1))
        issues_list+="$doc|$doc_issues\n"

        # 自动修复模式
        if [[ "$FIX_MODE" == "true" ]]; then
            echo -e "${YELLOW}Fixing: $doc${NC}"

            # 修复 status 格式
            if [[ "$doc_issues" == *"invalid_status_value"* ]]; then
                sed -i 's/^status: 完成$/status: complete/' "$doc"
                sed -i 's/^status: Complete$/status: complete/' "$doc"
            fi
        fi
    fi
done

# 输出报告
if [[ "$JSON_OUTPUT" == "true" ]]; then
    cat <<EOF
{
  "impl_spec_dir": "$IMPL_SPEC_DIR",
  "timestamp": "$(date -u +%Y%m%dT%H%M%SZ)",
  "summary": {
    "total_docs": $total_docs,
    "docs_with_issues": $issues_count,
    "quality_score": $(( (total_docs - issues_count) * 100 / total_docs ))
  },
  "issues": [
$(echo -e "$issues_list" | while IFS='|' read -r doc issues; do
    if [[ -n "$doc" ]]; then
        echo "    {\"file\": \"$doc\", \"issues\": \"$issues\"},"
    fi
done)
  ]
}
EOF
else
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    ic.mas Quality Report${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "目录: ${YELLOW}$IMPL_SPEC_DIR${NC}"
    echo -e "时间: $(date -u +%Y%m%dT%H%M%SZ)"
    echo ""

    quality_score=$(( (total_docs - issues_count) * 100 / total_docs ))

    echo -e "${GREEN}质量分数: ${quality_score}%${NC}"
    echo -e "总文档数: $total_docs"
    echo -e "问题文档: $issues_count"
    echo ""

    if [[ "$REPORT_MODE" == "true" && -n "$issues_list" ]]; then
        echo -e "${RED}问题详情:${NC}"
        echo -e "$issues_list" | while IFS='|' read -r doc issues; do
            if [[ -n "$doc" ]]; then
                module=$(basename "$(dirname "$doc")")
                filename=$(basename "$doc")
                echo -e "  ${YELLOW}$module/$filename${NC}"
                echo "    Issues: $issues"
            fi
        done
    fi

    echo -e "${BLUE}========================================${NC}"
fi

# 返回状态码
if [[ $quality_score -ge 80 ]]; then
    exit 0  # 高质量
elif [[ $quality_score -ge 50 ]]; then
    exit 0  # 中等质量
else
    exit 1  # 需改进
fi