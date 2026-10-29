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

## Verified File Layout and Mapping Gotchas (2026-10-29, yosys 0.70+277)

Real published layout (`The-OpenROAD-Project/asap7sc7p5t_28`, r28) — no `lib/`
level, dates differ per family:

```
<root>/LIB/NLDM/asap7sc7p5t_AO_RVT_SS_nldm_211120.lib
<root>/LIB/NLDM/asap7sc7p5t_OA_RVT_SS_nldm_211120.lib
<root>/LIB/NLDM/asap7sc7p5t_SIMPLE_RVT_SS_nldm_211120.lib
<root>/LIB/NLDM/asap7sc7p5t_INVBUF_RVT_SS_nldm_220122.lib
<root>/LIB/NLDM/asap7sc7p5t_SEQ_RVT_SS_nldm_220123.lib
```

Rules that follow from the layout:

- Resolve liberty by glob (`*_<FAMILY>_<VT>_<CORNER>_nldm_*.lib`), never pin a
  filename: the legacy `libs/asap7/asap7sc7p5t_28/lib/*_201020.lib` path from
  older docs does not exist in the published tree.
- No single liberty holds both combinational and sequential cells: `dfflibmap`
  needs `SEQ`, `abc` needs `SIMPLE` (or `AO`/`OA`/`INVBUF`). A concatenated
  multi-`library()` file makes yosys read only the first block, so `stat` then
  reports `Area for cell type ... is unknown!`.
- `stat -liberty` accepts one file per call; run it twice (comb then seq) and add
  the two `Chip area` values.

ABC mapping (VERIFIED on M13_ISADecoder):

| ABC invocation | Result |
|----------------|--------|
| default (no `-script`, supergate `&nf`) | `ABC failed with status 8B` (SIGSEGV) |
| `-g AND,OR,NAND,NOR,XOR` | status 8B |
| `-fast` | option not supported by this build |
| `-script "+strash;map"` | maps cleanly: 729 cells, comb 37.748 + seq 53.071 = 90.82 µm² |

`map` yields only NAND/XOR/XNOR + DFF (no AO/OAI composites), so area is a
conservative upper bound. Reproduce with `utils/run_yosys_asap7_map.sh`.

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
