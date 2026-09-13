# Coverage Naming Conventions

## Coverage Groups: `<module>_<feature>_cg`
Examples: `alu_arithmetic_cg`, `fifo_overflow_cg`, `pcie_tlp_format_cg`

## Coverage Points: `<signal>_<aspect>_cp`
Examples: `opcode_type_cp`, `addr_alignment_cp`, `burst_length_cp`

## Coverage Bins: `<value_or_range>_bin`
Examples: `read_bin`, `write_bin`, `addr_4k_boundary_bin`

## Cross Coverage: `<point1>_x_<point2>_cross`
Examples: `opcode_x_operand_cross`, `state_x_input_cross`

## Rules
1. Use lowercase with underscores
2. Be descriptive - name should indicate what is covered
3. Include module name for context
4. Avoid abbreviations except common ones (clk, rst, addr)
5. Group related items with common prefix

## SystemVerilog Example
```systemverilog
covergroup alu_operations_cg @(posedge clk);
    opcode_cp: coverpoint opcode {
        bins add_bin = {ADD};
        bins sub_bin = {SUB};
        bins mul_bin = {MUL};
    }
    opcode_x_overflow: cross opcode_cp, overflow_flag;
endgroup
alu_operations_cg alu_cov = new();
```

## In Verification Plans
Reference coverage as: `Coverage Goal: alu_arithmetic_cg >= 95%`
