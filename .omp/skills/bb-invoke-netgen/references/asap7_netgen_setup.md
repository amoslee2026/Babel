# ASAP7 Netgen Setup

## Setup File Location

| Item | Path |
|------|------|
| Default setup | `libs/asap7/netgen/setup.tcl` |
| Device map | `libs/asap7/netgen/asap7_devices.tcl` |

## Setup File Contents

The setup file configures how Netgen compares circuits:

```tcl
# Ignore power/ground name differences
property {-circuit1} vdd
property {-circuit1} gnd
property {-circuit2} vdd
property {-circuit2} gnd

# Cell permutation (port order)
permute default

# Compare all device properties
property device all
```

## Device Recognition

Netgen must recognize ASAP7 standard cells. Key mappings:

| Netlist Cell | Netgen Device | Properties Compared |
|-------------|---------------|-------------------|
| `INVx1` | Inverter | W, L, m (multiplier) |
| `NAND2x1` | NAND2 | W, L for each input |
| `NOR2x1` | NOR2 | W, L for each input |
| `DFF*` | Flip-flop | Data, clock, Q ports |
| `BUFX*` | Buffer | W, L, drive strength |

## Netlist Format Requirements

| Format | Schematic | Layout |
|--------|-----------|--------|
| Verilog | Synthesized `netlist.v` | N/A |
| SPICE | N/A | Magic `extracted.spice` |

Netgen handles cross-format comparison (Verilog vs SPICE).

## Common Configuration Options

```tcl
# Black-box cells (ignore internal structure)
blackbox <cell_name>

# Ignore specific properties
property {-circuit1} -remove <prop_name>

# Flatten hierarchy for comparison
flatten {-circuit1}
flatten {-circuit2}

# Compare with port order tolerance
permute {-circuit1}
permute {-circuit2}
```
