# AST Traversal Rules for Signal Path Tracing

## Overview

Signal path tracing walks the AST JSON produced by `bb-parse-ast` (or fallback)
to find propagation paths from a source signal to a sink signal.

## Edge Types

The tracer follows these AST edges to build the signal adjacency graph:

| Edge Type | AST Node Type | Description |
|-----------|---------------|-------------|
| `cont_assign` | `Assign` | Continuous assignment (`assign lhs = rhs`) |
| `non_blocking_assign` | `NonBlockingSubst` | `lhs <= rhs` in always block |
| `blocking_assign` | `BlockingSubst` | `lhs = rhs` in always block |
| `port_connection` | `Instance` + children | Module port mapping |
| `conditional` | `IfStatement` / `CaseStatement` | Conditional signal flow |

## Traversal Direction

Signal flow is traced from **RHS to LHS** (source to sink):
- `assign out = in` creates edge `in -> out`
- `out <= in` creates edge `in -> out`
- Port `(.port(signal))` creates edge `signal -> port` (external to internal)

## DFS Algorithm

```
1. Build adjacency graph from all modules
2. Parse source/sink into (module, signal) pairs
3. DFS from source with visited set and depth limit
4. At each node:
   a. If node matches sink -> return path
   b. Follow all outgoing edges
   c. Record (module, signal, line, op) for each hop
5. If depth > max_depth -> "trace depth exceeded"
6. If no path found -> "path not found"
```

## Module Hierarchy Handling

### Hierarchical Signal Names

Format: `top.u_sub.u_deep.signal`

- Split on `.` to get module path and signal name
- Match module path against instance hierarchy
- If ambiguous (multiple instances), return all matching paths

### Module-Local Signal Names

Format: `module_name.signal`

- Match against module definitions in AST
- If signal appears in multiple modules, trace all paths
- Report ambiguity in results

### Port Connections

When tracing through instance boundaries:
1. Find the instance in the parent module
2. Match port name to the connected signal
3. Continue tracing inside the child module
4. Record the port connection as a hop

## Clock Domain Inference

At each hop, the tracer infers the clock domain:

1. **Explicit**: Signal name contains domain prefix (e.g., `clk_sys_*`)
2. **Context**: Signal is in an `always @(posedge clk)` block
3. **MAS**: Clock domain mapping from MAS specification
4. **Unknown**: Domain cannot be determined

A path crosses clock domains if it contains nodes from >1 unique domain
(excluding UNKNOWN).

## Cycle Detection

- Visited set tracks `(module, signal)` pairs
- If a node is revisited, the edge is skipped (no infinite loops)
- `max_depth` provides an additional safety bound

## Limitations

- **No data-flow analysis**: Only structural connectivity
- **No timing**: Path existence does not imply timing correctness
- **Generate blocks**: May miss signals inside generate-for loops
- **Conditional paths**: All branches are traced (over-approximation)
- **Multi-driven signals**: Only first assignment edge is followed

## Error Conditions

| Error | Cause | Resolution |
|-------|-------|------------|
| `path not found` | Signal names wrong or AST incomplete | Verify names, try fallback parser |
| `trace depth exceeded` | Cycle or very long chain | Increase max_depth or check for loops |
| `TRACE_FILE_MISSING` | Script failed to produce output | Check log for errors |
| Ambiguous path | Multiple instances match | Use hierarchical signal names |
