# Yosys Synthesis Script for NPU_top
# Generated: 20260518_194302
# Top Module: NPU_top
# Technology: ASAP7 7.5-track LVT TT corner

# Read all RTL files from file_list
read_verilog -sv rtl/M00/src/M00_SystolicArray.sv
read_verilog -sv rtl/M01/src/M01_DataflowController.sv
read_verilog -sv rtl/M02/src/M02_SRAMScratchpad.sv
read_verilog -sv rtl/M03/src/M03_DRAMController.sv
read_verilog -sv rtl/M04/src/M04_SystemBus.sv
read_verilog -sv rtl/M05/src/M05_PowerManager.sv
read_verilog -sv rtl/M06/src/M06_ClockManager.sv
read_verilog -sv rtl/M07/src/M07_ResetManager.sv
read_verilog -sv rtl/M08/src/M08_ThreadScheduler.sv
read_verilog -sv rtl/M09/src/M09_AttentionUnit.sv
read_verilog -sv rtl/M10/src/M10_FFNMatMul.sv
read_verilog -sv rtl/M11/src/M11_RMSNormRoPE.sv
read_verilog -sv rtl/M12/src/M12_SoftMax.sv
read_verilog -sv rtl/M13/src/M13_ISADecoder.sv
read_verilog -sv rtl/M14/src/M14_SecureBoot.sv
read_verilog -sv rtl/M15/src/M15_JTAGInterface.sv
read_verilog -sv rtl/M16/src/M16_ISAInterface.sv
read_verilog -sv rtl/NPU_top.sv

# Check hierarchy
hierarchy -check -top NPU_top

# Generic synthesis
synth -top NPU_top

# Optimize
opt
opt_clean -purge

# Technology mapping with ABC
abc -liberty /home/lxx/wrk/libs/asap7_reference_design/lib/asap7sc7p5t_AO_LVT_TT_nldm_211120.lib -g AND,OR,NAND,NOR,XOR

# Clean up
opt_clean -purge

# Write netlist
write_verilog -noattr rtl/designs/NPU_top/synth/netlist_20260518_194302.v

# Statistics
stat -liberty /home/lxx/wrk/libs/asap7_reference_design/lib/asap7sc7p5t_AO_LVT_TT_nldm_211120.lib

# Exit
exit
