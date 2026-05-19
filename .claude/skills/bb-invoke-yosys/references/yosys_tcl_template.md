# Yosys TCL Template Reference

## Template Structure

```tcl
# Yosys ASAP7 Synthesis Script
# Generated: {timestamp}
# Design: {design_name}
# Top: {top_module}

# Phase 1: Read RTL sources
read_verilog -sv {file1}
read_verilog -sv {file2}
...

# Phase 2: Check hierarchy
hierarchy -check -top {top_module}

# Phase 3: Generic synthesis
synth -top {top_module}

# Phase 4: Technology mapping to ASAP7
dfflibmap -liberty {tech_lib}

# Phase 5: ABC optimization
abc -liberty {tech_lib} {abc_options}

# Optional: Retiming (if enable_retiming=true)
abc -liberty {tech_lib} -script +retime

# Phase 6: Cleanup
opt_clean -purge

# Phase 7: Write netlist
write_verilog -noattr {netlist_path}

# Phase 8: Statistics
stat -liberty {tech_lib}

# Exit
exit 0
```

## Command Details

| Command | Purpose | Notes |
|---------|---------|-------|
| `read_verilog -sv` | Load SystemVerilog source | Supports SV features |
| `hierarchy -check` | Validate top module | Fails if top not found |
| `synth` | Generic synthesis pass | Includes proc, flatten, etc. |
| `dfflibmap` | Map DFFs to tech lib cells | Required for technology mapping |
| `abc` | Logic optimization + tech mapping | Uses ABC engine internally |
| `abc -script +retime` | Retiming optimization | Moves registers across logic |
| `opt_clean -purge` | Remove unused logic | Final cleanup pass |
| `write_verilog -noattr` | Output netlist | Removes internal attributes |
| `stat` | Print statistics | Includes area, cell count |

## ASAP7 Library Selection

Default: `asap7sc7p5t_AO_RVT_TT_nldm_201020.lib`

Alternative libraries for different corners:
- TT (Typical): `*_TT_nldm_*`
- SS (Slow): `*_SS_nldm_*`
- FF (Fast): `*_FF_nldm_*`

## ABC Options

| Option | Effect |
|--------|--------|
| `-g AND,OR,NAND,NOR,XOR` | Restrict gate types |
| `-K 6` | 6-input LUT mapping |
| `-luts 2,3,4` | Multi-output LUT |
| `-script +retime` | Enable retiming |

## Common Patterns

### Basic Synthesis
```tcl
synth
dfflibmap -liberty {lib}
abc -liberty {lib}
opt_clean -purge
```

### High-Effort Synthesis
```tcl
synth -run coarse
opt -fast
synth -run fine
dfflibmap -liberty {lib}
abc -liberty {lib} -K 6
abc -liberty {lib} -script +retime
opt_clean -purge
```

### Area-Optimized
```tcl
synth -run coarse
opt -fast
dfflibmap -liberty {lib}
abc -liberty {lib} -g AND,OR,NAND,NOR
opt_clean -purge
```