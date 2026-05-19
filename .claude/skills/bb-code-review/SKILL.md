---
name: bb-code-review
description: "对抗性代码评审：代码质量 / 可维护性 / 时序风险 / 综合友好度 / MAS 对齐度。默认 ruthless 模式，找 EVERY flaw。触发场景：(1) RTL lint 后；(2) 显式 /bb-code-review。"
---

# bb-code-review

## 职责

读 RTL + MAS，对照设计意图做对抗评审，分维度给出 issues + severity + pass 判定。

- 调用者：`bb-rtl-coder`、用户
- 前置：`bb-check-lint`（lint 通过后）
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| rtl_dir | path | true | — | `designs/<name>/rtl/` |
| file_list | path | true | — | `file_list.f` |
| mas_path | path | true | — | `designs/<name>/mas/mas.json` |
| role | enum | false | `ruthless` | `ruthless` \| `linus` \| `balanced` |
| focus | string | false | `timing,maintainability` | 关注领域 |
| design_name | string | true | — | — |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/rtl/code_review_<stamp>.md` |
| `issues_found` | int |
| `severity_summary` | `{critical,high,medium,low}` |
| `timing_risks` | list[str] |
| `maintainability_issues` | list[str] |
| `synthesis_friendly` | bool |
| `mas_alignment` | `full` \| `partial` \| `none` |
| `pass` | bool（critical==0 && high≤1） |
| `valid` | bool |

## 角色

| 角色 | 风格 | 适用 |
|------|------|------|
| `ruthless` | 无赞美只挑刺，找 EVERY flaw | **默认**，重大改动前压力测试 |
| `linus` | 直接尖锐，技术导向 | 风格/架构决策 |
| `balanced` | 承认优点+建议 | 常规评审 |

## 4-Phase 执行

### Phase 1 — build_review_prompt

`scripts/build_prompt.py`：

```python
ROLE_PROMPTS = {
  "ruthless": "Ruthless reviewer. Find EVERY flaw. No compliments.",
  "linus":    "Linus Torvalds. Direct, no-nonsense, technically harsh.",
  "balanced": "Senior engineer. Constructive, acknowledge strengths.",
}

mas = json.load(open(mas_path))
rtl = {f: open(f).read() for f in cat(file_list)}
prompt = render_prompt(
    role=role,
    rtl=rtl,
    mas=mas,
    dimensions=["timing","maintainability","synthesis","mas_alignment"]
)
```

### Phase 2 — run_review

`claude --print "<prompt>" > <artifact_path>` 或 agent 内部生成。

### Phase 3 — parse_review

`scripts/parse_review.py`：

- 提取 dimensions 段（`## Timing Risks` / `## Maintainability` 等）
- 计数 severity 标签 `[CRITICAL] / [HIGH] / [MEDIUM] / [LOW]`
- `pass = (critical == 0 && high <= 1)`

### Phase 4 — return

返回 JSON。`pass=false` → bb-rtl-coder 反馈重生成（≤3 iter）。

## 维度

| 维度 | 检查 |
|------|------|
| timing_risks | 长组合路径 / 无 pipeline / CDC 未处理 |
| maintainability | 深嵌套 / 大模块 / 命名 |
| synthesis_friendly | 非综合语法 / blackbox |
| mas_alignment | RTL ↔ MAS FSM/datapath 一致性 |

## 通过标准

| 级别 | 通过 |
|------|------|
| critical | == 0 |
| high | ≤ 1 |

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| pass=true | 写 rtl_artifact.json + 进下一阶段 |
| pass=false & iter<3 | 反馈 bb-rtl-coder 重生成 |
| iter≥3 | 开 `arch-needs-fix` |

## 资源索引

- `scripts/build_prompt.py`、`scripts/run_review.py`、`scripts/parse_review.py`
- `references/rtl_review_dimensions.md`
- `references/role_personas.md` — 三角色详细提示词

**项目级 Coding Style 参考**：
- `wiki/codingstyle/systemverilog_styleguide.md` — SystemVerilog Style Guide (systemverilog.io)
- `wiki/codingstyle/freescale_verilog_standard.md` — Freescale Verilog HDL Coding Standard SRS V3.2