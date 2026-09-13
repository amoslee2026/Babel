# SDC Cheatsheet for OpenSTA

## Clock Definition

```tcl
# Basic clock
create_clock -name clk -period 2.0 [get_ports clk]

# Generated clock (divider)
create_generated_clock -name clk_div2 -source [get_ports clk] \
    -divide_by 2 [get_pins ff/Q]

# Clock uncertainty (jitter + skew)
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]

# Clock transition (slew)
set_clock_transition 0.1 [get_clocks clk]
```

## I/O Delays

```tcl
# Input delay relative to clock
set_input_delay -clock clk -max 0.5 [all_inputs]
set_input_delay -clock clk -min 0.1 [all_inputs]

# Output delay
set_output_delay -clock clk -max 0.3 [all_outputs]
set_output_delay -clock clk -min 0.0 [all_outputs]

# Exclude clock and reset ports
set_input_delay -clock clk -max 0.0 [get_ports {clk rst_n}]
```

## False Paths and Multicycle Paths

```tcl
# False path (async reset, cross-domain)
set_false_path -from [get_ports rst_n]
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# Multicycle path (e.g., 2-cycle path)
set_multicycle_path -setup 2 -from [get_cells reg_a/*] -to [get_cells reg_b/*]
set_multicycle_path -hold  1 -from [get_cells reg_a/*] -to [get_cells reg_b/*]
```

## Operating Conditions

```tcl
set_operating_conditions -analysis_type single
set_operating_conditions -analysis_type on_chip_variation
```

## Design Rule Constraints

```tcl
set_max_fanout 20 [all_inputs]
set_max_transition 0.5 [all_inputs]
set_max_capacitance 0.1 [all_inputs]
set_load 0.01 [all_outputs]
```

## Common Patterns

```tcl
# All inputs except clock
set_input_delay -clock clk -max 0.5 \
    [remove_from_collection [all_inputs] [get_ports clk]]

# Group paths for reporting
group_path -name reg2reg -from [all_registers] -to [all_registers]
group_path -name in2reg  -from [all_inputs]   -to [all_registers]
```
