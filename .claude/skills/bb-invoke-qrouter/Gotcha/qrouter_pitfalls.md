# QRouter Pitfalls

## LEF/DEF Version Mismatch

**Problem**: QRouter requires LEF/DEF version 5.8. ASAP7 LEF files may declare
older versions (5.4-5.7) that cause parse warnings or silent failures.

**Fix**: Verify VERSION header in LEF/DEF. Manually patch version string if needed:
```
VERSION 5.8 ;
```

**Detection**: Check QRouter log for "LEF version mismatch" or "DEF version" warnings.

## Antenna Violations

**Problem**: QRouter does not check antenna rules. Long Metal2/Metal3 routes
accumulating charge can cause gate oxide damage in 7nm.

**Fix**: Run antenna check after routing:
- Use Magic: `antennacheck` command
- Or KLayout DRC with antenna rule deck

**Detection**: Post-route DRC report showing antenna violations.

## Routing Congestion

**Problem**: Dense standard cell placement creates routing congestion, causing
QRouter to fail nets or create excessive vias.

**Symptoms**:
- Many "failed to route" nets in report
- Routes with excessive layer changes
- Very long runtimes on complex nets

**Fix**:
- Reduce placement density (increase utilization target)
- Add routing blockages for congested areas
- Use `layers` command to restrict routing to higher metals

## Unrouteable Nets

**Problem**: QRouter cannot route nets with:
- Overlapping pins on same layer
- Pins outside routing grid
- Macro blockages completely blocking paths

**Detection**: `failed` count > 0 in routing report.

**Fix**:
- Check pin placement in DEF
- Verify macro orientations and blockages
- Add feedthrough cells for blocked paths

## Power/Ground Net Routing

**Problem**: QRouter routes signal nets only. VDD/VSS nets must be handled
separately (usually via power grid in floorplan).

**Fix**: Ensure power nets are excluded from routing:
```
# In config, power nets should have SPECIALNETS in DEF
```

## Memory Usage on Large Designs

**Problem**: QRouter uses significant memory for designs > 100K cells.
ASAP7 7nm designs can easily exceed this.

**Fix**:
- Run on machine with >= 16GB RAM
- Set `QROUTER_MAX_MEMORY` environment variable
- Consider partitioning large designs
