# Common ABC Optimization Scripts

## Standard Resynthesis Scripts

### resyn (Basic)
```
resyn
```
Single-pass resynthesis. Fast but limited optimization.

### resyn2 (Standard)
```
resyn2
```
Two-pass resynthesis with better optimization. Recommended default.

### resyn3 (Aggressive)
```
resyn3
```
Three-pass resynthesis. Best area/delay results but slower.

## Technology Mapping

### map -m (Delay-oriented)
```
map -m
```
Map to technology library with delay-oriented mapping.

### map -a (Area-oriented)
```
map -a
```
Area-oriented mapping. Use when timing is not critical.

### if -K (LUT Mapping, FPGA)
```
if -K 6
```
Map to K-input LUTs. `-K` sets LUT size.

## Retiming

```
retime
```
Move registers to optimize combinational path delay.

```
retime; resyn2
```
Retiming followed by resynthesis for best results.

## Complete Optimization Flows

### Area-focused
```
read_lib asap7.lib
read design.v
resyn2
map -a
print_stats
write mapped.v
```

### Delay-focused
```
read_lib asap7.lib
read design.v
set_delay 500
resyn3
map -m
retime
resyn2
print_stats
write mapped.v
```

### Balanced
```
read_lib asap7.lib
read design.v
resyn2
map -m
print_stats
write mapped.v
```

## Key Commands

| Command | Description |
|---------|-------------|
| `print_stats` | Show current network statistics |
| `print_gates` | Show gate-level implementation |
| `show` | Display network graphically |
| `time` | Show current arrival times |
| `topo` | Print topological order |
| `strash` | Structural hashing (AIG) |
| `rewrite` | DAG-aware rewriting |
| `refactor` | BDD-based refactoring |
| `resub` | Resubstitution |
| `scorr` | Sequential correspondence |

## AIG-based Optimization

```
strash
rewrite
refactor
balance
resyn2
```
Convert to AIG, apply AIG optimizations, then resynthesize.
