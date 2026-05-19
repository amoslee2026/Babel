# NPU Top-Level Module Dependency Order
# Generated: 20260518_183000
# Top Module: NPU_top
# Module count: 21 (NPU_top + 17 IP blocks + 4 M03 submodules)

# Sub-modules (M00-M16) - no interdependencies
rtl/M00/src/M00_SystolicArray.sv
rtl/M01/src/M01_DataflowController.sv
rtl/M02/src/M02_SRAMScratchpad.sv
rtl/M03/src/M03_DRAMController.sv
rtl/M04/src/M04_SystemBus.sv
rtl/M05/src/M05_PowerManager.sv
rtl/M06/src/M06_ClockManager.sv
rtl/M07/src/M07_ResetManager.sv
rtl/M08/src/M08_ThreadScheduler.sv
rtl/M09/src/M09_AttentionUnit.sv
rtl/M10/src/M10_FFNMatMul.sv
rtl/M11/src/M11_RMSNormRoPE.sv
rtl/M12/src/M12_SoftMax.sv
rtl/M13/src/M13_ISADecoder.sv
rtl/M14/src/M14_SecureBoot.sv
rtl/M15/src/M15_JTAGInterface.sv
rtl/M16/src/M16_ISAInterface.sv

# Top-level module (instantiates all M00-M16)
rtl/NPU_top.sv
