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

# Phase 3: Generic synthesis (ABC deferred so dfflibmap sees generic FFs)
synth -top {top_module} -noabc

# Phase 4: Map flip-flops to the sequential library
dfflibmap -liberty {seq_lib}

# Phase 5: Combinational technology mapping via ABC
abc -liberty {tech_lib} {abc_options}

# Optional: Retiming (if enable_retiming=true)
abc -liberty {tech_lib} -script +retime

# Phase 6: Cleanup
opt_clean -purge

# Phase 7: Write netlist
write_verilog -noattr {netlist_path}

# Phase 8: Statistics (one liberty per stat call)
stat -liberty {tech_lib}
stat -liberty {seq_lib}
```

Do not append `exit 0`: Yosys has no `exit` command and aborts with
`ERROR: No such command: exit`, making every synthesis run exit non-zero.

## Command Details

| Command | Purpose | Notes |
|---------|---------|-------|
| `read_verilog -sv` | Load SystemVerilog source | Supports SV features |
| `hierarchy -check` | Validate top module | Fails if top not found |
| `synth -noabc` | Generic synthesis pass | Leaves generic `$_DFF*_` for dfflibmap |
| `dfflibmap -liberty {seq_lib}` | Map DFFs to SEQ library cells | Must use the library containing DFFs |
| `abc -liberty {tech_lib} {abc_options}` | Combinational mapping | `-script "+strash;map"` is the verified option |
| `abc -script +retime` | Retiming optimization | Moves registers across logic |
| `opt_clean -purge` | Remove unused logic | Final cleanup pass |
| `write_verilog -noattr` | Output netlist | Removes internal attributes |
| `stat -liberty` | Print statistics | One liberty per call; cells absent from that file print `area unknown` |

## ASAP7 Library Selection

ASAP7 splits cells across per-family liberty files; no single lib covers both
combinational and sequential cells:

| Purpose | Family | Published path (r28) |
|---------|--------|----------------------|
| Combinational mapping | `SIMPLE` (or `AO`/`OA`/`INVBUF`) | `<root>/LIB/NLDM/asap7sc7p5t_SIMPLE_RVT_SS_nldm_211120.lib` |
| Flip-flops (`dfflibmap`) | `SEQ` | `<root>/LIB/NLDM/asap7sc7p5t_SEQ_RVT_SS_nldm_220123.lib` |

`<root>` = `libs/asap7/asap7sc7p5t_28`. Date suffixes vary by family
(`211120`, `220122`, `220123`), so resolve by glob rather than pinning filenames.

Corner tokens: `TT` (typical), `SS` (slow), `FF` (fast); Vt tokens `RVT`/`LVT`.

## ABC Options

| Option | Effect |
|--------|--------|
| `-script "+strash;map"` | **Verified** on ASAP7 NLDM liberty (default) |
| *(no `-script`)* | Stock supergate flow `&nf` — **SIGSEGV (status 8B) on ASAP7 liberty** |
| `-g AND,OR,NAND,NOR,XOR` | Gate-only mapping — also fails (status 8B) on ASAP7 liberty |
| `-script +retime` | Enable retiming |
| `-D <ps>` | Delay target (supergate flow only; unusable while `&nf` crashes) |

`-script "+strash;map"` produces no AO/OAI composite cells, so area is a
conservative upper bound: M13_ISADecoder = 729 cells / 90.82 µm² (SS/RVT).

## Common Patterns

### Basic Synthesis
```tcl
synth -noabc
dfflibmap -liberty {seq_lib}
abc -liberty {comb_lib} -script "+strash;map"
opt_clean -purge
```

### High-Effort Synthesis
```tcl
synth -noabc
opt -fast
dfflibmap -liberty {seq_lib}
abc -liberty {comb_lib} -script "+strash;map"
opt_clean -purge
```

### Area-Optimized
```tcl
synth -noabc
dfflibmap -liberty {seq_lib}
abc -liberty {comb_lib} -script "+strash;map"
opt_clean -purge
```
