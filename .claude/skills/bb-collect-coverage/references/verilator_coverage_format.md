# Verilator Coverage Format

## coverage.dat Structure
- `L <count> '<file>' <line>` -- Line coverage
- `B <count> '<file>' <line>` -- Branch coverage
- `T <count> '<file>' <line>` -- Toggle coverage
- `F <count> '<file>' <line>` -- Functional (user-defined) coverage

## Annotation Commands
```bash
verilator_coverage --annotate <output_dir> coverage.dat
verilator_coverage --write-info info.dat coverage.dat
```

## Merging Coverage
```bash
verilator_coverage --write coverage_merged.dat cov1.dat cov2.dat
```
