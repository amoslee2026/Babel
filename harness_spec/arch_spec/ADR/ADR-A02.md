---
id: ADR-A02
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H2
---

# ADR-A02 — Schema 规范、版本与位置

## Status
Accepted (2026-05-16)

## Context
v1.1-issue H2：design_doc.md 引用 7+ schema 但全部 "TBD Phase 1"，无字段骨架。Phase 1 无落地起点。

## Decision
1. Schema 标准：**JSON Schema Draft 2020-12**
2. 位置：`harness_spec/arch_spec/schemas/*.schema.json`
3. 字段骨架：见 `schemas_seed.md`（本 arch_spec 阶段输出）
4. 版本化：每 schema 内 `$id` 含 `babel://schemas/<name>`，演进通过 `format_version` 字段（不是 $schema $id）
5. 校验工具：python `jsonschema` CLI（M201 wrapper）
6. 样例：每 schema 配 ≥1 valid + ≥1 invalid sample (`schemas/sample_*.json`)
7. 数量：10 个 schema（idea / spec / rtl_artifact / cdc_report / synth_input / synth_report / test_report / event / design_state / fix_request）

## Trade-offs
| 维度 | JSON Schema | YAML Schema (内部) | Protobuf |
|------|------------|---------------------|----------|
| 工具生态 | 强（python/JS/Go 全套） | 弱 | 强但偏 RPC |
| 与 LLM agent 兼容 | LLM 训练数据多 | 中等 | 低（二进制） |
| 演进策略 | 较成熟 | 自行设计 | proto2/3 兼容规则严格 |
| **选择** | ✅ | ❌ | ❌ |

## Consequences
- (+) Phase 1 接手者有具体字段骨架，无歧义
- (+) jsonschema CLI 通用工具链，无需自研
- (-) JSON Schema $ref 跨文件解析在某些 jsonschema 实现中需配置；Phase 1 验证可行性

## Affected
- `harness_spec/arch_spec/schemas_seed.md`（完整字段骨架）
- M201 schema_validator（包装 jsonschema CLI）
- Phase 1 DoD：7+ schema 通过 jsonschema CLI + sample 互验
