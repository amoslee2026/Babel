# Netgen Setup for ASAP7

## Setup File Location

```
libs/asap7/Magic/netgen_setup.tcl
```

## Device Recognition

Netgen uses the setup file to map layout-extracted devices to schematic device types.

### ASAP7 Device Types

| Device | Layout Name | Schematic Name | Parameters |
|--------|-------------|----------------|------------|
| NMOS | nfet | NMOS | W, L, M |
| PMOS | pfet | PMOS | W, L, M |

### Setup File Contents

```tcl
# ASAP7 Netgen Setup
# Device matching
property default all
property {nfet} remove as ad ps pd
property {pfet} remove as ad ps pd

# Tolerance for device parameters
permute transistors
property {nfet} tolerance {l 0.01} {w 0.01}
property {pfet} tolerance {l 0.01} {w 0.01}

# Ignore parasitic devices
ignore class c

# Power/ground net equivalence
equate VDD VDD VDD!
equate VSS VSS VSS! GND GND!
```

## Property Comparison

Netgen compares device properties (W, L, M) between schematic and layout.

### Tolerances

| Property | Default Tolerance | Notes |
|----------|-------------------|-------|
| W (width) | 0.01 um | Process variation |
| L (length) | 0.01 um | Process variation |
| M (multiplier) | exact | Must match exactly |

### Properties to Remove

Layout extraction adds parasitic properties not in schematic:
- `as` / `ad` -- source/drain area
- `ps` / `pd` -- source/drain perimeter
- `sa` / `sb` / `sd` -- LOD stress parameters

## Black-Box Cells

Some cells should be treated as black boxes (no internal comparison):

```tcl
# Black-box standard cells
blackbox ASAP7_*_xp*
blackbox FILL*
blackbox TAP*
```

## Power Net Naming

Schematic and layout may use different power net names:

| Schematic | Layout | Match Rule |
|-----------|--------|------------|
| VDD | VDD, VDD! | `equate VDD VDD!` |
| VSS | VSS, VSS!, GND | `equate VSS VSS! GND` |

## Running Netgen

```bash
netgen -batch lvs \
  "extracted.spice top_module" \
  "netlist.v top_module" \
  asap7_setup.tcl \
  lvs_report.txt
```

## Interpreting Results

- `Circuits match uniquely.` -- LVS clean
- `Circuits differ` -- Check discrepancies in report
- `Property errors` -- Device parameter mismatches (may be within tolerance)
- `Topology mismatch` -- Netlist connectivity differs (serious error)
