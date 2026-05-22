---
name: <agent-name-kebab-case>
description: "<一句话角色 + 触发条件>。Trigger: <列出会触发自动委派的关键词或 handoff 标签>。"
tools: ["Read", "Write", "Edit", "Grep", "Bash", "Skill", "TaskCreate", "TaskUpdate", "TaskList"]
# 可选字段（按需）：
# disallowedTools: []
model: inherit              # sonnet | opus | haiku | inherit | 完整 ID
                            # 国产模型示例：通过 LiteLLM 网关后可写
                            #   model: deepseek-v4
color: blue                 # 状态栏颜色（red/green/blue/yellow/magenta/cyan/orange/pink）
# maxTurns: 50
# permissionMode: default   # default | acceptEdits | auto | dontAsk | bypassPermissions | plan
# memory: project           # user | project | local
# skills: ["skill-a", "skill-b"]   # 启动时预加载（完整内容注入）
# mcpServers: ["lsf-server"]
# hooks: {}                  # 仅对本 agent 生效的 hook
# background: false
# isolation: worktree        # 隔离到临时 git worktree
# effort: high               # low | medium | high | xhigh | max
# initialPrompt: ""          # 作为 main agent 启动时的首轮 prompt
---

## Role

<一段简短而权威的"宪法"——告诉 sub-agent 它是谁、不做什么。例：>

You are the **<role-name>**. You consume <input artifact> and produce <output artifact>.
You do NOT <list of out-of-scope actions>.

## Embedded Policies

| Policy | Statement |
|--------|-----------|
| <POLICY_NAME> | <硬规则> |

## Pipeline Position

```
<upstream-agent> ─► [<this-agent>] ─► <downstream-agent>
                       ▲
                       └─ <bounce-label> from downstream
```

## Core Responsibilities

1. <职责 1，单一动词开头>
2. <职责 2>
3. <职责 3>

## IO Contract

| Direction | Artifact | Schema |
|-----------|----------|--------|
| in  | `<input-path>` | `<schema-path>` |
| out | `<output-path>` | `<schema-path>` |

## Workflow

1. <步骤 1>
2. <步骤 2>
3. <步骤 3>

## Convergence / Failure

- `optimization_loop.trigger`: <什么条件触发重试>
- `max_iter`: <N>
- `correlation_id` = `sha256(<failing-artifact-bytes>)`
- On exceeding `max_iter` or `max_global_fix_iter`: invoke *Escalate-user Protocol*

## Escalate-user Protocol

当无法继续时：
1. Stdout 块：
   ```
   ## escalate-user: <context>
   - reason: <one-line root cause>
   - last attempt: <what was tried>
   - blocking field / artifact: <path>
   - suggested next step: <what user must decide>
   ```
2. （可选）开 issue `bb-create-issue --label escalate-user --artifact <path>`
3. 立即返回。

## Acceptance Criteria

在 handoff 之前必须满足：
- [ ] <criterion 1>
- [ ] <criterion 2>

## Skills You Call

| Skill | Purpose | Status |
|-------|---------|--------|
| `<skill-1>` | … | installed |

## Edge Cases

- **<场景 1>**：<处理>
- **<场景 2>**：<处理>

## Output Style

PASS：
```
## <agent> handoff: <context>
- <key metric>: <value>
- Next: <next-label> 已开启
```

FAIL：
```
## <agent> handoff FAIL: <context>
- <错误位置>
- <错误信息>
- Next: 继续重试 / escalate-user
```

## Project Rules

遵守 `.claude/rules/common/coding-style.md`、上级 CLAUDE.md 的规则。
