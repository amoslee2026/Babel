# Netgen LVS Common Pitfalls

## 1. Power Net Naming Mismatch

**Problem**: LVS reports net mismatches for VDD/VSS when schematic uses `VDD` but layout extraction produces `VDD!` or `VPWR`.

**Cause**: Different tools use different conventions for power net naming.

**Fix**:
```tcl
# In netgen setup file
equate VDD VDD! VPWR vdd
equate VSS VSS! VGND vss GND
```
- Always check power net names in both schematic netlist and extracted SPICE before running LVS.

## 2. Filler Cell Handling

**Problem**: LVS reports device count mismatches due to filler cells present in layout but not in schematic.

**Cause**: Filler cells (FILLx1, FILLx2, etc.) are physical-only; they have no schematic representation.

**Fix**:
```tcl
# Black-box filler cells in setup file
blackbox FILL*
ignore class FILL*
```
- Alternatively, add filler cells as empty subcircuits in the schematic netlist.

## 3. Decap Treatment

**Problem**: Decoupling capacitor cells cause LVS mismatch.

**Cause**: Decap cells connect VDD to VSS intentionally. Netgen sees this as a short.

**Fix**:
```tcl
# Ignore decap cells
blackbox DCAP*
# Or handle as known power connections
equate VDD VDD
```
- Decap cells should be treated as black boxes since they intentionally connect power rails.

## 4. Port Order Mismatch

**Problem**: LVS reports pin mismatch even though connectivity is correct.

**Cause**: Schematic and layout have different port ordering.

**Fix**:
```tcl
# In setup file, match ports by name not order
property default all
permute transistors
```
- Netgen matches ports by name by default; ensure port names are identical in both netlists.

## 5. Parasitic Device Count Inflation

**Problem**: Layout SPICE has many more devices than schematic.

**Cause**: Extraction captures parasitic transistors from well-edge effects or dummy gates.

**Fix**:
```tcl
# Ignore parasitic class
ignore class c
# Set minimum device size filter
property {nfet} minimum {w 0.007}
```

## 6. Multi-Bit Cell Mapping

**Problem**: Multi-bit flip-flops (e.g., DFFx2) in layout appear as multiple single-bit FFs in schematic.

**Fix**:
- Ensure the standard cell library defines the multi-bit cell correctly
- Use `flatten` in Netgen to expand hierarchical cells before comparison
- Or black-box the multi-bit cells: `blackbox DFFx2`

## 7. SPICE vs Verilog Comparison Issues

**Problem**: Netgen cannot parse Verilog netlist correctly.

**Cause**: Verilog netlist uses `assign` or `buf` primitives that Netgen does not handle well.

**Fix**:
- Use `write_verilog -noexpr` in Yosys to generate structural Verilog
- Avoid behavioral constructs in synthesis netlist
- Ensure cell instantiations use the same names as the Liberty library

## 8. Hierarchy Mismatch

**Problem**: Schematic is flat but layout is hierarchical (or vice versa).

**Fix**:
```tcl
# Flatten both sides
flatten schematic
flatten layout
```
- Or use `ext2spice hierarchy` in Magic to preserve hierarchy in extracted SPICE.

## 9. Substrate Connection Mismatches

**Problem**: Layout has explicit substrate connections (BULK pins) that schematic omits.

**Fix**:
```tcl
# Remove bulk/substrate pins from comparison
property {nfet} remove bulk
property {pfet} remove bulk
```

## 10. Report File Location

**Problem**: `lvs_report.txt` not found after Netgen completes.

**Cause**: Netgen writes the report relative to its working directory, not the script's directory.

**Fix**:
- Use absolute paths in the Netgen command
- Verify working directory matches expected path
- Check that the output directory exists before running
