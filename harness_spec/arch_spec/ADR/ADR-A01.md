---
id: ADR-A01
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H1
---

# ADR-A01 — Babel CLI 入口 = Claude Code Slash Command

## Status
Accepted (2026-05-16)

## Context
v1.1-issue H1：design_doc.md §11.1 出现 `babel design uart "..."` 暗示存在独立 CLI，但全文未定义入口形态。可选方案：
- (A) 独立 python CLI 二进制（`pip install babel-chip`）
- (B) Claude Code slash command (`/babel-design`)
- (C) Wrapper shell 脚本

## Decision
采用 **(B) Claude Code slash command**：`/babel-design <design_name> "<prompt>"`，配套 `/babel-respond <design_name> --action <...>`。

实现位置：`commands/babel-design.md` + `commands/babel-respond.md`，Phase 1 实施。

## Trade-offs

| 维度 | (A) Python CLI | (B) Slash command | (C) Shell wrapper |
|------|---------------|-------------------|-------------------|
| 与 Claude Code 集成 | 需手工启动 sub agent | 原生 | 需 wrap claude code 调用 |
| 用户已有上下文 | 无（独立进程） | 共享 Claude Code session | 部分 |
| 安装复杂度 | pip + venv | 单文件复制 | shell + claude code |
| Discoverability | 需 README | `/help` 自动列出 | 需文档 |
| **选择** | ❌ | ✅ | ❌ |

## Consequences
- (+) 用户无需安装 babel 包；只需 commands/ 目录
- (+) 与 Claude Code session 状态打通（claude-mem、env、user prompt）
- (+) `/help` 自动展示 babel 命令
- (-) 用户必须使用 Claude Code（不能跑在普通 shell）
- (-) 命令分发逻辑写在 markdown 里，定位 bug 略困难

## Alternatives Considered
| 方案 | 放弃理由 |
|------|---------|
| (A) Python CLI | 重复造与 Claude Code 集成层；维护负担高 |
| (C) Shell wrapper | 等于 (A) 的轻量版，但仍需独立工具链 |

## Affected
- `harness_spec/arch_spec/user_manual.md` §2
- `harness_spec/arch_spec/architecture_specification.md` M001 trigger
- Phase 1 实施：`commands/babel-design.md`, `commands/babel-respond.md`
