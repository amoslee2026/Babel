---
id: ADR-A07
status: Accepted (v2 重写)
date: 2026-05-16
resolves: Agent 命名一致性
extends: project ADR-002
---

# ADR-A07 — Agent 命名收敛（bb-architect / bb-guru-{flow}）

## Status
Accepted (2026-05-16, arch_spec v2)

## Context
v1 arch_spec ADR-A07 主张 agent 单 token（`babel-coord` / `babel-synth` 等）。
v1.2/v1.3 调整：
- top-level architect 不需要 flow 修饰 → `bb-architect`
- flow owner 用 guru pattern → `bb-guru-{flow}`
- coord 取消（ADR-012）

## Decision
| Agent | 名称 | 角色 |
|-------|------|------|
| M001 | `bb-architect` | top-level architect（无 guru） |
| M002 | `bb-guru-rtl` | flow owner |
| M003 | `bb-guru-verification` | flow owner |
| M004 | `bb-guru-synthesis` | flow owner |
| M005 | `bb-guru-pd` | flow owner |
| (future) | `bb-guru-formal` / `bb-guru-power` / `bb-guru-dft` / `bb-guru-integration` | future flow owners |

Skill：`bb-{action}-{target}`（Babel 原生）或 `ic-{name}`（外部复用，ADR-014）。

## Trade-offs
| 维度 | v1 单 token (bb-rtl) | **v2 guru pattern (bb-guru-rtl)** |
|------|---------------------|----------------------------------|
| 简洁性 | ✅ 更短 | 稍长 |
| 角色暗示 | 弱 | **强（guru = flow owner）** |
| 与 ic-* 区分 | 模糊 | **明显（guru vs action）** |
| 扩展 future agent | 一致 | **更一致（bb-guru-formal 等）** |
| **选择** | ❌ | ✅ |

## Consequences
- (+) 角色清晰；用户一眼看出 flow owner
- (+) bb-architect 单独命名突出顶层职责
- (+) Future agent 添加自然
- (-) 名称略长（`bb-guru-verification` 17 char）

## Affected
- `architecture_specification.md` §2 所有 agent
- `data_flow_diagrams.md` / `workflow_diagrams.md`
- `schemas_seed.md` agent enum
- Phase 1 实施：agent yaml 文件名

## Supersedes
v1 arch_spec ADR-A07（单 token 方案）
