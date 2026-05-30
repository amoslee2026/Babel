# Netgen LVS Pitfalls

## Power/Ground Net Mismatch

| Problem | Symptom | Fix |
|---------|---------|-----|
| VDD/VSS naming | `Net mismatch` on power nets | Add `property {-circuit1} vdd` to setup file |
| Multiple power domains | Extra nets in one circuit | Use `blackbox` for domain-crossing cells |
| Implicit power connections | Missing power ports in SPICE | Ensure `extract all` includes power rails |

## Cell Name Differences

| Problem | Symptom | Fix |
|---------|---------|-----|
| Synthesis vs layout cell names | `Cell not found` errors | Ensure LEF cell names match liberty names |
| Case sensitivity | `NAND2x1` vs `nand2x1` | Use consistent naming; Netgen is case-sensitive |
| Library prefix | `asap7sc7p5t/NAND2x1` vs `NAND2x1` | Strip library prefix in setup file |

## Property Comparison Failures

| Problem | Symptom | Fix |
|---------|---------|-----|
| W/L mismatch | `Property mismatch` on devices | Check synthesis sizing vs layout extraction |
| Multiplier difference | `Property mismatch` m-factor | Ensure `m` parameter consistent |
| Missing properties | One side has props other lacks | Use `property {-circuit1} -remove <prop>` |

## Port Order Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Port order swap | `Device mismatch` despite same cell | Enable `permute default` in setup |
| Bus bit ordering | `[7:0]` vs `[0:7]` | Ensure consistent bit order in both netlists |
| Hierarchical port names | Full path vs short name | Flatten both circuits or match naming |

## Netlist Format Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Verilog vs SPICE | Format conversion errors | Netgen handles this natively; check cell mapping |
| Black-box cells | `Cell not found` for macros | Add `blackbox` declarations in setup |
| Hierarchical netlists | Subcircuit not expanded | Use `flatten` or ensure hierarchy matches |

## Extraction Issues (Upstream from Magic)

| Problem | Symptom | Fix |
|---------|---------|-----|
| Incomplete extraction | Missing devices in SPICE | Re-run `extract all` in Magic |
| Parasitic devices | Extra R/C devices in SPICE | Use `ext2spice lvs` (not full extraction) |
| Filler cells | Extra cells in layout | Black-box fillers or exclude from comparison |

## Debug Checklist

1. Verify both netlists exist and are non-empty
2. Check setup file handles power/ground naming
3. Look for `blackbox` declarations for IP macros
4. Compare cell counts: `grep -c "instance" netlist.v` vs SPICE
5. If mismatch: examine first discrepancy in report, often cascades
