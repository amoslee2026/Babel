# ABC Pitfalls

## Liberty Format Incompatibility

**Problem**: ABC expects Liberty (.lib) or `.genlib` format but may fail on
certain constructs: complex `timing_sense`, multi-bit buses, non-standard pg_pin.

**Symptoms**:
- "Error reading library file"
- Missing cells in mapping results
- Segmentation fault on library read

**Fix**:
- Use `read_lib -m asap7.genlib` (genlib format preferred)
- Strip unsupported attributes with preprocessor
- Use simplified Liberty (gate-level only, no analog)

**Detection**: Check ABC log for library parse errors before mapping.

## Buffer Tree Explosion

**Problem**: After technology mapping, ABC inserts excessive buffer chains
to meet timing constraints, inflating area and gate count.

**Symptoms**:
- `buf` gate count >> logic gate count
- Area increase after `map -m`

**Fix**:
- Use `buffer -N 4` to limit buffer fanout
- Apply `resyn2` after mapping to clean up
- Relax timing with higher `set_delay`
- Use `map -a` for area-focused mapping

## Retiming Across Registers

**Problem**: `retime` moves flip-flops through combinational logic, potentially
breaking initial value semantics or scan chain ordering.

**Fix**:
- Verify functional equivalence: `cec <original> <retimed>`
- Preserve scan chain order in DEF
- Add `set_reset` attributes to critical FFs

**Detection**: Run `cec` (Combinational Equivalence Checking) after retime.

## Input Format Limitations

**Problem**: ABC reads BLIF, Verilog, PLA but:
- SystemVerilog constructs not supported
- Parameterized modules must be elaborated first
- Black box modules cause mapping failures

**Fix**: Use Yosys to elaborate first: `yosys -p "synth; write_blif"`

## Timing Constraint Units

**Problem**: ABC uses picoseconds (ps) internally but Liberty may use ns.

**Fix**: Verify `time_unit` attribute. Common ASAP7: 500ps = 0.5ns.

## Area vs Delay Trade-off

`map -a` optimizes area; `map -d` optimizes delay. Blindly using default may
violate timing. Always specify mapping objective explicitly.

## Clock Gating Cells

ABC doesn't understand clock gating semantics. ICG cells may be optimized away.
Mark them as `dont_touch` before ABC optimization.

## Memory Usage on Large Designs

**Problem**: `resyn3` and `strash` consume significant memory on designs > 50K
gates. AIG may be 5-10x larger than netlist.

**Fix**: Use `resyn2` for large designs, or partition hierarchically.
