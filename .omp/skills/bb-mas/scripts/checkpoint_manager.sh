#!/bin/bash
# checkpoint_manager.sh - 管理 MAS 文档生成 checkpoint

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 <command> <impl_spec_dir> [options]"
    echo ""
    echo "Commands:"
    echo "  create <phase>   创建 checkpoint"
    echo "  check            检查最新 checkpoint"
    echo "  list             列出所有 checkpoint"
    echo "  restore          恢复到最新 checkpoint"
    echo "  clear            清除所有 checkpoint"
    echo ""
    echo "Options:"
    echo "  --phase <num>    指定阶段编号 (1-5)"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

COMMAND="$1"
IMPL_SPEC_DIR="$2"
CHECKPOINT_DIR="$IMPL_SPEC_DIR/.checkpoint"

# 验证目录存在
if [[ ! -d "$IMPL_SPEC_DIR" ]]; then
    echo "Error: Directory not found: $IMPL_SPEC_DIR"
    exit 1
fi

# 创建 checkpoint 目录
mkdir -p "$CHECKPOINT_DIR"

create_checkpoint() {
    local phase="$1"
    local timestamp=$(date -u +%Y%m%dT%H%M%SZ)
    local checkpoint_file="$CHECKPOINT_DIR/phase_${phase}.done"

    # 检查是否已存在
    if [[ -f "$checkpoint_file" ]]; then
        echo "Warning: Phase $phase checkpoint already exists"
        echo "Overwriting..."
    fi

    # 创建 checkpoint 文件
    cat > "$checkpoint_file" <<EOF
phase: $phase
timestamp: $timestamp
status: complete
modules_completed: $(find "$IMPL_SPEC_DIR" -type d -name "M*" | wc -l)
docs_completed: $(find "$IMPL_SPEC_DIR" -name "*.md" -path "*/M*" -exec grep -l "^status: complete$" {} \; 2>/dev/null | wc -l)
EOF

    # 创建备份目录
    local backup_dir="$CHECKPOINT_DIR/backup_${phase}_${timestamp}"
    mkdir -p "$backup_dir"

    # 备份当前状态
    find "$IMPL_SPEC_DIR" -name "*.md" -path "*/M*" | while read file; do
        relative_path=$(realpath --relative-to="$IMPL_SPEC_DIR" "$file")
        mkdir -p "$backup_dir/$(dirname "$relative_path")"
        cp "$file" "$backup_dir/$relative_path"
    done

    echo "✓ Created checkpoint for Phase $phase at $timestamp"
    echo "  Backup stored in: $backup_dir"
}

check_checkpoint() {
    local latest_phase=0

    for phase in 5 4 3 2 1; do
        if [[ -f "$CHECKPOINT_DIR/phase_${phase}.done" ]]; then
            latest_phase=$phase
            break
        fi
    done

    if [[ $latest_phase -eq 0 ]]; then
        echo "No checkpoints found"
        echo "Status: Starting from Phase 1"
        return 1
    fi

    echo "Latest checkpoint: Phase $latest_phase"
    cat "$CHECKPOINT_DIR/phase_${latest_phase}.done"

    if [[ $latest_phase -eq 5 ]]; then
        echo ""
        echo "Status: ✓ All phases completed"
    else
        echo ""
        echo "Status: Resume from Phase $((latest_phase + 1))"
    fi
}

list_checkpoints() {
    echo "All checkpoints:"
    echo ""

    for phase in 1 2 3 4 5; do
        local checkpoint_file="$CHECKPOINT_DIR/phase_${phase}.done"
        if [[ -f "$checkpoint_file" ]]; then
            echo "Phase $phase:"
            cat "$checkpoint_file"
            echo ""
        else
            echo "Phase $phase: Not completed"
            echo ""
        fi
    done

    # 列出备份
    echo "Backup directories:"
    ls -la "$CHECKPOINT_DIR" | grep "^d" | grep "backup_" || echo "  No backups"
}

restore_checkpoint() {
    local latest_phase=0

    for phase in 5 4 3 2 1; do
        if [[ -f "$CHECKPOINT_DIR/phase_${phase}.done" ]]; then
            latest_phase=$phase
            break
        fi
    done

    if [[ $latest_phase -eq 0 ]]; then
        echo "No checkpoint to restore"
        exit 1
    fi

    # 获取最新备份目录
    local backup_dir=$(ls -dt "$CHECKPOINT_DIR"/backup_${latest_phase}_* 2>/dev/null | head -1)

    if [[ -z "$backup_dir" ]]; then
        echo "Error: No backup found for Phase $latest_phase"
        exit 1
    fi

    echo "Restoring from: $backup_dir"

    # 恢复文件
    find "$backup_dir" -name "*.md" | while read file; do
        relative_path=$(realpath --relative-to="$backup_dir" "$file")
        target_file="$IMPL_SPEC_DIR/$relative_path"
        mkdir -p "$(dirname "$target_file")"
        cp "$file" "$target_file"
    done

    echo "✓ Restored to Phase $latest_phase state"
}

clear_checkpoints() {
    echo "Clearing all checkpoints..."

    # 删除 checkpoint 文件
    rm -f "$CHECKPOINT_DIR"/phase_*.done

    # 删除备份目录
    rm -rf "$CHECKPOINT_DIR"/backup_*

    echo "✓ All checkpoints cleared"
}

# 执行命令
case "$COMMAND" in
    create)
        if [[ $# -lt 3 ]]; then
            echo "Error: Phase number required"
            usage
        fi
        create_checkpoint "$3"
    ;;
    check)
        check_checkpoint
    ;;
    list)
        list_checkpoints
    ;;
    restore)
        restore_checkpoint
    ;;
    clear)
        clear_checkpoints
    ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
    ;;
esac