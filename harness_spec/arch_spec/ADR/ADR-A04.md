---
id: ADR-A04
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H5
extends: ADR-007
---

# ADR-A04 — claude-mem 失败降级 = Stateless + 警告

## Status
Accepted (2026-05-16)

## Context
v1.1-issue H5：ADR-007 决定 Babel 复用 claude-mem 插件，但未定义 claude-mem 失败 / disable / API 错误时 babel 行为。需明确降级路径。

## Decision
当 claude-mem 不可用（plugin disabled / API error / timeout）：
1. **Babel 不阻断**主流程
2. M304 claude-mem-adapter 返回 `degraded` 状态
3. stderr 输出固定格式警告横幅：
   ```
   ⚠ claude-mem unavailable; cross-session memory disabled.
     Continuing in stateless mode. Past design experiences won't be referenced.
   ```
4. 配置项 `babel_config.claude_mem_fallback: stateless | abort`，默认 `stateless`
5. 检测周期：会话启动 + 每次写 experience 失败 3 次

## Trade-offs
| 维度 | stateless 降级 | abort | retry-forever |
|------|---------------|-------|---------------|
| 设计可完成 | ✅ | ❌ | ❌（卡死） |
| 用户感知问题 | ✅ (banner) | ✅ | ❌ |
| 历史经验利用 | ❌ | n/a | ❌ |
| **选择** | ✅ (default) | (opt-in) | ❌ |

## Consequences
- (+) claude-mem 故障不阻断芯片设计交付
- (+) 用户明确知晓"无记忆"状态，可决策是否继续
- (-) agent 不学习历史失败，可能重复同一类 bug
- (-) `abort` 配置项给企业部署留口，但 MVP 不主推

## Affected
- `architecture_specification.md` M304 (fallback)
- `user_manual.md` §9 Q&A claude-mem 错误
- `data_flow_diagrams.md` §5
- `workflow_diagrams.md` §7
