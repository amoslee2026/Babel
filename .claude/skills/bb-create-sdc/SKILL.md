---
name: bb-create-sdc
description: "从 MAS（clock_domains / io_timing / path_exceptions）派生 Synopsys SDC 时序约束文件，OpenSTA 语法校验。触发场景：(1) bb-guru-synthesis 综合前；(2) post-PD timing fail 修订约束；(3) 显式 /bb-create-sdc。"
---

# bb-create-sdc

## 职责

按 MAS clock_domains / io_timing / path_exceptions + target_freq 生成 SDC，OpenSTA 解析校验。ADR-016：SDC 来源是 MAS，不从 RTL 推断。

- 调用者：`bb-guru-synthesis`
- 上游：`bb-mas`
- 下游：`bb-check-cdc`、`bb-invoke-yosys`、`bb-invoke-opensta`
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| mas_path | path | true | — | `designs/<name>/mas/mas.json` |
| target_freq_mhz | int | true | — | 目标频率（MHz） |
| design_name | string | true | — | — |
| process_corner | string | false | `tt_0p77v_25c` | ASAP7 corner |
| io_delay_pct | float | false | `0.3` | IO delay 占周期比 |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/constraints/<design>.sdc` |
| `script_path` | `designs/<name>/synth/gen_sdc_<stamp>.py` |
| `clocks` | int |
| `io_constraints` | int |
| `exceptions` | int |
| `valid` | bool |
| `error` | string\|null |

## SDC 模板

```tcl
# Auto-generated from MAS by bb-create-sdc
# design: <name>  target: <freq>MHz  corner: <corner>
create_clock -name clk -period <period> [get_ports clk]
set_input_delay  -clock clk -max <io_max> [get_ports {<in_ports>}]
set_output_delay -clock clk -max <io_max> [get_ports {<out_ports>}]
set_false_path -from [get_ports rst_n]
set_multicycle_path 2 -setup -from [...]  ;# from MAS.path_exceptions
```

## 4-Phase 执行

### Phase 1 — render_sdc_py

```python
import json
mas = json.load(open(mas_path))
period = 1000.0 / target_freq_mhz   # ns
io_max = period * io_delay_pct
# 渲染 create_clock / set_input_delay / set_output_delay / set_false_path / set_multicycle_path
```

### Phase 2 — run_sdc_gen

`timeout 120 uv run python <script_path> > <artifact_path>`

### Phase 3 — sdc_syntax_check

```bash
sta -exit "read_sdc <artifact_path>; exit" 2>&1
```

`scripts/parse_sdc.py`：

- log 含 `Error:` → `valid=false`
- 否则计 clocks / io_constraints / exceptions 数

### Phase 4 — return

返回 JSON。

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| valid=true | 进 `bb-check-cdc` → `bb-invoke-yosys` |
| valid=false | 重试 1 次，仍失败 `error="sdc invalid"` |
| post-PD timing fail | `bb-guru-pd` 触发本 skill 加 false_path / multicycle |

## 资源索引

- `scripts/render_sdc_py.py`、`scripts/run_sdc_gen.py`、`scripts/parse_sdc.py`
- `assets/sdc.tcl.tmpl`
- `references/asap7_corner_period.md` — 各 corner 推荐 margin
- `Gotcha/sdc_pitfalls.md` — virtual clock / clock group / generated clock
