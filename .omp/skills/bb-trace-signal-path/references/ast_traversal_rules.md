# AST Traversal Rules for Signal Path Tracing

## Traversal Direction
- **Forward (top-down)**: Start at top module, recurse into instances
- **Backward (bottom-up)**: Start at leaf, find parent modules

## Port Connection Resolution

### Named Association
`.port_name(signal_name)` - Match by port name; signal name may differ.

### Positional Association
`instance(sig1, sig2)` - Match by position in port list.

## Signal Types
- **Wire**: `assign out = in;` - propagates both directions
- **Reg/Logic**: `always_ff @(posedge clk) q <= d;` - source (RHS) to destination (LHS)
- **Port**: Module boundary - input (in), output (out)

## Special Cases

### Generate Blocks
Expand loops, index instances: `gen_loop[0].u`, `gen_loop[1].u`

### Bus Slicing
`assign bus[3:0] = data;` - track bit ranges for partial assignments

### Conditional
`assign out = sel ? a : b;` - trace all branches

## Algorithm
```
forward(module, signal):
    for instance in module.instances:
        if signal connects to instance.port:
            add to path; recurse(instance.module)

backward(module, signal):
    for parent that instantiates module:
        if parent.port connects to signal:
            add to path; recurse(parent)
```

## Best Practices
1. Limit depth to prevent infinite recursion (max 10)
2. Track visited nodes to avoid cycles
3. Handle bus bit ranges for partial assignments
4. Validate port exists in module definition
5. Document untraceable constructs
