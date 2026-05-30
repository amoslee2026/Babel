# OpenSTA Pitfalls

## Liberty Format Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Wrong corner liberty file | Timing numbers unrealistic | Verify corner-to-Liberty mapping (SS/TT/FF) |
| Liberty missing timing arcs | `Warning: no timing arc for cell` | Use NLDM library, not CCS/ECM |
| Mismatched voltage/temp | OCV warnings | Ensure `set_operating_conditions` matches liberty |

## Clock Tree Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Clock not propagated | Slack shows unrealistic values | `set_propagated_clock [all_clocks]` for post-CTS |
| Missing `create_clock` | `Error: no clocks defined` | Add `create_clock` in SDC before `report_checks` |
| Generated clock misdefined | Wrong period on divided clock | Use `-source` pointing to the generating pin |

## SDC Syntax Errors

| Problem | Symptom | Fix |
|---------|---------|-----|
| Missing `link_design` | `Error: design not linked` | Call `link_design <top>` after `read_verilog` |
| Port name mismatch | `Warning: port X not found` | SDC port names must match Verilog exactly |
| `get_clocks` vs `get_ports` | Wrong object type error | `create_clock` returns clock; `get_ports` returns port |

## SPEF / Post-Route Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| SPEF not read | Timing same as pre-route | Add `read_spef <path>` after `link_design` |
| SPEF net mismatch | `Warning: net X not found in SPEF` | Ensure netlist matches SPEF (same routing run) |
| Missing parasitics | Partial SPEF coverage | Use `report_parasitic_annotation` to check |

## Multi-Corner Pitfalls

| Problem | Symptom | Fix |
|---------|---------|-----|
| Corners share liberty | All corners report same WNS | Each corner needs its own `read_liberty` |
| Missing corner separator | Metrics bleed across corners | Use `puts "=== CORNER X ==="` between blocks |
| Temperature inversion ignored | SS at 125C gives optimistic results | 7nm: SS at -40C, FF at 125C |

## Virtual Clock

| Problem | Symptom | Fix |
|---------|---------|-----|
| No physical clock port | `create_clock` on virtual clock | Use `create_clock -name vclk -period 2.0` (no port) |
| I/O unconstrained | `Warning: no clock for input delay` | Define virtual clock for I/O constraints |

## Debug Checklist

1. Verify `read_liberty` points to correct corner file
2. Confirm `link_design` succeeds (check for unresolved black boxes)
3. Check `report_clocks` shows correct period
4. Run `report_checks -path_delay max` for setup, `min` for hold
5. For post-PD: verify `read_spef` coverage
