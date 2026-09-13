# ASAP7 Process Corners (canonical naming, fix L-08)

Single source of truth for corner string spelling across all skills/agents.

## Naming Convention

```
<process>_<voltage>v_<temperature>c
```

| Token | Format | Example |
|-------|--------|---------|
| process | `ss` / `tt` / `ff` (lowercase) | `ss` |
| voltage | `0p` + millivolts digits with no decimal point | `0p77` (= 0.77 V) |
| temperature | `m` prefix for negative, digits as integer Celsius | `m40` (= -40 °C), `125` (= +125 °C) |

## v1.3 MVP Canonical Set

| Corner | Liberty filename hint (ASAP7) |
|--------|-------------------------------|
| `ss_0p63v_m40c` | `asap7sc7p5t_*_SS_nldm_*_0p63v_m40c.lib` |
| `tt_0p77v_25c`  | `asap7sc7p5t_*_TT_nldm_*_0p77v_25c.lib` |
| `ff_0p88v_125c` | `asap7sc7p5t_*_FF_nldm_*_0p88v_125c.lib` |

## Forbidden Spellings

- ❌ `tt_0p7v_25c`     (loses precision)
- ❌ `TT_0p77V_25C`    (case)
- ❌ `tt-0p77v-25c`    (separator)
- ❌ `tt_0.77v_25c`    (decimal point)
- ❌ `tt_770mv_25c`    (mV unit)

Always use `tt_0p77v_25c`.

## Usage

Reference this file from skills:

```markdown
默认 corners: synth `["tt_0p77v_25c"]`；post_pd `["ss_0p63v_m40c","tt_0p77v_25c","ff_0p88v_125c"]`
（命名规范见 [references/asap7_corners.md](references/asap7_corners.md)）
```
