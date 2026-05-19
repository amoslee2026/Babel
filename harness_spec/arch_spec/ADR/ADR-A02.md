---
id: ADR-A02
status: Accepted (v2)
date: 2026-05-16
resolves: Schema 规范
---

# ADR-A02 — Schema 标准、位置与演进规则

## Status
Accepted (2026-05-16, arch_spec v2)

## Context
v1.3 design_doc 引用 8 个 schema (idea / mas / rtl_artifact / test_report / synth_report / pd_report / design_summary / issue_body)。Phase 1 需要明确实施基线。

## Decision
1. **标准**: JSON Schema Draft 2020-12
2. **位置**: `harness_spec/arch_spec/schemas/*.schema.json`
3. **字段骨架**: 见 `schemas_seed.md`（v2）
4. **版本化**: 每 schema `$id` 含 `babel://schemas/<name>`；演进通过 schema 内 `format_version` 字段（v1.3 base = "1.0"）
5. **校验工具**: python `jsonschema` CLI（M201 wrapper）
6. **样例**: 每 schema ≥ 1 valid + ≥ 1 invalid (`schemas/sample_<name>_<n>.json`)
7. **跨引用**: 使用 `$ref: babel://schemas/<other>#/properties/...` 内部解析；Phase 1 测试 jsonschema 实现支持

## Trade-offs
| 维度 | JSON Schema | YAML 内部规范 | Protobuf |
|------|------------|---------------|----------|
| 工具生态 | 强 | 弱 | 强（RPC 偏向） |
| LLM 训练兼容 | 强 | 中 | 弱（二进制） |
| 演进 | 成熟 | 自研 | proto2/3 严格 |
| **选择** | ✅ | ❌ | ❌ |

## Consequences
- (+) Phase 1 接手者有具体字段骨架
- (+) jsonschema CLI 通用工具链
- (-) $ref 跨文件解析需要 Phase 1 测试不同实现兼容性

## Affected
- `schemas_seed.md` 完整骨架
- M201 schema_validator
- Phase 1 DoD: 8 schema + sample 互验通过
