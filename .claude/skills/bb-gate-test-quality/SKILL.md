---
name: bb-gate-test-quality
description: "验证质量门禁（v1.3 加严）：functional 100% + line/branch/toggle 100% + assertions 全 pass。通过才允许 ready-for-synth。触发场景：(1) bba-guru-verification 跑完回归；(2) 显式 /bb-gate-test-quality。"
---

# bb-gate-test-quality

## 职责

读 coverage.json / test_report.json / sim_log，校验所有覆盖率 == 100% 且无断言失败。

- 调用者：`bba-guru-verification`
- 上游：`bb-collect-coverage`、`bb-invoke-verilator`
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| coverage_json | path | true | — | `designs/<name>/coverage.json` |
| test_report | path | true | — | `designs/<name>/test_report.json` |
| sim_log | path | true | — | `designs/<name>/sim_results/<stamp>.log` |
| design_name | string | true | — | — |
| target_pct | float | false | `100.0` | 阈值 |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/verif/quality_gate_<stamp>.json` |
| `functional_coverage` | float |
| `code_coverage` | `{line: float, branch: float, toggle: float}` (NESTED, fix C-01) |
| `assertions_pass` | bool |
| `uncovered_bins` | list |
| `pass` | bool |
| `valid` | bool |

## 4-Phase 执行

### Phase 1 — render_gate_py

```python
import json
tr = json.load(open(test_report))     # 已经是嵌套 schema（fix C-01）
sim = open(sim_log).read()
# 检查 functional_coverage == 100 + code_coverage.{line,branch,toggle} == 100
# + sim_log 中无 'Assertion failed' / '%Error'
```

### Phase 2 — run_gate

`timeout 180 uv run python <script_path> > <log> 2>&1`

### Phase 3 — parse_gate

`scripts/parse_gate.py`：合并五项 → `pass = AND`。

### Phase 4 — return

返回 JSON。`pass=false` → 返回 `uncovered_bins` 让 verification 追加 corner 用例。

## 通过标准（v1.3）

| 项 | 条件 |
|----|------|
| `test_report.functional_coverage` | == 100 |
| `test_report.code_coverage.line` | == 100 |
| `test_report.code_coverage.branch` | == 100 |
| `test_report.code_coverage.toggle` | == 100 |
| `assertions_pass` | true |

## 资源索引

- `scripts/render_gate_py.py`、`scripts/run_gate.py`、`scripts/parse_gate.py`
