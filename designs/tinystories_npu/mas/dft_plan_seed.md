---
doc_id: DOC-D3-03-DFTPLAN
doc_type: dft_plan
title: DFT Plan Seed — tinystories_npu
version: 0.1
status: seed
parent: DOC-D3-01-MAS
generated: 2026-05-31T18:00:00+08:00
---

# DFT Plan Seed — tinystories_npu

> This is the seed DFT plan generated at MAS stage. The final DFT implementation will be performed during synthesis and PD stages.

## 1. DFT Strategy Overview

| Attribute | Target |
|-----------|--------|
| DFT Methodology | Scan-based (mux-D flip-flop) + MBIST |
| Fault Model | Stuck-at (single), transition delay |
| Scan Coverage Target | >= 95% stuck-at |
| Transition Fault Coverage | >= 85% |
| Test Compression | 10x (optional, area permitting) |
| ATPG Tool | Tetramax-compatible |

## 2. Scan Architecture

### 2.1 Scan Chain Configuration

| Parameter | Value |
|-----------|-------|
| Number of Scan Chains | 16 |
| Target Chain Length | ~5000 FF per chain |
| Total Flip-Flops | ~80,000 (estimated) |
| Scan Clock | clk_sys (50 MHz max during shift) |
| Scan Enable | scan_en (dedicated pin or JTAG-controlled) |
| Scan Input | scan_in[15:0] |
| Scan Output | scan_out[15:0] |

### 2.2 Scan Insertion Strategy

```
Module-level scan insertion:
  1. Replace all DFF with scan-D-FF (MUX-D type)
  2. Scan chains balanced across 16 chains
  3. Clock-gating cells: scan_mode → bypass clock gate
  4. Reset during scan: held inactive (rst_sys_n=1 during shift)

Test Mode Controls:
  scan_mode: 1 = scan shift, 0 = capture
  scan_en:   1 = shift, 0 = capture
  test_clk:  clk_sys (slowed to 50 MHz)
```

### 2.3 Scan Chain Partitioning

| Chain | Modules | Est. FF Count |
|-------|---------|---------------|
| Chain 0 | M00 SystolicArray | ~8000 |
| Chain 1 | M00 SystolicArray | ~8000 |
| Chain 2 | M01 DataflowController | ~5000 |
| Chain 3 | M02 SRAMScratchpad (control) | ~3000 |
| Chain 4 | M03 DRAMController (sys) | ~4000 |
| Chain 5 | M03 DRAMController (d2d) | ~4000 |
| Chain 6 | M04 SystemBus | ~6000 |
| Chain 7 | M05+M06+M07 | ~4000 |
| Chain 8 | M08 ThreadScheduler | ~5000 |
| Chain 9 | M09 AttentionUnit | ~6000 |
| Chain 10 | M10 FFNMatMul | ~5000 |
| Chain 11 | M11 RMSNormUnit | ~3000 |
| Chain 12 | M12 RoPESoftMaxUnit | ~4000 |
| Chain 13 | M13+M14 | ~5000 |
| Chain 14 | M15+M16 | ~3000 |
| Chain 15 | NPU_top (top-level glue) | ~3000 |

## 3. Memory BIST

### 3.1 MBIST Architecture

| Memory | Type | Size | Algorithm | Repair |
|--------|------|------|-----------|--------|
| M02 Bank 0 (weight ping) | SRAM | 128 KB | March C- | Column redundancy (optional) |
| M02 Bank 1 (weight pong) | SRAM | 128 KB | March C- | Column redundancy |
| M02 Bank 2 (activation) | SRAM | 128 KB | March C- | Column redundancy |
| M02 Bank 3 (KV+context) | SRAM | 128 KB | March C- | Column redundancy |
| M03 DMA FIFO (read) | Register File | 4 KB | March LR | None |
| M03 DMA FIFO (write) | Register File | 4 KB | March LR | None |
| Other register files | Flip-flop | ~40 KB | Scan test | None |

### 3.2 MBIST Controller

```
MBIST Controller (shared across M02 banks):
  - March C- algorithm:
    1. Write 0 (ascending)
    2. Read 0, Write 1 (ascending)
    3. Read 1, Write 0 (ascending)
    4. Read 0, Write 1 (descending)
    5. Read 1, Write 0 (descending)
    6. Read 0 (ascending)

  - Interface:
    bist_en: MBIST enable
    bist_done: MBIST complete
    bist_fail: Failure detected
    bist_fail_addr: Failing address
    bist_fail_data: Expected vs actual data

  - Execution:
    Triggered via JTAG IR=MBIST_RUN
    Result read via JTAG IR=MBIST_RESULT
```

## 4. JTAG DFT Integration

### 4.1 JTAG Instructions (Extended for DFT)

| IR Code | Instruction | Description |
|---------|------------|-------------|
| 0000 | BYPASS | Bypass register |
| 0001 | IDCODE | Device ID (32-bit) |
| 0010 | SAMPLE/PRELOAD | Sample I/O pins |
| 0011 | EXTEST | External test (boundary scan) |
| 0100 | INTEST | Internal test |
| 0101 | SCAN_TEST | Internal scan chain access |
| 0110 | MBIST_RUN | Run memory BIST |
| 0111 | MBIST_RESULT | Read MBIST results |
| 1000 | SCAN_CHAIN_SEL | Select scan chain for access |
| 1001 | CLAMP | Clamp I/O pins |
| 1010 | HIGHZ | Force all outputs to high-Z |

### 4.2 Boundary Scan Chain

```
Boundary scan cells at all chip I/O pins:
  - ext_clk_50MHz
  - ext_rst_por_n
  - pll_lock_ext
  - pll_pwr_en
  - irq_compute_done
  - status_sec_boot_done

Total boundary scan length: ~200 cells (est.)
```

## 5. Test Mode Constraints

### 5.1 Scan Test Constraints

| Constraint | Value | Notes |
|-----------|-------|-------|
| Scan shift frequency | <= 50 MHz | Limited by scan chain skew |
| Capture pulse width | 1 clk_sys cycle | Standard stuck-at capture |
| Capture frequency | 500 MHz (at-speed) | Transition fault test |
| scan_en setup to capture | >= 2 cycles | Prevent race condition |
| Reset during scan | Held inactive | All resets = 1 |

### 5.2 Clock Control During Test

```
Test Clock Configuration:
  - Functional: clk_sys (500 MHz), clk_io (50 MHz)
  - Scan shift: clk_sys slowed to 10-50 MHz
  - Scan capture: clk_sys at functional frequency (at-speed)
  - PLL bypassed during scan shift

  OCC (On-Chip Clock) Controller:
    - Generates at-speed capture pulses
    - Two-pulse capture for transition faults
    - Controlled via JTAG/OCC registers
```

### 5.3 Power During Test

| Domain | Scan Shift | Scan Capture |
|--------|-----------|--------------|
| VDD_MAIN | 0.7V | 0.9V |
| VDD_IO | 1.2V | 1.2V |
| VDD_AON | 0.7V | 0.7V |

## 6. ATPG Coverage Estimation

| Module | Stuck-at | Transition |
|--------|----------|------------|
| M00 SystolicArray | 96% | 88% |
| M01 DataflowController | 97% | 90% |
| M02 SRAMScratchpad (control) | 95% | 85% |
| M03 DRAMController | 94% | 85% |
| M04 SystemBus | 96% | 88% |
| M05-M07 Infrastructure | 97% | 90% |
| M08 ThreadScheduler | 96% | 88% |
| M09 AttentionUnit | 95% | 86% |
| M10 FFNMatMul | 95% | 86% |
| M11 RMSNormUnit | 96% | 88% |
| M12 RoPESoftMaxUnit | 95% | 86% |
| M13 ISADecoder | 97% | 90% |
| M14 SecureBoot | 94% | 84% |
| M15+M16 I/O | 93% | 82% |
| **Average** | **95.3%** | **86.9%** |

## 7. DFT Area Overhead

| Component | Gate Count | % of Total |
|-----------|-----------|------------|
| Scan flip-flop replacement | +15% per FF | ~2.0% of total |
| Scan chain routing | — | ~1.5% |
| MBIST controller | ~5K gates | ~0.3% |
| OCC controller | ~2K gates | ~0.1% |
| JTAG + boundary scan | ~3K gates | ~0.2% |
| Test compression (optional) | ~10K gates | ~0.5% |
| **Total DFT Overhead** | | **~4.6%** |