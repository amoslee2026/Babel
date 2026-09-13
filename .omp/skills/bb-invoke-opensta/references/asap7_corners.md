# ASAP7 Timing Corners

## PVT Corner Definitions

| Corner | Process | Voltage | Temp | Liberty File Pattern | Use Case |
|--------|---------|---------|------|---------------------|----------|
| `ss_0p63v_m40c` | SS (slow-slow) | 0.63V | -40C | `*_SS_nldm_*` | Worst-case setup timing |
| `tt_0p77v_25c` | TT (typical) | 0.77V | 25C | `*_TT_nldm_*` | Typical functional |
| `ff_0p88v_125c` | FF (fast-fast) | 0.88V | 125C | `*_FF_nldm_*` | Worst-case hold timing |

## Liberty File Locations

Base path: `libs/asap7/asap7sc7p5t_28/lib/`

| Corner | File |
|--------|------|
| SS | `asap7sc7p5t_AO_RVT_SS_nldm_201020.lib` |
| TT | `asap7sc7p5t_AO_RVT_TT_nldm_201020.lib` |
| FF | `asap7sc7p5t_AO_RVT_FF_nldm_201020.lib` |

## Vt Variants

| Vt Type | Suffix | Leakage | Speed | Usage |
|---------|--------|---------|-------|-------|
| RVT | `_RVT_` | Normal | Normal | Default |
| LVT | `_LVT_` | High | Fast | Critical paths |
| HVT | `_HVT_` | Low | Slow | Non-critical, low power |

## Multi-Corner Signoff Matrix

| Phase | Corners Required | Pass Criteria |
|-------|-----------------|---------------|
| Post-synthesis | `tt_0p77v_25c` | WNS >= 0 |
| Post-PD signoff | All three | All WNS >= 0 |

## Temperature Inversion Note

At 7nm, the SS corner uses **low temperature** (-40C) due to temperature inversion:
slow transistors are slower at cold temperatures in advanced nodes.
The FF corner uses **high temperature** (125C) because fast transistors get faster
at cold temps, making hold violations worse.
