---
doc_id: DOC-D2-01-ARCH
doc_type: ARCH
title: Architecture Specification — Edge NPU for TinyStories Inference (tinystories_npu)
version: 1.0
status: draft
tier: 1
domain: Architecture
owner: bba-architect
approvers: [Chief Architect]
parent: DOC-D1-01-PRD
children: [DOC-D3-01-MAS]
references: [PRD.md, doc/isa/, doc/operators/, rtl/designs/NPU_top/]
generated: 2026-05-31T14:00:00+08:00
---

# Architecture Specification — Edge NPU for TinyStories Inference (tinystories_npu)

## 0. Document Control

| Version | Date       | Author         | Change |
|---------|------------|----------------|--------|
| 1.0     | 2026-05-31 | bba-architect  | Initial architecture spec from PRD v1.0 |

**Sign-off required before**: MAS v1.0

---

## 1. System Overview

### 1.1 Chip Identity

| Attribute | Value |
|-----------|-------|
| Design Name | tinystories_npu |
| Target Process | ASAP7 (7nm predictive PDK) |
| Die Area | ≤90 mm² (design target), ≤100 mm² (hard limit) |
| Package | BGA / PoP, ≤150 mm² total |
| Stacking | 3D Wafer-on-Wafer: Logic Die (ASAP7) + DRAM Die (TSV) |
| Primary Workload | TinyStories 15M parameter LLM inference |

### 1.2 Key Performance Targets

| KPI | Target | Condition |
|-----|--------|-----------|
| Peak FP8 Throughput | ≥2 TOPS | TT/0.9V, 500 MHz |
| Peak INT8 Throughput | ≥2 TOPS | TT/0.9V, 500 MHz |
| Peak FP16 Throughput | ≥1 TOPS | TT/0.9V, 500 MHz |
| Decode TPS (FP32) | ≥100 token/s | TinyStories 15M, batch=1 |
| Decode TPS (FP16) | ≥200 token/s | TinyStories 15M, batch=1 |
| TTFT | ≤50 ms | prompt ≤256 tokens |
| Core Clock | ≥500 MHz | TT/0.9V |
| TDP | ≤2 W (design: ≤1.8 W) | Peak workload, incl. DRAM |
| Idle Power | ≤0.1 W | Clock gated, power gated |

### 1.3 Architecture Philosophy

The tinystories_npu employs a **spatial dataflow architecture** built around a **Systolic Array** compute engine, optimized for Transformer model inference. Key architectural decisions:

1. **Systolic Array (weight stationary)**: Maximizes data reuse for matrix multiplications, the dominant operation in Transformer inference
2. **Spatial Dataflow Scheduler**: Orchestrates compute, memory, and I/O as a pipeline to achieve ≥80% array utilization
3. **3D Stacked DRAM**: Places 2 GB DRAM directly on top of the logic die via TSV, eliminating off-chip memory bandwidth bottleneck
4. **Multi-threaded Execution**: 2+ concurrent threads to overlap compute and memory access
5. **Mixed-Precision Pipeline**: FP32 accumulation with FP8/FP16/INT8 compute for configurable precision-energy trade-off

---

## 2. System Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         tinystories_npu Top-Level                            │
│                                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │   JTAG       │   │   ISA        │   │   Secure     │   │   Clock      │ │
│  │   I/F (M15)  │   │   I/F (M16)  │   │   Boot (M14) │   │   Manager(M06│ │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘ │
│         │                  │                  │                  │         │
│  ┌──────┴──────────────────┴──────────────────┴──────────────────┴───────┐ │
│  │                        System Bus (M04)                                │ │
│  │                  (AXI4-Lite crossbar + register bus)                   │ │
│  └──┬──────────┬──────────┬──────────┬──────────┬──────────┬────────────┘ │
│     │          │          │          │          │          │              │
│  ┌──┴──┐  ┌────┴────┐ ┌───┴───┐ ┌───┴───┐ ┌───┴───┐ ┌───┴──────────┐  │
│  │Power│  │ Reset   │ │Thread │ │ ISA   │ │ SRAM  │ │ DRAM         │  │
│  │Mgr  │  │ Mgr     │ │Sched  │ │Decoder│ │Pad    │ │Controller    │  │
│  │(M05)│  │ (M07)   │ │(M08)  │ │(M13)  │ │(M02)  │ │(M03)         │  │
│  └─────┘  └─────────┘ └───┬───┘ └───┬───┘ └───┬───┘ └──────┬───────┘  │
│                           │          │          │            │          │
│                    ┌──────┴──────────┴──────────┴────────────┘          │
│                    │                                                    │
│              ┌─────┴─────────────────────────────────────┐              │
│              │        Dataflow Controller (M01)           │              │
│              │   (Spatial dataflow orchestration)         │              │
│              └─────┬──────────────┬──────────────────────┘              │
│                    │              │                                     │
│         ┌──────────┴───┐    ┌────┴──────────────────────┐              │
│         │ Systolic     │    │    Operator Pipeline        │              │
│         │ Array (M00)  │    │ ┌──────┐┌──────┐┌───────┐ │              │
│         │ 32x32 MAC    │    │ │Attn  ││ FFN  ││RMSNorm│ │              │
│         │ FP8/FP16/INT8│    │ │(M09) ││(M10) ││(M11)  │ │              │
│         │              │    │ └──────┘└──────┘└───────┘ │              │
│         │ 2 TOPS peak  │    │ ┌──────┐┌───────┐         │              │
│         └──────────────┘    │ │RoPE  ││SoftMax│         │              │
│                             │ │(M12) ││(M12b) │         │              │
│                             │ └──────┘└───────┘         │              │
│                             └───────────────────────────┘              │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────┐       │
│  │              3D Stacked DRAM (2 GB, ≥10 GB/s)              │       │
│  │                   TSV interface to M03                      │       │
│  └────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Module Inventory

| Module ID | Name | Category | Clock Domain | Description |
|-----------|------|----------|-------------|-------------|
| M00 | SystolicArray | Compute | clk_sys (500 MHz) | 32x32 systolic array, FP8/FP16/INT8 MAC |
| M01 | DataflowController | Control | clk_sys (500 MHz) | Spatial dataflow orchestration, op dispatch |
| M02 | SRAMScratchpad | Memory | clk_sys (500 MHz) | 512 KB on-chip SRAM with ECC (SECDED) |
| M03 | DRAMController | Memory | clk_sys + clk_d2d | 3D stacked DRAM controller, TSV interface |
| M04 | SystemBus | Interconnect | clk_sys, clk_io, clk_aon | AXI4-Lite crossbar + register bus |
| M05 | PowerManager | Infrastructure | clk_aon (32 kHz) | DVFS control, power gating, power state machine |
| M06 | ClockManager | Infrastructure | ext_clk, clk_sys, clk_aon | PLL, clock gating, frequency scaling |
| M07 | ResetManager | Infrastructure | clk_aon (32 kHz) | POR sequencing, multi-domain reset control |
| M08 | ThreadScheduler | Control | clk_sys (500 MHz) | Multi-thread dispatch, ≥2 concurrent threads |
| M09 | AttentionUnit | Compute | clk_sys (500 MHz) | Multi-head attention (QKV projection + score) |
| M10 | FFNMatMul | Compute | clk_sys (500 MHz) | Feed-forward network matrix multiplications |
| M11 | RMSNormUnit | Compute | clk_sys (500 MHz) | Root Mean Square Normalization |
| M12 | RoPEUnit | Compute | clk_sys (500 MHz) | Rotary Position Embedding + SoftMax |
| M13 | ISADecoder | Control | clk_sys (500 MHz) | NPU custom ISA instruction decode |
| M14 | SecureBoot | Security | clk_sys (500 MHz) | Firmware signature verification, OTP key access |
| M15 | JTAGInterface | I/O | clk_io (JTAG TCK) | IEEE 1149.1 JTAG TAP controller |
| M16 | ISAInterface | I/O | clk_io | External ISA command interface, CRC check |

---

## 3. Compute Architecture

### 3.1 Systolic Array (M00)

```
                   Weight Preload (from SRAM/DRAM)
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│              Systolic Array 32×32                        │
│                                                         │
│  Activation  ┌───┐ ┌───┐ ┌───┐     ┌───┐              │
│  Stream ────►│MAC│→│MAC│→│MAC│→...→│MAC│──► Partial    │
│  (west→east) └───┘ └───┘ └───┘     └───┘    Sums       │
│              ┌───┐ ┌───┐ ┌───┐     ┌───┐              │
│              │MAC│→│MAC│→│MAC│→...→│MAC│              │
│              └───┘ └───┘ └───┘     └───┘              │
│                │     │     │         │                  │
│              ┌───┐ ┌───┐ ┌───┐     ┌───┐              │
│              │MAC│→│MAC│→│MAC│→...→│MAC│              │
│              └───┘ └───┘ └───┘     └───┘              │
│                ...   ...   ...       ...                │
│              ┌───┐ ┌───┐ ┌───┐     ┌───┐              │
│              │MAC│→│MAC│→│MAC│→...→│MAC│              │
│              └───┘ └───┘ └───┘     └───┘              │
│                                     Accumulator        │
│                                        │               │
│                                        ▼               │
│                                   Output Buffer         │
└─────────────────────────────────────────────────────────┘

Configuration (per op):
  - Precision:  FP8 (E4M3) / FP16 (IEEE 754) / INT8
  - Mode:       Weight Stationary (weights preloaded, activations streamed)
  - Dimensions: Up to 32×32 per tile; tiling for larger matrices
  - Accumulator: FP32 (for numerical stability)
```

**Key Design Decisions:**
- **Weight Stationary**: Minimizes weight movement during inference — weights are loaded once per layer
- **FP32 Accumulator**: Prevents numerical drift in deep networks; final result cast to target precision
- **32×32 Array Size**: Balances throughput (1024 MAC/cycle) vs. area; systolic interconnect scales poorly beyond 32

**Performance:**
- 32×32 × 2 (MAC/cycle) × 500 MHz = 1.024 TMAC/s (TOPS for MAC-only)
- FP8: 2 TOPS (each FP8 MAC = 1 op, 1024 × 500M × 4 lanes ≈ 2T)
- FP16: 1 TOPS (each FP16 MAC = 1 op, 1024 × 500M × 2 lanes ≈ 1T)
- INT8: 2 TOPS (each INT8 MAC = 1 op, 1024 × 500M × 4 lanes ≈ 2T)

### 3.2 Spatial Dataflow (M01)

The DataflowController implements a **spatial dataflow** that maps the Transformer layer computation graph onto the hardware:

```
Layer Pipeline (4 stages):
┌─────────┐    ┌─────────┐    ┌──────────┐    ┌─────────┐
│ Stage 0 │───►│ Stage 1 │───►│ Stage 2  │───►│ Stage 3 │
│ RMSNorm │    │ QKV Proj │    │ Attention│    │ FFN     │
│ (M11)   │    │ (M00)    │    │ (M09)    │    │ (M10)   │
└─────────┘    └─────────┘    └──────────┘    └─────────┘
     │              │               │               │
     └──────────────┴───────────────┴───────────────┘
                    Pipeline utilization target: ≥80%
```

**Scheduling Policy:**
- **Prefill phase**: Process all prompt tokens in batch through RMSNorm → QKV → Attention → FFN
- **Decode phase**: Process single token; reuse KV cache from previous tokens
- **Double-buffering**: Overlap DRAM reads with compute using ping-pong SRAM buffers
- **Thread interleaving**: M08 ThreadScheduler dispatches ≥2 threads to overlap compute-bound (Attention) and memory-bound (FFN weight load) operations

### 3.3 Operator Pipeline

| Operator | Module | Implementation | Precision Support |
|----------|--------|---------------|-------------------|
| MatMul (QKV, FFN) | M00 | Systolic Array, 32×32 tile | FP8, FP16, INT8 |
| Attention Score | M09 | Scaled dot-product, softmax | FP16, FP32 |
| RMSNorm | M11 | Element-wise sqrt-mean-square | FP16, FP32 |
| RoPE | M12 | Rotary position embedding (sin/cos LUT) | FP16 |
| SoftMax | M12 | Online softmax with FP32 accum | FP16, FP32 |
| FFN (Gate+Up+Down) | M10 | Three MatMul passes + SiLU gate | FP8, FP16 |
| Residual Add | M01/M09 | Element-wise add, fused with next op | FP16, FP32 |

---

## 4. Memory Architecture

### 4.1 Memory Hierarchy

```
┌──────────────────────────────────────────────────────┐
│  Level 3: 3D Stacked DRAM (2 GB, ≥10 GB/s)          │
│  - Model weights (~60 MB FP32, ~30 MB FP16)          │
│  - KV cache (up to 2048 tokens)                       │
│  - Firmware image                                     │
├──────────────────────────────────────────────────────┤
│  Level 2: On-chip SRAM Scratchpad (512 KB)           │
│  - Weight tiles (double-buffered, 256 KB per buffer)  │
│  - Activation buffer (128 KB)                         │
│  - KV cache working set (64 KB)                       │
│  - Thread context (64 KB)                             │
├──────────────────────────────────────────────────────┤
│  Level 1: Register Files (per-module)                 │
│  - Systolic Array accumulators (FP32, 4 KB)          │
│  - Operator-local scratch (varies)                    │
├──────────────────────────────────────────────────────┤
│  Level 0: OTP/ROM                                      │
│  - Secure boot key (256-bit)                          │
│  - Device ID / fuse map                               │
└──────────────────────────────────────────────────────┘
```

### 4.2 SRAM Scratchpad (M02)

| Attribute | Value |
|-----------|-------|
| Total Capacity | 512 KB |
| Organization | 4 banks × 128 KB |
| Data Width | 256-bit per bank (1024-bit aggregate) |
| Read Bandwidth | 64 GB/s @ 500 MHz (1024-bit × 500M) |
| ECC | SECDED (8-bit ECC per 64-bit data) |
| Access Pattern | Software-managed scratchpad (no cache coherence) |

**Banking Strategy:**
- Bank 0: Weight buffer A (ping)
- Bank 1: Weight buffer B (pong)
- Bank 2: Activation buffer
- Bank 3: KV cache workspace + Thread context

### 4.3 DRAM Controller (M03)

| Attribute | Value |
|-----------|-------|
| Interface | Custom D2D PHY via TSV (not standard LPDDR4X PHY) |
| Aggregate Bandwidth | ≥10 GB/s (read + write) |
| Read Latency | ≤100 ns (row hit) |
| Data Width | 128-bit D2D bus @ 625 MHz DDR → 10 GB/s |
| Addressing | 32-bit physical address (4 GB addressable) |
| ECC | SECDED on data path |

**DRAM Address Map:**
```
0x0000_0000 ─ 0x0FFF_FFFF : Firmware / Boot ROM image (256 MB)
0x1000_0000 ─ 0x1FFF_FFFF : Model Weights (256 MB)
0x2000_0000 ─ 0x3FFF_FFFF : KV Cache (512 MB)
0x4000_0000 ─ 0x7FFF_FFFF : Reserved / Scratch (1 GB)
```

### 4.4 Memory Map (System Address Space)

| Start Address | End Address | Size | Target | Access |
|---------------|-------------|------|--------|--------|
| 0x0000_0000 | 0x0FFF_FFFF | 256 MB | DRAM (Firmware) | R/W |
| 0x1000_0000 | 0x1FFF_FFFF | 256 MB | DRAM (Weights) | R/W |
| 0x2000_0000 | 0x3FFF_FFFF | 512 MB | DRAM (KV Cache) | R/W |
| 0x4000_0000 | 0x7FFF_FFFF | 1 GB | DRAM (Scratch) | R/W |
| 0xF000_0000 | 0xF000_0FFF | 4 KB | M05 PowerManager CSR | R/W |
| 0xF000_1000 | 0xF000_1FFF | 4 KB | M06 ClockManager CSR | R/W |
| 0xF000_2000 | 0xF000_2FFF | 4 KB | M07 ResetManager CSR | R/W |
| 0xF000_3000 | 0xF000_3FFF | 4 KB | M08 ThreadScheduler CSR | R/W |
| 0xF000_4000 | 0xF000_4FFF | 4 KB | M01 DataflowController CSR | R/W |
| 0xF000_5000 | 0xF000_5FFF | 4 KB | M03 DRAMController CSR | R/W |
| 0xF000_6000 | 0xF000_6FFF | 4 KB | M14 SecureBoot CSR | R/W |
| 0xF000_7000 | 0xF000_7FFF | 4 KB | M13 ISADecoder CSR | R/W |
| 0xF000_8000 | 0xF000_8FFF | 4 KB | M15 JTAGInterface CSR | R/W |
| 0xF000_9000 | 0xF000_9FFF | 4 KB | M16 ISAInterface CSR | R/W |
| 0xF800_0000 | 0xFBFF_FFFF | 64 MB | M02 SRAM (direct access) | R/W |

---

## 5. Clock and Reset Architecture

### 5.1 Clock Domains

| Domain | Frequency | Source | Modules | Gating |
|--------|-----------|--------|---------|--------|
| clk_sys | 500 MHz (nominal) | PLL (M06) | M00, M01, M02, M03(sys), M04(sys), M08, M09, M10, M11, M12, M13, M14 | Per-module ICG |
| clk_io | 50 MHz | PLL div /10 | M04(io), M15, M16 | Module-level |
| clk_aon | 32 kHz | Internal RC | M05, M06(aon), M07, M04(aon) | Always-on |
| clk_d2d | 625 MHz DDR | PLL (M06) | M03(d2d PHY) | Power-gated with DRAM |

### 5.2 Clock Distribution

```
                    ext_clk (25 MHz, external oscillator)
                        │
                        ▼
              ┌──────────────────┐
              │   PLL (M06)      │
              │   VCO: 1-2 GHz   │
              │   Div: /2 → 500  │
              │   Div: /10 → 50  │
              └───┬──────┬───────┘
                  │      │
          clk_sys │      │ clk_io
          (500MHz)│      │ (50MHz)
                  ▼      ▼
    ┌─────────────────────────────────┐
    │       Clock Gating Tree         │
    │  (per-module ICG cells in M06)  │
    └─────────────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
  M00-M03,     M04(sys)     M15, M16
  M08-M14

    Internal RC (32 kHz)
        │
        ▼
    clk_aon → M05, M06(aon), M07, M04(aon)
```

### 5.3 CDC Strategy

| Crossing | From | To | Method | Rationale |
|----------|------|----|--------|-----------|
| clk_sys → clk_io | M04 | M15/M16 | 2-stage sync (single-bit) / Async FIFO (data) | Standard async domain |
| clk_io → clk_sys | M15/M16 | M04 | 2-stage sync / Async FIFO | Standard async domain |
| clk_sys → clk_aon | M05(DVFS) | M06(PLL) | Handshake (req/ack) | DVFS command path, low rate |
| clk_aon → clk_sys | M05/M06/M07 | Main domain | 2-stage sync | Status/control signals |
| clk_sys → clk_d2d | M03(sys) | M03(d2d) | Async FIFO (M03 internal) | DRAM data path, high throughput |

### 5.4 Reset Architecture

**Reset Sources (priority order):**
1. POR (Power-On Reset) — external pin, active low
2. WDT Reset — internal watchdog timer
3. SW Reset — software-triggered via CSR

**Reset Domains:**

| Domain | Reset Signal | Source | Release Condition |
|--------|-------------|--------|-------------------|
| rst_aon_n | Always-On domain | POR | clk_aon stable + POR de-asserted |
| rst_sys_n | Main system domain | M07 sequencer | PLL locked + clk_sys stable + rst_aon_n released |
| rst_io_n | I/O domain | M07 sequencer | clk_io stable + rst_sys_n released |
| rst_por_n | Global POR | External pin | VDD stable |

**Reset Sequence (M07):**
```
POR Assert ─► rst_por_n=0 ─► [100 µs debounce] ─► rst_por_n=1
  │
  ├─ rst_aon_n=0 ─► [clk_aon stable, 1ms] ─► rst_aon_n=1
  │    │
  │    └─► Secure Boot (M14) ─► [firmware verified]
  │           │
  │           └─► PLL enable (M06) ─► [PLL lock, 100µs]
  │                  │
  │                  └─► rst_sys_n=0 ─► [clk_sys stable, 16 cycles] ─► rst_sys_n=1
  │                         │
  │                         └─► rst_io_n=0 ─► [clk_io stable, 16 cycles] ─► rst_io_n=1
  │                                │
  │                                └─► [CPU/ISA boot, firmware runtime]
```

---

## 6. Power Architecture

### 6.1 Power Domains

| Domain | Voltage | Modules | Max Power | Control |
|--------|---------|---------|-----------|---------|
| VDD_AON | 0.7V (always-on) | M05, M06(aon), M07, M04(aon) | 5 mW | Always on |
| VDD_MAIN | 0.7-0.9V (DVFS) | M00, M01, M02, M03(sys), M04(sys), M08, M09, M10, M11, M12, M13, M14 | 1.7 W peak | Power gating + DVFS |
| VDD_IO | 1.2V (fixed) | M04(io), M15, M16 | 50 mW | Module-level gating |
| VDD_DRAM | 1.1V (DRAM supply) | M03(d2d PHY) + DRAM die | 100 mW | Power gating with dram |

**Total budget distribution (1.8W design target):**
- VDD_MAIN compute: ~1.5 W (Systolic Array + operators)
- VDD_MAIN SRAM: ~100 mW
- VDD_DRAM: ~100 mW
- VDD_IO: ~50 mW
- VDD_AON: ~5 mW
- Margin: ~45 mW (2.5%)

### 6.2 Power States

| State | clk_sys | clk_io | clk_aon | VDD_MAIN | VDD_DRAM | Power | Wake Latency |
|-------|---------|--------|---------|----------|----------|-------|-------------|
| ACTIVE | 500 MHz | 50 MHz | 32 kHz | 0.9V | 1.1V | ≤1.8 W | — |
| DVFS_LOW | 250 MHz | 50 MHz | 32 kHz | 0.7V | 1.1V | ~0.8 W | 10 µs |
| IDLE | Gated | 50 MHz | 32 kHz | 0.7V | Self-refresh | ≤0.1 W | 100 µs |
| SLEEP | Off | Off | 32 kHz | Power-gated | Power-gated | ≤5 mW | 1 ms |

### 6.3 DVFS (M05 + M06)

```
DVFS operation sequence:
  1. ThreadScheduler (M08) detects idle or requests performance change
  2. M05 sends DVFS command via clk_aon handshake
  3. M06 acknowledges, begins frequency ramp
  4. M05 ramps VDD_MAIN voltage via external VRM (vdd_main_set)
  5. PLL re-locks at new frequency (if frequency change)
  6. M06 signals dvfs_ack → system resumes

Supported DVFS points:
  - (0.9V, 500 MHz) — Peak performance
  - (0.7V, 250 MHz) — Power efficient
```

### 6.4 Clock Gating Coverage

| Level | Coverage Target | Implementation |
|-------|----------------|----------------|
| Module | 100% (all 17 modules) | ICG at module clock input (M06) |
| Sub-module | ≥70% | ICG at major sub-blocks |
| Operator | On-demand | M01 DataflowController enables only active operator |

### 6.5 Isolation Cells

Cross-power-domain signals between VDD_MAIN and VDD_AON:
- All outputs from power-gated domain → isolation cells (clamp to 0) when domain is off
- Isolation enable controlled by M05 (pg_main_en)
- VDD_IO ↔ VDD_MAIN: level shifters at domain boundary

---

## 7. Interconnect Architecture (M04 SystemBus)

### 7.1 Bus Topology

```
                    ┌─────────────────────────┐
                    │     SystemBus (M04)      │
                    │   AXI4-Lite Crossbar     │
                    │                          │
  ┌─────────────┐   │  ┌───────────────────┐   │
  │ M15 JTAG    │───┼──► S0 (Debug)        │   │
  │ M16 ISA I/F │───┼──► S1 (Command)      │   │
  │ M08 Thread  │───┼──► S2 (Register R/W) │   │
  │ M14 Secure  │───┼──► S3 (Security)     │   │
  └─────────────┘   │  └───┬───┬───┬───┬───┘   │
                    │      │   │   │   │       │
                    │  ┌───┴───┴───┴───┴───┐   │
                    │  │    Address Router  │   │
                    │  └───┬───┬───┬───┬───┘   │
                    │      │   │   │   │       │
                    │  M0:SRAM M1:CSR M2:DRAM M3:Reserved │
                    └─────────────────────────┘

Protocol: AXI4-Lite (32-bit address, 32-bit data)
  - awvalid/awready, wvalid/wready, bvalid/bready (write channel)
  - arvalid/arready, rvalid/rready (read channel)
Arbitration: Round-robin with priority escalation for debug access
```

### 7.2 D2D Interconnect (M03 DRAM)

```
Logic Die (ASAP7)                              DRAM Die
┌─────────────────┐                    ┌─────────────────┐
│  M03 DRAM Ctrl  │                    │  DRAM PHY       │
│  ┌───────────┐  │     TSV bus       │  ┌───────────┐  │
│  │ D2D CMD   │──┼───────────────────┼──► CMD Decoder│  │
│  │ (addr/rw) │  │   8-bit unidir    │  └───────────┘  │
│  ├───────────┤  │                    │  ┌───────────┐  │
│  │ D2D WDATA │──┼───────────────────┼──► Write FIFO │  │
│  │ (128-bit) │  │  128-bit unidir   │  └───────────┘  │
│  ├───────────┤  │                    │  ┌───────────┐  │
│  │ D2D RDATA │◄─┼───────────────────┼──┤ Read FIFO  │  │
│  │ (128-bit) │  │  128-bit unidir   │  └───────────┘  │
│  └───────────┘  │                    │                 │
└─────────────────┘                    └─────────────────┘

D2D Interface:
  - Clock: 625 MHz DDR (bidirectional data on both edges)
  - Bandwidth: 128-bit × 625M × 2 (DDR) = 10 GB/s per direction
  - TSV count: ~280 (128 data + 8 cmd + ECC + ctrl + power/ground)
  - Latency: <5 ns TSV propagation + DRAM access
```

---

## 8. Security Architecture

### 8.1 Secure Boot Flow (M14)

```
Power-On ─► ROM Boot Code ─► Load Firmware Header from DRAM
                                  │
                                  ▼
                         Parse signature block:
                           - FW image hash (SHA-256)
                           - ECDSA signature (r, s)
                                  │
                                  ▼
                         Verify with OTP public key ────┐
                                  │                     │
                    ┌─────────────┴──────────────┐      │
                    ▼                            ▼      │
               VALID                          INVALID   │
                    │                            │      │
                    ▼                            ▼      │
              sec_status_pass=1           sec_status_fail=1
              Boot continues              Lockdown mode:
              JTAG unlocked (if dev)        - JTAG locked
                                           - ISA I/F locked
                                           - LED/error indicator
```

### 8.2 Security Features

| Feature | Implementation | Module |
|---------|---------------|--------|
| Secure Boot | ECDSA P-256 signature verification of firmware | M14 |
| OTP Key Storage | 256-bit public key hash, 64-bit device ID | M14 (OTP I/F) |
| JTAG Lock | After secure boot fail: JTAG access denied | M15 |
| ISA Lock | After secure boot fail: ISA commands rejected | M16 |
| Firmware CRC | Runtime CRC-32 check on firmware image | M16 |
| Memory ECC | SECDED on SRAM (M02) and DRAM (M03) | M02, M03 |
| Supply Chain | Device ID + OTP fuses for traceability | M14 |

### 8.3 Lifecycle States

| State | JTAG | ISA | Secure Boot | Description |
|-------|------|-----|-------------|-------------|
| TEST | Open | Open | Bypassed | Manufacturing test |
| DEV | Open | Open | Optional | Development/debug |
| PROD | Locked | Locked | Required | Production deployment |
| RMA | Unlocked (auth) | Locked | Required | Return/repair (authenticated) |

---

## 9. DFT Architecture

### 9.1 Scan Chain Strategy

| Attribute | Target |
|-----------|--------|
| Scan Coverage | ≥95% stuck-at fault coverage |
| Scan Chain Count | ~16 chains (balanced) |
| Scan Compression | 10x (optional, area permitting) |
| ATPG Tool | Tetramax-compatible flow |
| Test Clock | clk_sys (scan shift: 50 MHz max) |

### 9.2 Memory BIST

| Memory | Type | BIST Algorithm |
|--------|------|---------------|
| M02 SRAM (512 KB) | SRAM | March C- (full coverage) |
| M03 DRAM Buffer | Register file | March LR |
| Register Files (all modules) | Flip-flop | Scan test (not MBIST) |

### 9.3 JTAG (M15)

- IEEE 1149.1 compliant TAP controller
- 4-wire interface: TCK, TMS, TDI, TDO, TRST_n
- Boundary scan chain for I/O testing
- Internal scan access via TAP instructions
- Debug access control: gated by M14 secure_boot status

---

## 10. Module-to-PRD Requirement Traceability

| PRD REQ ID | Requirement | ARCH Section | Responsible Module |
|------------|-------------|-------------|-------------------|
| REQ-COMPUTE-001 | FP8 ≥2 TOPS | §3.1 | M00 SystolicArray |
| REQ-COMPUTE-002 | FP16 ≥1 TOPS | §3.1 | M00 SystolicArray |
| REQ-COMPUTE-003 | INT8 ≥2 TOPS | §3.1 | M00 SystolicArray |
| REQ-COMPUTE-004 | Systolic Array (WS/OS) | §3.1 | M00 SystolicArray |
| REQ-COMPUTE-005 | Pipeline util ≥80% | §3.2 | M01 DataflowController |
| REQ-COMPUTE-006 | ≥2 concurrent threads | §3.2 | M08 ThreadScheduler |
| REQ-COMPUTE-007 | Mixed precision (FP32/FP16/INT8) | §3.1, §3.3 | M00, M09, M10, M11, M12 |
| REQ-COMPUTE-008 | Transformer ops (Attn, FFN, RMSNorm, RoPE) | §3.3 | M09, M10, M11, M12 |
| REQ-MEM-001 | DRAM ≥2 GB | §4.1 | M03 DRAMController |
| REQ-MEM-002 | DRAM BW ≥10 GB/s | §4.3 | M03 DRAMController |
| REQ-MEM-003 | DRAM latency ≤100 ns | §4.3 | M03 DRAMController |
| REQ-MEM-004 | SRAM ≥512 KB | §4.2 | M02 SRAMScratchpad |
| REQ-MEM-005 | ECC SECDED | §4.2, §4.3 | M02, M03 |
| REQ-IO-001 | JTAG IEEE 1149.1 | §9.3 | M15 JTAGInterface |
| REQ-IO-002 | Custom NPU ISA I/F | §7.1 | M16 ISAInterface |
| REQ-PERF-001 | Core ≥500 MHz | §5.1 | M06 ClockManager |
| REQ-PERF-002 | Decode TPS ≥100 (FP32) | §3.1, §3.2 | M00, M01, M08 |
| REQ-PERF-003 | Decode TPS ≥200 (FP16) | §3.1, §3.2 | M00, M01, M08 |
| REQ-PERF-004 | TTFT ≤50 ms | §3.2 | M01, M03, M08 |
| REQ-PWR-001 | TDP ≤2W (design ≤1.8W) | §6.1 | M05 PowerManager |
| REQ-PWR-002 | Idle ≤0.1W | §6.2 | M05, M06 |
| REQ-PWR-003 | DVFS ≥2 points | §6.3 | M05, M06 |
| REQ-AREA-001 | Die ≤90 mm² (≤100 mm² hard) | §1.1 | Floorplan |
| REQ-REL-001 | MTTF ≥100k hrs @85C | §6 | All |
| REQ-REL-002 | SER ≤1000 FIT | §4.2, §8.2 | M02, M03 (ECC) |
| REQ-D2D-001 | D2D BW ≥10 GB/s | §7.2 | M03 DRAMController |
| REQ-D2D-002 | D2D protocol | §7.2 | M03 DRAMController |
| REQ-D2D-003 | D2D ≤5 pJ/bit | §7.2 | M03 + TSV PHY |
| REQ-D2D-004 | D2D latency ≤100 ns | §7.2 | M03 DRAMController |
| REQ-SEC-001 | Secure boot | §8.1 | M14 SecureBoot |
| REQ-SEC-002 | Supply chain security | §8.2, §8.3 | M14 SecureBoot |

---

## 11. Design Decisions and Tradeoffs

### ADR-001: Weight Stationary vs. Output Stationary Systolic Array
- **Decision**: Weight Stationary
- **Rationale**: Weights loaded once per layer during inference; weight stationary eliminates repeated weight reload. Output stationary would require activations to be stationary — impractical for decode phase (single token at a time)
- **Tradeoff**: Weight stationary requires larger weight SRAM (double-buffered), but area increase (128 KB per buffer) is acceptable

### ADR-002: 32×32 Array Size
- **Decision**: 32×32 systolic array
- **Rationale**: TinyStories 15M model has hidden_dim=576; 32×32 tiles maps cleanly (18 tiles/dim). Larger arrays (e.g., 64×64) would waste area for small models
- **Tradeoff**: 32×32 limits peak throughput vs. larger arrays; multi-tile execution compensates via spatial dataflow

### ADR-003: Scratchpad SRAM vs. Cache
- **Decision**: Software-managed scratchpad (no hardware cache coherence)
- **Rationale**: NPU workloads have predictable access patterns; scratchpad avoids cache miss penalties and tag overhead. Compiler/runtime manages data placement
- **Tradeoff**: Requires compiler/runtime to explicitly manage data movement; acceptable for fixed-model inference

### ADR-004: Custom D2D Interface vs. LPDDR4X PHY
- **Decision**: Custom D2D interface for TSV-based 3D stacking
- **Rationale**: TSV direct connection eliminates PCB trace parasitics; simpler PHY than LPDDR4X (no training, no DLL). 3D stacking is a primary architectural differentiator
- **Tradeoff**: Non-standard interface; DRAM die must be co-designed

### ADR-005: Single PLL vs. Multiple PLLs
- **Decision**: Single PLL with integer dividers
- **Rationale**: Only 3 clock domains needed (sys, io, aon); single PLL simplifies clock tree and reduces analog area. aon clock from internal RC
- **Tradeoff**: All frequencies integer-related to PLL output; acceptable for this design

### ADR-006: AXI4-Lite vs. Full AXI4 for System Bus
- **Decision**: AXI4-Lite (no burst support)
- **Rationale**: Control/status register access is low-bandwidth, word-sized; full AXI4 burst would add area without benefit. Bulk data movement uses dedicated datapaths (M01→M00, M03→M02)
- **Tradeoff**: Burst transfers not supported; not needed for register access

### ADR-007: FP32 Accumulator
- **Decision**: FP32 accumulator in systolic array MAC units
- **Rationale**: Prevents numerical drift in deep networks; standard practice in ML accelerators (TPU, GPU). Area cost: ~2x vs FP16 accumulator
- **Tradeoff**: Increased MAC area; justified by numerical stability requirement (PRD requires ≤0.5% accuracy loss)

### ADR-008: Online Softmax
- **Decision**: Online softmax algorithm (M12)
- **Rationale**: Avoids storing full attention matrix; computes softmax in streaming fashion. Reduces SRAM requirement for attention by O(seq_len²)
- **Tradeoff**: Slightly more complex control logic; standard approach for Transformer accelerators

---

## 12. Open Issues and Risks

| ID | Issue | Severity | Mitigation |
|----|-------|----------|------------|
| RISK-01 | DRAM die co-design not in Babel scope | HIGH | Define clean D2D interface spec; DRAM-side behavior modeled as Verilog BFMs |
| RISK-02 | TSV yield modeling for 3D stacking | MEDIUM | Assume known-good-die (KGD) flow; TSV redundancy not implemented in RTL |
| RISK-03 | Exact SRAM macro availability in ASAP7 | MEDIUM | Use behavioral SRAM model; synthesis will map to register file if macros unavailable |
| RISK-04 | PLL behavioral model fidelity | LOW | Use ideal clock for RTL sim; OpenSTA for timing sign-off with liberty corners |
| RISK-05 | FP8 (E4M3) operator verification | MEDIUM | Reference implementation in C; bba-guru-verification stage to compare |
| RISK-06 | DRAM 10 GB/s BW verification | HIGH | Requires D2D BFM with timing; test at reduced frequency if tool flow limited |

---