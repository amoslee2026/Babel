# ABC Script Reference for ASAP7

## Standard Optimization Script
```
read_blif input.blif
strash
rewrite
refactor
resub
rewrite
map -a -B 0.9
write_blif output.blif
```

## Timing-Driven Script
```
read_blif input.blif
read_lib -m asap7.genlib
strash
ifraig
scorr
dc2
dretime
map -d -B 0.95
buffer
upsize
write_blif output.blif
```

## Key Commands
| Command | Purpose |
|---------|---------|
| strash | Structural hashing (AIG) |
| rewrite | DAG-aware rewriting |
| refactor | BDD-based refactoring |
| resub | Resubstitution |
| map | Technology mapping |
| buffer | Buffer insertion |
| scorr | Sequential correspondence |
