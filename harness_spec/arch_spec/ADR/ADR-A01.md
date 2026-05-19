---
id: ADR-A01
status: Accepted (v2)
date: 2026-05-16
resolves: 入口设计
---

# ADR-A01 — `/bb-design` Slash Command 实现

## Status
Accepted (2026-05-16, arch_spec v2)

## Context
Babel 需要用户入口；v1 设想 Python CLI / shell wrapper / slash command 三选项。
v1.3 design_doc §11.1 已明确"/bb-design"形式（与原 v1.2 一致）。本 ADR 落地实施细节。

## Decision
入口为 Claude Code **slash command**：`/bb-design <design_name> "<prompt>"`，配套 `/bb-respond <design_name> --action {retry|abort|manual-fix|continue}`。

实现位置：
- `commands/bb-design.md`（启动 bb-architect + 拉起 pipeline）
- `commands/bb-respond.md`（处理 escalate-user 响应）
- `commands/bb-pipeline.md`（可选：手动触发下一 stage）

## Trade-offs
| 维度 | Python CLI | **Slash command** | Shell wrapper |
|------|-----------|-------------------|---------------|
| 与 Claude Code 集成 | 需独立 sub agent 启动 | **原生 session** | 需 wrap |
| 用户上下文打通 | 无 | **有（session 共享）** | 部分 |
| 安装成本 | pip | **复制 commands/** | shell + cc |
| `/help` 自动发现 | 无 | **有** | 无 |
| **选择** | ❌ | ✅ | ❌ |

## Consequences
- (+) 用户无需安装额外包；只需复制 commands/ 目录
- (+) Session 状态 / env / claude-mem / prompt 全部贯通
- (+) `/help` 自动列出 bb-* 命令
- (-) 必须在 Claude Code session 内运行（不能裸 shell）
- (-) Slash command 用 markdown 描述，调试相比 Python 麻烦

## Affected
- `user_manual.md` §2
- `architecture_specification.md` M001 trigger
- Phase 1 实施：`commands/bb-design.md` / `commands/bb-respond.md`
