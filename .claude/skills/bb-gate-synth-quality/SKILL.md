---
name: bb-gate-synth-quality
description: "综合质量门禁：WNS≥0 + Area<baseline×1.2 + CDC clean。通过才允许 ready-for-pd。触发场景：(1) bba-guru-synthesis 跑完 yosys+opensta；(2) 显式 /bb-gate-synth-quality。"
---

# bb-gate-synth-quality

## 职责

合并 STA / area / CDC 三项 → pass 判定。

- 调用者：`bba-guru-synthesis`
- 上游：`bb-invoke-opensta`、`bb-invoke-yosys`、`bb-check-cdc`
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| synth_report | path | true | — | `designs/<name>/synth/synth_report.json`（含 wns/area） |
| cdc_report | path | true | — | `designs/<name>/cdc/cdc_report.json` |
| baseline_area | float | false | — | 基线面积（um²），未给则跳过 area check |
| area_margin | float | false | `1.2` | area ≤ baseline × margin |
| design_name | string | true | — | — |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/synth/quality_gate_<stamp>.json` |
| `wns_ns` | float |
| `timing_met` | bool |
| `area_um2` | float |
| `area_baseline` | float\|null |
| `area_ratio` | float\|null |
| `area_met` | bool |
| `cdc_clean` | bool |
| `pass` | bool |
| `valid` | bool |

## 4-Phase 执行

### Phase 1 — render_gate_py

```python
synth = json.load(open(synth_report))
cdc = json.load(open(cdc_report))
# timing_met = (wns >= 0)
# area_met = baseline 缺 or area <= baseline*area_margin
# cdc_clean = cdc.clean
```

### Phase 2 — run_gate

`timeout 180 uv run python <script_path> > <log> 2>&1`

### Phase 3 — parse_gate

`scripts/parse_gate.py`：三项合并；输出 details 失败项。

### Phase 4 — return

返回 JSON。`pass=true` → 开 `ready-for-pd`。

## 通过标准

| 项 | 条件 |
|----|------|
| timing_met | WNS ≥ 0 |
| area_met | area ≤ baseline × 1.2（baseline 存在） |
| cdc_clean | unwaived violation == 0 |

## 资源索引

- `scripts/render_gate_py.py`、`scripts/run_gate.py`、`scripts/parse_gate.py`
