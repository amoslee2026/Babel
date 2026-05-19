---
id: ADR-A08
status: Accepted (v2，沿用 v1)
date: 2026-05-16
resolves: Skill 单向依赖
---

# ADR-A08 — Skill 单向依赖 CI 强制

## Status
Accepted (2026-05-16, arch_spec v2)

## Context
project ADR-009 + ADR-013 要求 skill 不调用 Agent / 不嵌套 Skill。需要技术强制。

## Decision
1. **Skill frontmatter 强制字段**: `forbidden_tools: [Task, Agent, Skill]`
2. **CI 脚本** `scripts/check_skill_purity.py`:
   - 扫描 `skills/**/*.md`
   - 检测违反: 缺失 forbidden_tools / bash 含 `claude -p` / `Skill:` 嵌套引用
   - 任何违反 → CI 红灯
3. **Runtime hook** `bb-hook-skill-purity`（PreToolUse Skill）:
   - 拦截 skill 内的 Task / Agent / Skill 调用 → 错误退出
4. **Phase 1 DoD**: skill purity check 通过

## Trade-offs
| 维度 | 仅文档 | **frontmatter + CI** | runtime sandbox |
|------|--------|---------------------|-----------------|
| 防开发者错误 | ❌ | ✅ | ✅ |
| 实施成本 | 0 | 低 | 高 (container) |
| 误判率 | n/a | 低 | 极低 |
| 与 ADR-010 一致 | ✅ | ✅ | ❌ (引入 sandbox) |
| **选择** | (已淘汰) | ✅ | (overkill) |

## Consequences
- (+) Skill 不能间接触发 agent
- (+) CI 统一约束
- (-) 合法的"helper skill"模式被禁；未来如需再开 ADR
- (-) 模式匹配可被刻意混淆（ADR-010 已明确不防恶意 agent）

## Affected
- M201 schema_validator + bb-hook-skill-purity
- Phase 1 实施 `scripts/check_skill_purity.py`
