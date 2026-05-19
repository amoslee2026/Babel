---
name: bb-challenge-code
description: "通用对抗性代码/文档评审，按可选角色 ruthless/linus/balanced 输出犀利质询。供任何 agent 在重大改动前压力测试。触发场景：(1) agent 自评；(2) 用户显式 /bb-challenge-code。"
---

# bb-challenge-code

## 职责

对 `target_path` 做角色化对抗评审，找潜在缺陷，输出 markdown report + severity 摘要。

- 调用者：所有 bb-* agent + 用户
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| target_path | path | true | — | 文件或目录 |
| role | enum | false | `balanced` | `ruthless` \| `linus` \| `balanced` |
| focus | string | false | — | 关注领域（`timing` / `security` / `maintainability`） |
| design_name | string | false | — | 用于产物路径 |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/review/challenge_<stamp>.md` |
| `role` | str |
| `issues_found` | int |
| `severity_summary` | `{critical,high,medium,low}` |
| `valid` | bool |

## 4-Phase 执行

### Phase 1 — build_prompt

```python
ROLE_PROMPTS = {
  "ruthless": "Ruthless reviewer. Find EVERY flaw. No compliments.",
  "linus":    "Linus Torvalds. Direct, no-nonsense, technically harsh.",
  "balanced": "Senior engineer. Constructive, acknowledge strengths.",
}
content = read(target_path)
prompt = build(ROLE_PROMPTS[role], focus, content)
```

### Phase 2 — run_review

`claude --print "<prompt>" > <artifact_path>` 或 agent 内部直接生成。

### Phase 3 — parse_severity

`scripts/parse_severity.py` 扫描产出 markdown 中 `[CRITICAL] / [HIGH] / [MEDIUM] / [LOW]` 标签 → 计数。

### Phase 4 — return

返回 JSON。调用方据 severity 决定后续动作。

## 角色

| 角色 | 风格 | 适用 |
|------|------|------|
| `ruthless` | 无赞美只挑刺 | 重大改动前压力测试 |
| `linus` | 直接尖锐技术导向 | 风格/架构决策 |
| `balanced` | 承认优点+建议 | 常规评审 |

## 与专用评审 skill 的区别（M-07 边界明示）

| Skill | 定位 | 强制 | 评审维度 |
|-------|------|------|----------|
| `bb-challenge-code` | **用户级 ad-hoc 工具**，任意目标（代码/文档/spec），用户主动调 | 否（无 pipeline 阻断） | 通用对抗，按 `role` 风格变化 |
| `bb-code-review`    | RTL pipeline 强制环节，bb-guru-rtl 在 lint 后自动调，pass=false 阻断 | 是（自动阻断 bb-rtl-coder） | RTL 专用：timing / maintainability / synthesis / MAS-alignment |
| `bb-spec-review`    | Spec pipeline 强制环节，bb-architect 在 MAS frozen 前自动调，pass=false 阻断 | 是（自动阻断 frozen） | 规格专用：consistency / feasibility / coverage |

简言之：
- 用户/agent 想做开放式对抗 → `bb-challenge-code`
- pipeline 强制 RTL review → `bb-code-review`
- pipeline 强制 spec review → `bb-spec-review`

## 资源索引

- `scripts/build_prompt.py`、`scripts/run_review.py`、`scripts/parse_severity.py`
- `references/role_personas.md` — 三角色详细提示词
