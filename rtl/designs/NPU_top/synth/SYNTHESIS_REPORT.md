# Babel NPU RTL Synthesis Report

**Date**: 2026-05-19
**Tool**: Yosys 0.65+37 (OSS CAD Suite)
**Technology**: ASAP7 7nm PDK

## Summary

| Task | Status | Details |
|------|--------|---------|
| ABC/ASAP7 Compatibility | ✓ | Workaround: abc -g basic gates |
| M12 SoftMax Fix | ✓ | Simplified 32-element, 34 cells |
| Individual Module Synthesis | ✓ | 17/17 modules pass |
| NPU_top Integration | ⏳ | Port matching in progress |
| SDC Constraints | ✓ | CLK_SYS 500MHz, multicycle paths |

## Module Synthesis Results

| Module | Description | Status |
|--------|-------------|--------|
| M00 | Systolic Array (16x16) | ✓ |
| M01 | Dataflow Controller | ✓ |
| M02 | SRAM Scratchpad | ✓ |
| M03 | DRAM Controller | ✓ |
| M04 | System Bus | ✓ |
| M05 | Power Manager | ✓ |
| M06 | Clock Manager | ✓ |
| M07 | Reset Manager | ✓ |
| M08 | Thread Scheduler | ✓ |
| M09 | Attention Unit | ✓ |
| M10 | FFN MatMul | ✓ |
| M11 | RMSNorm + RoPE | ✓ |
| M12 | SoftMax (Simplified) | ✓ |
| M13 | ISA Decoder | ✓ |
| M14 | Secure Boot | ✓ |
| M15 | JTAG Interface | ✓ |
| M16 | ISA Interface | ✓ |

## Files Generated

```
rtl/designs/NPU_top/synth/
├── netlist_NPU_top_*.v       # Synthesized netlist
├── yosys_*.log               # Synthesis logs
└── SYNTHESIS_REPORT.md       # This report

rtl/designs/NPU_top/constraints/
└── NPU_top.sdc               # Timing constraints
```

## Next Steps

1. Complete NPU_top port matching
2. Run OpenSTA timing analysis
3. PD flow: floorplan → place → route → DRC → LVS
