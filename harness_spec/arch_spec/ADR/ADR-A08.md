---
id: ADR-A08
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H10
extends: ADR-009
---

# ADR-A08 — Skill 单向依赖强制机制

## Status
Accepted (2026-05-16)

## Context
ADR-009 声明 "skill 不允许调用 Agent 工具或派发 subagent，保持单向依赖 agent→skill"，但 v1.1 无强制机制：skill 是 markdown + bash，可隐式 `claude -p` 调用 agent。需要技术强制。

## Decision
1. **Skill frontmatter 强制字段**：
   ```yaml
   forbidden_tools: [Task, Agent, Skill]
   ```
2. **Runtime hook** `babel-hook-skill-purity`（CI 模式）：
   - PreToolUse 拦截 skill 内的 Task / Agent / Skill 调用 → 阻断 + 错误
   - PostToolUse 扫描 skill stdout 含 `claude -p` 等模式 → 警告
3. **CI 脚本** `scripts/check_skill_purity.py`：
   - 扫描 `skills/**/*.md`
   - 检测违反模式：缺失 forbidden_tools / bash 含 `claude -p` / `Skill:` 嵌套
   - 任何违反 → CI 红灯
4. Phase 1 DoD 增条：skill purity check 通过

## Trade-offs
| 维度 | 仅文档声明 | frontmatter + CI | 运行时 sandboxing |
|------|-----------|-----------------|------------------|
| 防御开发者错误 | ❌ | ✅ | ✅ |
| 实施成本 | 0 | 低（python 脚本） | 高（container） |
| 误判率 | n/a | 低（明确模式） | 极低 |
| 与 ADR-010 一致 | ✅ | ✅ | ❌ (引入 sandbox) |
| **选择** | (已淘汰) | ✅ | (over-engineering) |

## Consequences
- (+) Skill 不能间接触发 agent，避免循环依赖
- (+) CI 一致性，所有新 skill 自动 enforced
- (-) 合法的 "skill 内调用 helper skill" 用例被禁止；如果未来需要，再开 ADR 评估
- (-) 检测靠模式匹配，可被刻意混淆（同 ADR-010 威胁模型：信任开发者）

## Affected
- `architecture_specification.md` M201 schema_validator + babel-hook-skill-purity
- Phase 1 实施：`scripts/check_skill_purity.py`、所有 skill frontmatter 加 `forbidden_tools`
