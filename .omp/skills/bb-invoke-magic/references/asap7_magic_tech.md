# ASAP7 Magic Technology Setup

## Tech File

| Item | Path |
|------|------|
| Magic tech file | `libs/asap7/asap7.tech` |
| Alternative | `libs/asap7/magic/asap7_magic.tech` |

The tech file defines layers, design rules, and connectivity for ASAP7 7nm PDK.

## Layer Mapping (ASAP7 to Magic)

| ASAP7 Layer | Magic Layer | Description |
|-------------|-------------|-------------|
| M1 | Metal1 | First metal (horizontal) |
| M2 | Metal2 | Second metal (vertical) |
| M3 | Metal3 | Third metal (horizontal) |
| M4 | Metal4 | Fourth metal (vertical) |
| V0 | Via0 | Contact to M1 |
| V1 | Via1 | Via M1-M2 |
| V2 | Via2 | Via M2-M3 |
| V3 | Via3 | Via M3-M4 |
| Active | Active | Transistor active area |
| Poly | Poly | Gate polysilicon |

## Key Design Rules (7nm)

| Rule | Value | Description |
|------|-------|-------------|
| M1 width | 36nm | Minimum metal width |
| M1 spacing | 36nm | Minimum metal spacing |
| M2 width | 48nm | Minimum metal width |
| M2 spacing | 48nm | Minimum metal spacing |
| Via size | 36x36nm | Minimum via dimension |

## Running Magic with ASAP7

```bash
# Batch mode DRC
magic -dnull -noconsole -T libs/asap7/asap7.tech < drc_script.tcl

# Interactive
magic -T libs/asap7/asap7.tech design.mag
```

## DEF vs GDS Loading

| Format | Command | Use Case |
|--------|---------|----------|
| DEF | `load design.def` | Post-route DRC, placement |
| GDS | `gds read design.gds` | Final verification, extraction |
| MAG | `load design.mag` | Magic native, intermediate edits |
