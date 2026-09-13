# SDC Creation Pitfalls

## Common Issues

### 1. Virtual Clock Port Mismatch
`create_clock` must reference an existing port or be declared as virtual (no port).
Referencing a non-existent port causes OpenSTA parse errors.

### 2. Generated Clock Missing Master
`create_generated_clock` requires `-master_clock` pointing to an existing clock.
Missing master clock causes the generated clock to be ignored silently.

### 3. Clock Group Overlap
A clock must belong to exactly one `-group` in `set_clock_groups`. Listing a clock
in multiple groups causes undefined behavior in timing analysis.

### 4. IO Delay on Clock Ports
`set_input_delay` / `set_output_delay` should not be applied to clock ports.
Clock ports use `create_clock` timing. Applying IO delay to clocks creates
conflicting constraints.

### 5. False Path Overconstraint
`set_false_path` completely removes timing analysis on the path. Overusing it
hides real timing violations. Use `set_max_delay` for CDC paths instead.

### 6. Missing Reset False Paths
Asynchronous reset signals must have `set_false_path` from the reset port.
Without it, timing tools try to meet timing on reset assertion paths, which
are inherently asynchronous.

### 7. Multicycle Path Hold Constraint
When setting `set_multicycle_path N -setup`, also set the corresponding hold
constraint: `set_multicycle_path N-1 -hold`. Missing hold constraint causes
hold violations on multicycle paths.

### 8. Clock Uncertainty Order
`set_clock_uncertainty` must come after `create_clock`. Setting uncertainty
before clock creation has no effect.
