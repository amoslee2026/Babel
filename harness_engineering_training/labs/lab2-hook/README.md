# Lab 2: 写一个 Hook — 综合阶段冻结 RTL

> **目标**：用 PreToolUse hook 防止 `bba-guru-synthesis` 这个 sub-agent 直接修改 `designs/*/rtl/*.sv`——RTL 在综合阶段必须由上游 `bba-guru-rtl` 通过 `rtl-needs-fix` 反弹机制修改。
>
> **预计时长**：45 分钟
>
> **学到什么**：
> - PreToolUse hook 的 stdin JSON 结构
> - 如何精准 deny 一类操作（matcher + 脚本判断双重过滤）
> - hook 决策返回 JSON 的格式
> - 如何用 `agent_type` 字段做条件判断
> - 区分 fail-soft（警告）与 fail-loud（阻断）

## 前置

- 已读主报告第 2.2 节（Hook 概念）
- 已熟悉 `.claude/settings.json` 中 hooks 块的格式

## Step 1: 看清楚为什么需要这个 hook

Babel 流水线：

```
bba-guru-rtl ──► bba-guru-verification ──► bba-guru-synthesis ──► bba-guru-pd
```

`bba-guru-synthesis` 收到 `ready-for-synth` handoff 时，RTL 已经"冻结"——它的工作是写 SDC、跑 yosys、跑 STA。如果它顺手改了 RTL：

- 没经过 verification 验证 → 引入 bug
- 没更新 mas.json → 上下游 sha256 失配
- 没走 issue protocol → review 链断了

**这正是 hook 该兜的底**。frontmatter 的 `tools: [...]` 字段只能管"能不能用某个 tool"，管不了"对哪个路径用"。

## Step 2: 写 hook 脚本

新建 `.claude/hooks/bb-hook-synthesis-rtl-freeze.sh`：

```bash
#!/usr/bin/env bash
# bb-hook-synthesis-rtl-freeze.sh — 防止 bba-guru-synthesis 修改 RTL
#
# Event:   PreToolUse
# Matcher: Write|Edit
# Decision: deny if (agent_type == bba-guru-synthesis) AND (file is RTL)
# Failure: fail-loud (硬阻断 + 解释如何走正确路径)

set -eu

INPUT="$(cat || true)"
[ -z "${INPUT:-}" ] && exit 0

# 提取字段
read -r TARGET AGENT <<< "$(
  printf '%s' "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
target = d.get('tool_input', {}).get('file_path', '')
agent  = d.get('agent_type', '')
print(target, agent)
" 2>/dev/null || echo " "
)"

# 不在 bba-guru-synthesis 上下文就放行
[ "$AGENT" != "bba-guru-synthesis" ] && exit 0

# 不是 RTL 文件就放行
case "$TARGET" in
  *designs/*/rtl/*.sv|*designs/*/rtl/*.svh|*designs/*/rtl/*.v)
    ;;
  *) exit 0 ;;
esac

# 命中——硬阻断
python3 -c '
import json, sys
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": (
      "RTL is frozen at synthesis stage. "
      "bba-guru-synthesis must NOT modify RTL files directly. "
      "Bounce back to bba-guru-rtl via rtl-needs-fix issue. "
      "Use: bb-create-issue --label rtl-needs-fix --artifact " + "'"$TARGET"'"
    )
  }
}))
'
exit 0
```

赋权：

```bash
chmod +x .claude/hooks/bb-hook-synthesis-rtl-freeze.sh
```

## Step 3: 注册到 settings.json

编辑 `.claude/settings.json`，在 `PreToolUse.Write|Edit` 组里加一行：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {"type": "command", "command": ".claude/hooks/bb-hook-write-arch-freeze-check.sh"},
          {"type": "command", "command": ".claude/hooks/bb-hook-instantiate-cbb-search.sh"},
          {"type": "command", "command": ".claude/hooks/bb-hook-synthesis-rtl-freeze.sh"}
        ]
      }
    ]
  }
}
```

## Step 4: 测试

启动 `bba-guru-synthesis` agent：

```
/bba-guru-synthesis designs/foo
```

让它"试图"写 RTL：

```
（在子 agent 内手工触发）
请帮我修改 designs/foo/rtl/top.sv 的端口列表
```

期望结果：
- Write tool 调用被阻断
- 错误信息提示走 `rtl-needs-fix` 路径
- agent 自动转向开 issue 而不是硬改文件

## Step 5: 验证 false positive

确认正常操作不受影响：

1. 主代理（非 sub-agent）写 RTL → 应放行（agent_type 为空，第一个 `[ "$AGENT" != ... ] && exit 0` 命中）
2. `bba-guru-synthesis` 写 SDC → 应放行（路径不是 *.sv）
3. `bba-guru-rtl` 写 RTL → 应放行（agent_type 不匹配）
4. `bba-guru-synthesis` 跑 Bash → 应放行（matcher 是 Write|Edit，没匹配）

## Step 6: 进阶——加日志

调试 hook 时最痛苦的是"被静默放行"。给脚本加一行 stderr 日志：

```bash
echo "[synthesis-rtl-freeze] agent=$AGENT target=$TARGET → $([ "$AGENT" = "bba-guru-synthesis" ] && [[ "$TARGET" == *rtl/*.sv* ]] && echo DENY || echo ALLOW)" >&2
```

放在 `exit 0` 之前。这样每次匹配都会留下痕迹，用户看 session 时一眼看到 hook 在工作。

## 反思问题

1. 为什么不直接在 `bba-guru-synthesis.md` 的 `disallowedTools` 加 `Write` 就行？
   <details><summary>参考答案</summary>
   过于粗暴。`bba-guru-synthesis` 需要写 SDC、写综合报告、写 handoff。完全禁 Write 它就跑不了。Hook 提供了"按路径条件 deny"的精细度，frontmatter 字段没有这个能力。
   </details>

2. 这个 hook 用 fail-loud（硬 deny），如果改为 fail-soft（warning + 放行）会有什么后果？
   <details><summary>参考答案</summary>
   RTL 会被偷改、sha256 失配、下游 verification 会跑过期 RTL……整个流水线信任链断裂。这种"明确错误且不可挽回"的场景必须硬阻断。fail-soft 适用于"也许有合理理由"的场景（如 `sudo` 在 dev VM 里可能合法）。
   </details>

3. 如果团队里有人不喜欢这个限制，怎么提供一个"豁免开关"？
   <details><summary>参考答案</summary>
   读环境变量：`[ "${BB_ALLOW_SYNTH_RTL_WRITE:-0}" = "1" ] && exit 0`。在脚本顶部加上。这样豁免要显式 `export`，不会无意中关掉。比删除 hook 安全得多。
   </details>
