# ABC Logic Optimization Pitfalls

## 1. Liberty File Mismatch
ABC uses `.genlib` format, not Liberty. Must convert: `read_lib -m asap7.genlib`

## 2. Technology Mapping After Optimization
Running `strash` without subsequent `map` leaves gates unmapped to target library.

## 3. Area vs Delay Trade-off
`map -a` optimizes area; `map -d` optimizes delay. Blindly using default may violate timing.

## 4. Multi-output Optimization
ABC may merge outputs aggressively, breaking module boundaries. Use `&get -n` to preserve.

## 5. Clock Gating Cells
ABC doesn't understand clock gating semantics. ICG cells may be optimized away.

## 6. Sequential Depth
`fold`/`unfold` operations on FSMs > 16 states can explode runtime.
