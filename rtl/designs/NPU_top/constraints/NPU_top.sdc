# TinyStories NPU Timing Constraints
# Target: ASAP7 7nm PDK
# Created: 2026-05-19

# Clock Definitions
create_clock -name CLK_SYS -period 2.0 [get_ports ext_clk_50MHz]
create_clock -name CLK_AON -period 1000 [get_ports ext_clk_50MHz]
create_generated_clock -name CLK_IO -source [get_pins u_M06/clk_io_o] -divide_by 10

# Clock Groups (asynchronous)
set_clock_groups -asynchronous -group [get_clocks CLK_SYS] -group [get_clocks CLK_AON]

# Input/Output Delays
set_input_delay -clock CLK_SYS 0.1 [get_ports ext_rst_por_n]
set_input_delay -clock CLK_SYS 0.1 [get_ports pll_lock_ext]
set_output_delay -clock CLK_SYS 0.1 [get_ports pll_pwr_en]
set_output_delay -clock CLK_SYS 0.1 [get_ports irq_compute_done]

# False Paths
set_false_path -from [get_ports ext_rst_por_n]

# Multi-cycle Paths for Compute Units
set_multicycle_path -setup 8 -to [get_cells -hierarchical -filter "name=~*M00*"]
set_multicycle_path -setup 4 -to [get_cells -hierarchical -filter "name=~*M09*"]
set_multicycle_path -setup 4 -to [get_cells -hierarchical -filter "name=~*M10*"]
set_multicycle_path -setup 2 -to [get_cells -hierarchical -filter "name=~*M11*"]
set_multicycle_path -setup 2 -to [get_cells -hierarchical -filter "name=~*M12*"]

# Load Constraints (typical values for ASAP7)
set_load 0.01 [all_outputs]

# Driving Cell
set_driving_cell -lib_cell INV_X1 -pin Z [all_inputs]

# Uncertainty
set_clock_uncertainty 0.05 [all_clocks]

# Transition
set_max_transition 0.1 [current_design]
