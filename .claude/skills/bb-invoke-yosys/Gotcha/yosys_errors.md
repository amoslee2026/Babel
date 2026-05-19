# Yosys Common Errors

## ERROR Codes

| Error | Cause | Fix |
|-------|-------|-----|
| `ERROR: Module ... not found` | Top module missing | Check `file_list.f` |
| `ERROR: Wire ... has multiple drivers` | MULTIDRIVEN RTL | Fix RTL driver conflict |
| `ERROR: Failed to detect width of ...` | Width mismatch | Check signal widths |
| `ERROR: Failed to map ... to cell` | Tech lib issue | Verify liberty path |

## Warnings

### MULTIDRIVEN
```
Warning: MULTIDRIVEN: Signal ... driven by multiple always blocks
```
**Cause**: Multiple drivers on same signal
**Fix**: Raise `rtl-needs-fix` - RTL bug, cannot synthesize

### WIDTHEXPAND
```
Warning: WIDTHEXPAND: ... expanded from 8 to 9 bits
```
**Cause**: Width expansion during operations
**Fix**: Log only; raise `rtl-needs-fix` if ≥ 5 hits

### UNUSED
```
Warning: UNUSED: Signal ... is never used
```
**Cause**: Dead code
**Fix**: Log only, not blocker

### Latch Inferred
```
Warning: latch inferred for signal ...
```
**Cause**: incomplete `always_comb` case coverage
**Fix**: Raise `rtl-needs-fix` - unintended latch

## Common Failures

### Timeout
```
YOSYS_TIMEOUT after 600s
```
**Cause**: Complex logic or infinite loop in synthesis
**Fix**: Reduce complexity, add `opt -fast` passes

### Version Mismatch
```
VERSION_MISMATCH: got '0.30', need '0.35'
```
**Cause**: Wrong Yosys version installed
**Fix**: `source ~/wrk/eda_opensources/eda_env.sh`

### Exit Code Non-Zero
```
YOSYS_EXIT_1
```
**Cause**: Generic synthesis failure
**Fix**: Check log for specific error

## Resolution Flow

1. Check `yosys_<stamp>.log` for ERROR lines
2. Classify by error type above
3. Escalate: RTL → `rtl-needs-fix`, Arch → `arch-needs-fix`
4. Retry with adjusted options if non-RTL issue