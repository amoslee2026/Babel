# ASAP7 LEF File Paths and Parameters

## LEF Library Locations

Base path: `libs/asap7/`

### asap7sc6t_26 (6-track standard cells)

| File | Path |
|------|------|
| Tech LEF (4x) | `asap7sc6t_26/techlef_misc/asap7sc6t_tech_4x_210831.lef` |
| Standard cells (L) | `asap7sc6t_26/LEF/asap7sc6t_26_L_1x_210923b.lef` |
| Standard cells (R) | `asap7sc6t_26/LEF/asap7sc6t_26_R_1x_210923b.lef` |
| Standard cells (SL) | `asap7sc6t_26/LEF/asap7sc6t_26_SL_1x_210923b.lef` |
| SRAM macros | `asap7sc6t_26/LEF/asap7sc6t_26_SRAM_1x_210923b.lef` |

### asap7sc7p5t_27 (7.5-track standard cells, rev 27)

| File | Path |
|------|------|
| Tech LEF (4x) | `asap7sc7p5t_27/techlef_misc/asap7_tech_4x_201209.lef` |
| Standard cells (L) | `asap7sc7p5t_27/LEF/asap7sc7p5t_27_L_1x_201211.lef` |
| Standard cells (R) | `asap7sc7p5t_27/LEF/asap7sc7p5t_27_R_1x_201211.lef` |
| Standard cells (SL) | `asap7sc7p5t_27/LEF/asap7sc7p5t_27_SL_1x_201211.lef` |
| SRAM macros | `asap7sc7p5t_27/LEF/asap7sc7p5t_27_SRAM_1x_201211.lef` |

### asap7sc7p5t_28 (7.5-track standard cells, rev 28)

| File | Path |
|------|------|
| Tech LEF (4x) | `asap7sc7p5t_28/techlef_misc/asap7_tech_4x_201209.lef` |
| Standard cells (L) | `asap7sc7p5t_28/LEF/asap7sc7p5t_28_L_1x_220121a.lef` |
| Standard cells (R) | `asap7sc7p5t_28/LEF/asap7sc7p5t_28_R_1x_220121a.lef` |
| Standard cells (SL) | `asap7sc7p5t_28/LEF/asap7sc7p5t_28_SL_1x_220121a.lef` |
| SRAM macros | `asap7sc7p5t_28/LEF/asap7sc7p5t_28_SRAM_1x_220121a.lef` |

## Key Parameters for QRouter

| Parameter | Value | Note |
|-----------|-------|------|
| LEF/DEF version | 5.8 | Must match QRouter parser |
| Units | MICRONS 10000 | Database precision |
| Min routing layer | Metal2 | M1 reserved for cells |
| Max routing layer | Metal7 | Top metal for signal |
| Via definitions | In tech LEF | Must read tech LEF first |

## QRouter Read Order

```
read_lef <tech_lef>     # Technology LEF first (layer defs, vias)
read_lef <stdcell_lef>  # Standard cell LEF (macro defs, obs)
read_def <input_def>    # Design DEF with placement
```
