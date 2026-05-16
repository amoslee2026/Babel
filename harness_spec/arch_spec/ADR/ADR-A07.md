---
id: ADR-A07
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H9, M11
extends: ADR-002
---

# ADR-A07 — Agent 命名 = 单 Token

## Status
Accepted (2026-05-16)

## Context
ADR-002 决定 agent ID 简化为 `babel-{name}` 单 token，但 v1.1 design_doc 中 Phase 3 / coordinator agent 仍三 token（如 `babel-yosys-synth-planner`、`babel-clock-domain-guard`、`babel-cross-domain-coordinator`），与 ADR-002 自相矛盾。

## Decision
全文统一 rename 至单 token：

| Before (v1.1) | After (arch_spec) | M-ID |
|---------------|---------------------|------|
| babel-spec-planner | **babel-spec** | M001 |
| babel-rtl-coder | **babel-rtl** | M002 |
| babel-test-architect | **babel-test** | M003 |
| babel-cross-domain-coordinator | **babel-coord** | M004 |
| babel-yosys-synth-planner | **babel-synth** | M005 |
| babel-clock-domain-guard | **babel-cdc** | M006 |

## Trade-offs
| 维度 | 三 token 描述性 | 单 token 简洁 |
|------|---------------|-------------|
| 命令行输入 | 长 | 短 |
| 日志可读性 | 长 | 短 |
| 与 wiki/CBB 命名一致 | 不一致 | 一致 |
| 描述清晰度 | 高 | 由 description 字段补充 |
| **选择** | ❌ | ✅ |

## Consequences
- (+) `/babel-design`, `/babel-respond` 命令短
- (+) 与 design_doc Mermaid 图、event.kind enum 一致
- (-) v1.1 idea 文档需要在下次更新时 sync（暂不强求，因 idea 已冻结）
- (-) 单 token 失去 "describes flow ownership" 暗示；由 description 字段补救

## Affected
- `functional_specification.md` (M-ID references)
- `architecture_specification.md` §2 所有 agent yaml
- `data_flow_diagrams.md` / `workflow_diagrams.md` 节点 ID
- `schemas_seed.md` event.agent enum
- Phase 1 实施：agent yaml 文件名

## Supersedes
扩展 ADR-002（v1.1 决策落地到所有 agent）
