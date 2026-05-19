---
type: system_summary
status: complete
generated: "2026-05-17T18:30:00+08:00"
---

# System Power Budget

**Document Purpose**: 汇总各模块功耗预算，确保总功耗 < 1.8W (REQ-PWR-001)

---

## Summary Table

| Domain | Modules | OP0 Power (500 MHz) | OP1 Power (250 MHz) | Notes |
|--------|---------|---------------------|---------------------|-------|
| **Compute** | M00, M09-M12 | ~600 mW | ~300 mW | 主要计算功耗 |
| **Storage** | M02, M03 | ~280 mW | ~140 mW | SRAM + DRAM 控制器 |
| **Control** | M01, M05-M08, M13-M14 | ~200 mW | ~100 mW | 控制逻辑 + 安全模块 |
| **IO** | M15, M16 | ~30 mW | ~15 mW | JTAG + ISA 接口 |
| **Total** | **17 modules** | **~1.1 W** | **~0.55 W** | **Margin: 38%** |

---

## Module-Level Breakdown

### Compute Domain (PD_MAIN)

| Module | OP0 Power | OP1 Power | Power Model | REQ Reference |
|--------|-----------|-----------|-------------|---------------|
| M00 Systolic Array | ~500 mW | ~250 mW | Activity × 128×128 PE × MAC_power | REQ-COMPUTE-001 |
| M09 Attention Unit | ~60 mW | ~30 mW | Score compute + KV cache access | REQ-COMPUTE-008 |
| M10 FFN Unit | ~20 mW | ~10 mW | 3 MatMul + Sigmoid | REQ-COMPUTE-008 |
| M11 RMSNorm+RoPE | ~15 mW | ~7.5 mW | Norm compute + position encoding | REQ-COMPUTE-008 |
| M12 SoftMax Unit | ~5 mW | ~2.5 mW | Max + Exp + Normalize | REQ-COMPUTE-008 |

### Storage Domain (PD_MAIN + PD_IO)

| Module | OP0 Power | OP1 Power | Power Model | REQ Reference |
|--------|-----------|-----------|-------------|---------------|
| M02 SRAM Scratchpad | ~200 mW | ~100 mW | 512 KB SRAM + ECC + Arbitration | REQ-MEM-002, REQ-MEM-004 |
| M03 DRAM Controller | ~80 mW | ~40 mW | 3D Stacked D2D PHY + Controller | REQ-MEM-001 |

### Control Domain (PD_MAIN + PD_AON)

| Module | OP0 Power | OP1 Power | Power Model | Notes |
|--------|-----------|-----------|-------------|-------|
| M01 Thread Scheduler | ~50 mW | ~25 mW | Dispatch + Context management | 2-4 threads |
| M05 Power Manager | ~7 mW (AON) | ~7 mW | Always-on domain | 不受 DVFS 影响 |
| M06 Clock Manager | ~30 mW | ~15 mW | PLL + Clock gating | DVFS latency ~200 us |
| M07 Reset Manager | ~20 mW | ~10 mW | Reset sequence + WDT | |
| M08 Barrier Controller | ~10 mW | ~5 mW | Barrier sync + Thread coordination | |
| M13 ISA Decoder | ~50 mW | ~25 mW | 32 指令 decode + Dispatch | |
| M14 Secure Boot | ~20 mW | ~10 mW | SHA-256/ECDSA + OTP interface | Boot 时激活 |

### IO Domain (PD_IO)

| Module | OP0 Power | OP1 Power | Notes |
|--------|-----------|-----------|-------|
| M15 JTAG Debug | ~15 mW | ~7.5 mW | TAP controller + Scan chain |
| M16 ISA Interface | ~15 mW | ~7.5 mW | CDC bridge + Tri-state buffer |

---

## Power Budget Verification

### REQ-PWR-001 Compliance

| Requirement | Target | Actual (OP0) | Actual (OP1) | Status |
|-------------|--------|---------------|---------------|--------|
| Total Power | < 1.8 W | ~1.1 W | ~0.55 W | ✓ PASS |
| Margin | >= 20% | 38% | 69% | ✓ PASS |
| Peak Power | < 2.0 W | ~1.3 W (worst) | - | ✓ PASS |

---

## References

- REQ-PWR-001: Total power < 1.8 W
- REQ-PWR-002: DVFS support
- Module MAS.md: 各模块详细功耗分析