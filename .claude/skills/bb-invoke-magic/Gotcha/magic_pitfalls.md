# Magic Pitfalls

## Tech File Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Wrong tech file | DRC rules don't match ASAP7 | Use `libs/asap7/asap7.tech` specifically |
| Tech file not found | `Error: cannot read tech file` | Verify path; tech file must be absolute or relative to CWD |
| Missing layer definitions | Extraction skips layers | Ensure tech file has all M1-M4, Via definitions |

## DEF vs GDS Loading

| Problem | Symptom | Fix |
|---------|---------|-----|
| Loading DEF without LEF | Cells not recognized | Load LEF first: `lef read asap7_cells.lef` then `def read` |
| Loading GDS after DEF | Geometry mismatch | Use one format consistently per session |
| Grid misalignment | DRC false positives on grid errors | `grid` command to check; DEF grid must match tech file |

## DRC False Positives

| Problem | Symptom | Fix |
|---------|---------|-----|
| Unflattened hierarchy | DRC misses violations in subcells | Run `select top cell` + `drc check` on flattened view |
| Stale DRC results | Old violations persist | Run `drc catch` to clear, then `drc check` fresh |
| Boundary violations | Errors at cell edges only | Check abutment spacing; may be placement issue |

## Extraction Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Extraction hangs | Very large designs | Flatten selectively; use `extract area` for regions |
| Missing parasitics | SPICE has no R/C values | Ensure `extract all` runs before `ext2spice` |
| ext2spice empty output | No extracted netlist | Check `extract` completed; verify hierarchy with `ext2spice hierarchy` |

## Grid Alignment

| Problem | Symptom | Fix |
|---------|---------|-----|
| Off-grid geometry | Thousands of DRC errors | Snap placement to manufacturing grid (1nm) |
| DEF grid mismatch | Placement cells misaligned | Match DEF `UNITS DISTANCE MICRONS` to tech file grid |
| Via stacking errors | Via DRC violations | Ensure via positions align to M1/M2 pitch |

## Batch Mode Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| No `-dnull` flag | Magic tries to open GUI | Always use `-dnull -noconsole` for batch |
| Missing `quit` | Script hangs | End every TCL script with `quit` |
| rcfile interference | Unexpected behavior | Use `-rcfile /dev/null` to disable .magicrc |

## Debug Checklist

1. Verify tech file path exists and is correct for ASAP7
2. Check log for `Error:` lines after batch run
3. For DRC: confirm `drc count` output matches report
4. For extraction: verify `extracted.spice` file size > 0
5. For placement: confirm `placed.def` exists and is valid
