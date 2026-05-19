---
name: bb-gate-pd-quality
description: "PD signoff 质量门禁：DRC 0 violation + LVS match + post-PD timing 所有 corner WNS≥0 + GDSII 文件存在。通过即完成 signoff。触发场景：(1) bba-guru-pd 完成 GDS export；(2) 显式 /bb-gate-pd-quality。"
---

# bb-gate-pd-quality

## 职责

校验 DRC / LVS / post-PD multi-corner STA / GDS 四项，全 pass 才标记 signoff。

- 调用者：`bba-guru-pd`
- 上游：`bb-invoke-magic`(drc)、`bb-invoke-netgen`、`bb-invoke-opensta`(post_pd)、`bb-invoke-klayout`(export)
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| drc_report | path | true | — | `designs/<name>/pd/drc_report.txt` 或 magic JSON |
| lvs_report | path | true | — | `designs/<name>/pd/lvs_report.txt` 或 netgen JSON |
| timing_signoff | path | true | — | `designs/<name>/pd/timing_signoff.json` |
| gds_path | path | true | — | `designs/<name>/gdsii/<name>.gds` |
| design_name | string | true | — | — |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/pd/quality_gate_<stamp>.json` |
| `drc_violations` | int |
| `drc_clean` | bool |
| `lvs_match` | bool |
| `timing_corners` | `[{corner,wns_ns,met:bool}]` |
| `timing_all_met` | bool |
| `gds_exists` | bool |
| `gds_size_bytes` | int |
| `pass` | bool（四项全过） |
| `valid` | bool |

## 4-Phase 执行

### Phase 1 — render_gate_py

```python
# 1. 解析 drc_report → violations count
# 2. 解析 lvs_report → match
# 3. 读 timing_signoff.json：all(c.wns >= 0)
# 4. os.path.exists(gds_path) && size > 0
```

### Phase 2 — run_gate

`timeout 180 uv run python <script_path> > <log> 2>&1`

### Phase 3 — parse_gate

`scripts/parse_gate.py`：合并四项布尔 → `pass`，输出 timing_corners 详表。

### Phase 4 — return

返回 JSON。`pass=true` → 写 `pd_report.json` + 开 `signoff` issue。

## 通过标准

| 项 | 条件 |
|----|------|
| drc_clean | violations == 0 |
| lvs_match | `Circuits match uniquely` |
| timing_all_met | 所有 corner WNS ≥ 0 |
| gds_exists | size > 0 |

## 资源索引

- `scripts/render_gate_py.py`、`scripts/run_gate.py`、`scripts/parse_gate.py`
- `references/asap7_corner_signoff_list.md`
