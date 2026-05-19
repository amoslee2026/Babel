---
id: ADR-A04
status: Accepted (v2)
date: 2026-05-16
resolves: claude-mem fallback 实现
extends: project ADR-007
---

# ADR-A04 — claude-mem 不可用时的 Fallback 实现

## Status
Accepted (2026-05-16, arch_spec v2)

## Context
project ADR-007 决定复用 claude-mem 插件。M304 是 Babel 侧 adapter。需要明确：
- 插件 disabled / API error / timeout 时 Babel 行为
- 用户感知方式
- 配置项

## Decision
当 claude-mem 不可用：
1. M304 adapter 检测失败（API 错误 / 超时 / 插件未启用）
2. 返回 `degraded` 状态给上层 hook
3. **不阻断** 主流程（agent 仍能完成本 stage）
4. stderr 输出固定横幅：
   ```
   ⚠ claude-mem unavailable; cross-session memory disabled.
     Continuing in stateless mode. Past design experiences won't be referenced.
   ```
5. 配置项 `babel_config.claude_mem_fallback: stateless | abort`，**默认 stateless**
6. 检测周期：会话启动 + 写 experience 失败 3 次后切换 degraded

## Trade-offs
| 维度 | stateless | abort | retry-forever |
|------|-----------|-------|---------------|
| 设计可完成 | ✅ | ❌ | ❌ (卡死) |
| 用户感知 | ✅ (banner) | ✅ | ❌ |
| 历史经验利用 | ❌ | n/a | ❌ |
| **选择** | ✅ default | (opt-in) | ❌ |

## Consequences
- (+) claude-mem 故障不阻断芯片设计
- (+) 用户明确知晓"无记忆"状态
- (-) Agent 不能从历史失败学习（同类 bug 可能重复）
- (-) `abort` 模式给企业部署留口

## Affected
- M304 claude-mem-adapter
- `data_flow_diagrams.md` §6 fallback 流
- `user_manual.md` §9 Q&A
