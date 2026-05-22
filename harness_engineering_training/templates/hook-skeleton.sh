#!/usr/bin/env bash
# <hook-name>.sh — <one-line purpose>
#
# Event: <SessionStart | UserPromptSubmit | PreToolUse | PostToolUse | Stop | SessionEnd | ...>
# Matcher: <tool name / regex>
# Decision: <allow | deny | annotate | inject-context>
# Failure mode: <fail-soft warning | fail-loud block>
#
# stdin 收到的 JSON 字段（典型）：
#   .session_id     str
#   .cwd            str
#   .hook_event_name str
#   .tool_name      str       (仅 PreToolUse/PostToolUse)
#   .tool_input     object    (仅 PreToolUse/PostToolUse)
#   .tool_response  object    (仅 PostToolUse)
#   .agent_type     str       (sub-agent 内触发时)

set -eu  # 注意：不加 -o pipefail，避免 jq 提前关闭管道误报失败

# ── 1. 读 stdin ────────────────────────────────────────────────
INPUT="$(cat || true)"
[ -z "${INPUT:-}" ] && exit 0   # 手动调用（无 stdin）就静默退出

# ── 2. 提字段（python3 比 jq 更通用，因为系统不一定有 jq） ──
extract() {
  printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('$1', '') if '.' not in '$1' else
          # 简单嵌套：'tool_input.command'
          (lambda *ks: __import__('functools').reduce(
              lambda acc,k: acc.get(k, {}) if isinstance(acc, dict) else {},
              ks, d) or '')(*'$1'.split('.')))
except Exception:
    print('')
" 2>/dev/null || true
}

TOOL="$(extract tool_name)"
CMD="$(extract tool_input.command)"
TARGET="$(extract tool_input.file_path)"

# ── 3. 决策逻辑（按事件填充） ─────────────────────────────────

# 例 A: PreToolUse 阻断危险命令
# if echo "$CMD" | grep -qE 'rm[[:space:]]+-rf'; then
#   # 硬阻断：输出 JSON 决策到 stdout
#   python3 -c 'import json; print(json.dumps({
#     "hookSpecificOutput": {
#       "hookEventName": "PreToolUse",
#       "permissionDecision": "deny",
#       "permissionDecisionReason": "rm -rf blocked by hook"
#     }
#   }))'
#   exit 0
# fi

# 例 B: PreToolUse 软警告（不阻断）
# if echo "$CMD" | grep -qE 'sudo|chmod 777'; then
#   echo "⚠️  WARNING: dangerous pattern detected, proceeding anyway" >&2
#   exit 0
# fi

# 例 C: PostToolUse 自动 format
# if [ -n "$TARGET" ] && [[ "$TARGET" == *.sv ]]; then
#   verible-verilog-format --inplace "$TARGET" 2>&1 >&2 || true
# fi

# 例 D: SessionStart 注入上下文（stdout 内容会被加入对话）
# git status --short
# echo "---"
# echo "Active design: $(cat designs/.active 2>/dev/null || echo none)"

# ── 4. 默认通过 ───────────────────────────────────────────────
exit 0
