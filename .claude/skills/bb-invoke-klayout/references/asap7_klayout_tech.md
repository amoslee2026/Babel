# ASAP7 KLayout Technology Reference

## GDS Layer Map

| Layer | Purpose | GDS Layer | GDS Datatype |
|-------|---------|-----------|--------------|
| Active | Diffusion | 65 | 20 |
| Fin | Fin pattern | 3 | 0 |
| Gate | Poly gate | 1 | 0 |
| SDT | Source/Drain | 5 | 0 |
| LIG | Local interconnect | 17 | 0 |
| LISD | Local interconnect SD | 18 | 0 |
| V0 | Contact/Via 0 | 19 | 0 |
| M1 | Metal 1 | 74 | 0 |
| V1 | Via 1 | 75 | 0 |
| M2 | Metal 2 | 76 | 0 |
| V2 | Via 2 | 77 | 0 |
| M3 | Metal 3 | 78 | 0 |
| V3 | Via 3 | 79 | 0 |
| M4 | Metal 4 | 80 | 0 |
| V4 | Via 4 | 81 | 0 |
| M5 | Metal 5 | 82 | 0 |
| Pad | Bond pad | 90 | 0 |

## DRC Minimum Rules (ASAP7 6-track)

| Rule | Value (nm) |
|------|-----------|
| M1 width | 36 |
| M1 spacing | 36 |
| M2 width | 36 |
| M2 spacing | 36 |
| M3 width | 36 |
| M3 spacing | 36 |
| M4 width | 48 |
| M4 spacing | 48 |
| Via1 enclosure | 10 |
| Via2 enclosure | 10 |

## Technology File

| Item | Path |
|------|------|
| Layer properties | `libs/asap7/klayout/asap7.lyt` |
| DRC rule deck | `libs/asap7/klayout/asap7_drc.lydrc` |
| Layer map | `libs/asap7/klayout/asap7.map` |

## Batch Mode Commands

```bash
# Run DRC in batch (no GUI)
klayout -b -rd in_gds=design.gds -rd report=drc_report.xml -r asap7_drc.lydrc

# Export GDSII to PNG
klayout -b -rd in_gds=design.gds -rd out_png=design.png -r export_png.rb

# Merge GDS files
klayout -b -rd in1=top.gds -rd in2=macro.gds -rd out=merged.gds -r merge.rb

# Run script on GDS
klayout -b -rd in_gds=design.gds -r transform.py
```

## DRC Report Format

KLayout DRC reports use XML format:

```xml
<?xml version="1.0"?>
<report-database>
  <categories>
    <category><name>M1.W.1</name></category>
  </categories>
  <items>
    <item>
      <category>M1.W.1</category>
      <cell>TOP</cell>
      <values><value>polygon: (x1,y1;x2,y2;...)</value></values>
    </item>
  </items>
</report-database>
```

## Netgen vs KLayout DRC

| Feature | Magic DRC | KLayout DRC |
|---------|-----------|-------------|
| Speed | Slower (interpreted) | Faster (compiled rules) |
| GUI | Limited | Full viewer |
| Format | Plain text report | XML report |
| Custom rules | Tech file | `.lydrc` Ruby script |
