# KLayout Pitfalls — ASAP7 7nm

## Layer Map Mismatch

| Problem | Symptom | Fix |
|---------|---------|-----|
| Wrong layer numbers | DRC errors on valid geometry | Verify `asap7.map` matches PDK version |
| Missing layer definitions | Import skips layers | Check `.lyt` file has all M1-M5, Via definitions |
| Magic vs KLayout numbering | Geometry appears on wrong layer | Use separate layer map files per tool |

## DRC Rule Deck Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Version mismatch | False violations or missed errors | Match `asap7_drc.lydrc` to PDK version |
| Incomplete rule set | Some violations undetected | Verify deck covers width, spacing, area, enclosure |
| Custom rules syntax | Ruby errors in `.lydrc` | Test with `klayout -b -r test.lydrc` first |

## Deep Mode Performance

| Problem | Symptom | Fix |
|---------|---------|-----|
| Memory exhaustion | OOM kill on large designs | Use `-t 4` minimum threads, limit hierarchy depth |
| Timeout | DRC never completes | Set explicit `--timeout 3600` |
| Slow on full-chip | Hours for >100K cells | Flatten selectively; run DRC per-block |

## GDSII Import/Export

| Problem | Symptom | Fix |
|---------|---------|-----|
| Cell name conflicts | Auto-flattened hierarchy | Use `--add-cell-name` to preserve |
| Off-grid shapes | DRC false positives | Snap to manufacturing grid before export |
| Missing cells in export | Incomplete GDS | Verify all referenced cells exist in library |

## XML Report Parsing

| Problem | Symptom | Fix |
|---------|---------|-----|
| Malformed XML | Parser fails | Validate with `xmllint` before parsing |
| Missing category names | Cannot classify violations | Ensure DRC deck names all rules explicitly |
| Large reports (>100MB) | Parser timeout | Split by category or filter severity |

## Macro Script Issues

| Problem | Symptom | Fix |
|---------|---------|-----|
| Encoding errors | Silent parse failure | Ensure `.lym` files are UTF-8 only |
| Missing dependencies | Script crashes | Include all `require` statements at top |
| GUI-only commands | Batch mode failure | Guard interactive calls with `if not Application.instance.is_batch_mode` |

## Debug Checklist

1. Verify layer map file exists and matches PDK version
2. Check DRC deck syntax with dry-run: `klayout -b -r deck.lydrc -rd test=1`
3. Confirm XML report is well-formed before parsing
4. For large designs: test on single block before full-chip run
5. Verify GDS cell hierarchy matches expected structure
