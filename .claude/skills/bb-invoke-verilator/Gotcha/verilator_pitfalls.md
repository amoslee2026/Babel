# Verilator Common Pitfalls

## 1. Missing --timing for Delays

**Problem**: Simulation ignores `#10ns` delays, everything runs at time 0.

**Cause**: Verilator 5.x requires `--timing` flag to support delay statements.

**Fix**:
```bash
verilator --binary --timing -f file_list.f tb.sv
```

**Note**: `--timing` significantly increases compile time. Only enable when testbench uses delays.

## 2. Signal Naming Conflicts

**Problem**: `%Error: Signal name conflicts with C++ keyword` for signals named `new`, `class`, `delete`, etc.

**Fix**:
- Rename signals to avoid C++ reserved words
- Use `--prefix` flag to namespace generated code
- Add `// verilator lint_off` pragmas

## 3. Large VCD Trace Files

**Problem**: VCD files grow to GB, filling disk.

**Fix**:
```systemverilog
// In testbench, use $dumpvars with scope limit
initial begin
    $dumpfile("trace.vcd");
    $dumpvars(1, tb_top.dut);  // Only DUT, depth 1
end
```
- Use `--trace-fst` for compressed FST format (10x smaller)
- Add `$dumpoff`/`$dumpon` to capture only relevant windows

## 4. Memory Limits During Compilation

**Problem**: `cc1plus: out of memory` during Verilator C++ compilation.

**Fix**:
- Reduce `-j` parallel jobs (e.g., `-j 2`)
- Add `-CFLAGS "-Os"` to optimize for size
- Split large designs into smaller compilation units
- Use `--no-decoration` to reduce generated code size

## 5. SystemVerilog Feature Gaps

**Problem**: Verilator does not support all SV features.

**Unsupported**:
- `force`/`release` statements (limited)
- `rand`/`randc` in non-class contexts
- Analog/mixed-signal
- Dynamic process creation

**Workaround**: Use `--assert` for property checking instead of SVA where possible.

## 6. Coverage Data Merge Issues

**Problem**: `verilator_coverage` fails with multiple `.dat` files.

**Fix**:
```bash
# Ensure each run writes to separate obj_dir
verilator_coverage obj_dir_run1/coverage.dat obj_dir_run2/coverage.dat \
  --write merged_coverage.dat
```

## 7. Undriven/Unused Signal Warnings in Synthesis-Style RTL

**Problem**: Synthesis-ready RTL has intentional unused ports (e.g., debug signals).

**Fix**:
```verilog
/* verilator lint_off UNUSEDSIGNAL */
wire [31:0] debug_bus;
/* verilator lint_on UNUSEDSIGNAL */
```

## 8. Binary Mode vs Library Mode

**Problem**: `--binary` creates executable but no linkable library.

**When to use each**:
- `--binary`: Standalone simulation (most common)
- `--cc --exe`: Custom C++ testbench wrapper
- `--cc`: Generate model for integration into larger C++ system

## 9. Time Resolution Mismatch

**Problem**: `%Error: Time resolution mismatch` between modules.

**Fix**: Use `--time-resolution-unit 1ps` (finest resolution) at compile time.

## 10. Assertion Checking Requires Explicit Enable

**Problem**: SVA assertions not checked in simulation.

**Fix**: Assertions are on by default in Verilator 5.x. If disabled:
```bash
verilator --assert --binary -f file_list.f tb.sv
```
