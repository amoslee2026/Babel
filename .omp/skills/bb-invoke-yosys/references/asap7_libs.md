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

ASAP7 publishes one liberty per cell family; combinational and sequential cells
never share a file. Verified layout (`The-OpenROAD-Project/asap7sc7p5t_28`, r28):

```
<root>/LIB/NLDM/asap7sc7p5t_SIMPLE_RVT_SS_nldm_211120.lib   # comb → abc
<root>/LIB/NLDM/asap7sc7p5t_SEQ_RVT_SS_nldm_220123.lib      # DFF → dfflibmap
```

`<root>` = `libs/asap7/asap7sc7p5t_28`. Date suffixes vary by family
(`211120` / `220122` / `220123`), so resolve with a glob
(`*_{FAMILY}_{VT}_{CORNER}_nldm_*.lib`) instead of pinning a filename. The older
`libs/asap7/asap7sc7p5t_28/lib/*_201020.lib` path does not exist upstream.

## Drive Strengths

- AO (Average Output): Balanced drive
- BO (Buffered Output): Higher drive
- CO (Cascade Output): Low drive for internal

## Vt Types

- RVT: Regular threshold (balanced)
- LVT: Low threshold (fast, high leakage)
- HVT: High threshold (slow, low leakage)

## Default Selection

For synthesis (`generate_synthesis_config.py` defaults):
- Corner: SS (slow) — pessimistic for area/timing signoff of first run
- Track: 7.5T (`asap7sc7p5t_28`)
- Vt: RVT (regular)
- Combinational family: SIMPLE (or AO/OA/INVBUF)
- Sequential family: SEQ

```bash
# resolve liberty automatically
python3 scripts/generate_synthesis_config.py ... \
    --lib-root libs/asap7/asap7sc7p5t_28 --corner SS --vt RVT
```

ABC mapping: the stock supergate script SIGSEGVs (status 8B) on ASAP7 liberty;
use `-script "+strash;map"` (default). Verified result on M13_ISADecoder:
729 cells, 37.748 µm² comb + 53.071 µm² seq = 90.82 µm².