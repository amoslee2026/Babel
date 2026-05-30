# Verilator Key Flags Reference

## Compilation Flags

| Flag | Description |
|------|-------------|
| `--binary` | Compile to standalone executable (implies --build) |
| `--cc` | Generate C++ model (without --build) |
| `--exe` | Build executable from generated C++ |
| `--build` | Invoke C++ compiler to build model |
| `--timing` | Enable timing support (delays, #1ns etc.) |
| `--coverage` | Enable coverage analysis |
| `--trace` | Enable VCD tracing |
| `--trace-structs` | Trace struct/union members individually |
| `--trace-fst` | Use FST format instead of VCD |
| `--top-module <name>` | Specify top-level module |
| `-Mdir <dir>` | Output directory for generated files |
| `-o <name>` | Output executable name |
| `-f <file>` | Read file list from file |
| `-j <n>` | Parallel compilation jobs |
| `-CFLAGS "<flags>"` | Pass flags to C++ compiler |
| `--time-resolution-unit <unit>` | Time resolution (1ns, 1ps, etc.) |

## Warning Suppression

| Flag | Description |
|------|-------------|
| `-Wno-<WARNING>` | Suppress specific warning |
| `-Wno-fatal` | Do not treat warnings as fatal |
| `-Wno-WIDTHEXPAND` | Suppress width expansion warnings |
| `-Wno-UNUSEDSIGNAL` | Suppress unused signal warnings |
| `-Wno-UNDRIVEN` | Suppress undriven signal warnings |
| `-Wno-MULTIDRIVEN` | Suppress multi-driven signal warnings |
| `-Wno-BLKSEQ` | Suppress blocking assignment warnings |
| `-Wno-CASEINCOMPLETE` | Suppress incomplete case warnings |
| `-Wno-LATCH` | Suppress latch inference warnings |

## Common Warning Types

| Warning | Meaning | Fix |
|---------|---------|-----|
| `WIDTHEXPAND` | Signal width expanded | Check bit widths |
| `UNUSED` | Unused signal/port | Remove or use |
| `MULTIDRIVEN` | Signal driven from multiple places | Fix logic |
| `BLKSEQ` | Blocking in sequential block | Use `<=` |
| `CASEINCOMPLETE` | Case statement missing branches | Add default |
| `LATCH` | Latch inferred | Complete case/if |
| `COMBDLY` | Delayed assignment in combo | Use `=` |

## Simulation Flags

| Flag | Description |
|------|-------------|
| `+rand_seed=<N>` | Set random seed |
| `+verilator+seed+<N>` | Alternative seed syntax |
| `--assert` | Enable assertion checking (default on) |
| `--savable` | Enable save/restore |

## Coverage Analysis

```bash
# Run simulation with coverage
verilator --coverage --binary -f file_list.f tb.sv -o sim
./sim

# Merge coverage data
verilator_coverage obj_dir/coverage.dat --write merged.dat

# Generate annotated report
verilator_coverage --annotate merged.dat --annotate-min 1

# Generate info file for viewing
verilator_coverage --write-info merged.info merged.dat
```

## Version Check

```bash
verilator --version | grep -q "Verilator 5.012" || echo "VERSION_MISMATCH"
```
