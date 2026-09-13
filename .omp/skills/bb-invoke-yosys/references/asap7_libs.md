# ASAP7 Library Reference

## Standard Cell Libraries

| Library | Track | Revision | Description |
|---------|-------|----------|-------------|
| `asap7sc6t_26` | 6T | r26 | 6-track, minimal height |
| `asap7sc7p5t_27` | 7.5T | r27 | 7.5-track, balanced |
| `asap7sc7p5t_28` | 7.5T | r28 | 7.5-track, improved timing |

## Library Files

Path: `libs/asap7/` or `libs/ASAP7-Synopsys-Enablement/`

| File Type | Location |
|-----------|----------|
| Liberty (.lib) | `lib_*_nldm_*` |
| LEF | `*_.lef` |
| Tech LEF | `asap7_tech.lef` |

## Corner Selection

| Corner | Lib File Pattern |
|--------|------------------|
| TT (Typical) | `*_TT_nldm_*` |
| SS (Slow-Cold) | `*_SS_nldm_*` |
| FF (Fast-Hot) | `*_FF_nldm_*` |

## Recommended for Synthesis

```
libs/asap7/asap7sc7p5t_28/lib/asap7sc7p5t_AO_RVT_TT_nldm_201020.lib
```

## Drive Strengths

- AO (Average Output): Balanced drive
- BO (Buffered Output): Higher drive
- CO (Cascade Output): Low drive for internal

## Vt Types

- RVT: Regular threshold (balanced)
- LVT: Low threshold (fast, high leakage)
- HVT: High threshold (slow, low leakage)

## Default Selection

For synthesis, use:
- Corner: TT (Typical-Typical)
- Track: 7.5T (balanced density/timing)
- Vt: RVT (regular)
- Drive: AO (average)

Full path:
```
libs/asap7/asap7sc7p5t_28/lib/asap7sc7p5t_AO_RVT_TT_nldm_201020.lib
```