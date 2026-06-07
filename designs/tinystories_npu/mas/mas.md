---
doc_id: DOC-D3-01-MAS
doc_type: MAS
title: Micro-Architecture Specification — Edge NPU for TinyStories Inference (tinystories_npu)
version: 1.0
status: draft
tier: 2
domain: Micro-Architecture
owner: bba-architect
approvers: [Chief Architect, RTL Lead]
parent: DOC-D2-01-ARCH
children: null
references: [PRD.md, arch_spec/arch_doc.md, arch_spec/data_flow.md, arch_spec/workflow.md, rtl/designs/NPU_top/]
generated: 2026-05-31T18:00:00+08:00
---

# Micro-Architecture Specification — tinystories_npu

## 0. Document Control

| Version | Date       | Author         | Change |
|---------|------------|----------------|--------|
| 1.0     | 2026-05-31 | bba-architect  | Initial MAS from ARCH v1.0; 19 modules (M00-M16 + M11 split, M12 redefined) |

**Sign-off required before**: RTL coding (bba-guru-rtl)

---

## 1. System Overview

### 1.1 Design Identity

| Attribute | Value |
|-----------|-------|
| Design Name | tinystories_npu |
| Top Module | NPU_top |
| Target Process | ASAP7 (7nm predictive PDK) |
| Core Clock (clk_sys) | 500 MHz |
| I/O Clock (clk_io) | 50 MHz |
| Always-On Clock (clk_aon) | 32 kHz |
| D2D Clock (clk_d2d) | 625 MHz DDR |
| Design Area Target | <= 90 mm^2 (hard limit: 100 mm^2) |
| Power Budget | <= 1.8 W (TDP <= 2.0 W) |
| SRAM Budget | 512 KB on-chip |
| DRAM Budget | 2 GB 3D-stacked |
| Precision | FP8 (E4M3), FP16 (IEEE 754), INT8, FP32 (accum) |

### 1.2 Architecture Philosophy

The tinystories_npu is a **spatial dataflow accelerator** optimized for Transformer model inference. Key micro-architectural principles:

1. **Weight Stationary Systolic Array** -- weights preloaded once per layer, activations streamed; minimizes weight movement
2. **Spatial Pipeline** -- 4-stage Transformer layer pipeline (RMSNorm -> QKV Proj -> Attention -> FFN) with >= 80% utilization target
3. **Double-Buffered SRAM** -- ping-pong weight buffers enable compute/memory overlap
4. **Multi-Threaded Dispatch** -- >= 2 concurrent threads to overlap compute-bound and memory-bound operations
5. **Streaming Dataflow** -- operators connected via valid/ready handshake; no centralized buffer for operator-to-operator data

---

## 2. Complete Module List

### 2.1 Module Inventory

<!-- REQ-COMPUTE-001 through REQ-SEC-002 -->

| ID | Module Name | Category | Clock Domain | RTL File | Description |
|----|------------|----------|-------------|----------|-------------|
| M00 | SystolicArray | compute | clk_sys | M00_SystolicArray.sv | 32x32 weight-stationary systolic array, FP8/FP16/INT8 MAC, FP32 accum |
| M01 | DataflowController | control | clk_sys | M01_DataflowController.sv | Spatial dataflow orchestration, op dispatch, pipeline stage sequencing |
| M02 | SRAMScratchpad | storage | clk_sys | M02_SRAMScratchpad.sv | 512 KB on-chip SRAM, 4 banks, SECDED ECC, 1024-bit aggregate read |
| M03 | DRAMController | storage | clk_sys + clk_d2d | M03_DRAMController.sv | 3D stacked DRAM controller, TSV D2D PHY, DMA engine, 10 GB/s |
| M04 | SystemBus | interconnect | clk_sys, clk_io, clk_aon | M04_SystemBus.sv | AXI4-Lite crossbar + TileLink CSR bus + AXI4 DRAM bus |
| M05 | PowerManager | infrastructure | clk_aon | M05_PowerManager.sv | DVFS control, power gating, 4 power state FSM, isolation control |
| M06 | ClockManager | infrastructure | ext_clk, clk_sys, clk_aon | M06_ClockManager.sv | PLL control, clock gating tree, frequency scaling, clock dividers |
| M07 | ResetManager | infrastructure | clk_aon | M07_ResetManager.sv | POR sequencing, multi-domain reset, WDT, reset status capture |
| M08 | ThreadScheduler | control | clk_sys | M08_ThreadScheduler.sv | Multi-thread dispatch (>=2 threads), priority RR, resource arbitration |
| M09 | AttentionUnit | compute | clk_sys | M09_AttentionUnit.sv | Multi-head attention: QKV aggregation, scaled dot-product, KV cache R/W |
| M10 | FFNMatMul | compute | clk_sys | M10_FFNMatMul.sv | FFN: gate/up/down projections, SiLU activation, residual add |
| M11 | RMSNormUnit | compute | clk_sys | M11_RMSNormUnit.sv | Root Mean Square Normalization: gamma multiply, sqrt-mean-square |
| M12 | RoPESoftMaxUnit | compute | clk_sys | M12_RoPESoftMaxUnit.sv | Rotary Position Embedding (sin/cos LUT) + Online SoftMax (FP32 accum) |
| M13 | ISADecoder | control | clk_sys | M13_ISADecoder.sv | NPU custom ISA instruction decode, command dispatch to M08 |
| M14 | SecureBoot | security | clk_sys | M14_SecureBoot.sv | ECDSA P-256 firmware verification, OTP key access, lifecycle FSM |
| M15 | JTAGInterface | io | clk_io | M15_JTAGInterface.sv | IEEE 1149.1 JTAG TAP controller, boundary scan, debug access |
| M16 | ISAInterface | io | clk_io | M16_ISAInterface.sv | External ISA command interface, CRC-32 check, security gate |

**Total: 17 modules** (M00-M16). Note: The previous RTL generation had M11 as "RMSNormRoPE" (combined) and M12 as "SoftMax". The current ARCH spec splits these into separate M11 (RMSNorm) and M12 (RoPE + SoftMax). This is a **new RTL development** -- M11 and M12 must be created from scratch.

### 2.2 Module Dependency Graph

```
                    ┌──────────────────────────────────────────────────────┐
                    │                    NPU_top                            │
                    │                                                      │
   ext_clk ─────────┼──► M06_ClockManager ──► clk_sys, clk_io, clk_aon     │
   ext_rst ─────────┼──► M07_ResetManager ──► rst_sys_n, rst_io_n, rst_aon │
                    │                                                      │
   ISA CMD ─────────┼──► M16_ISAInterface ──► M13_ISADecoder               │
   JTAG   ─────────┼──► M15_JTAGInterface                                  │
                    │                                                      │
                    │   M14_SecureBoot ──► sec_status → M15, M16           │
                    │   M05_PowerManager ──► pg_en, dvfs → M06, all mods   │
                    │                                                      │
                    │                    ┌─ M04_SystemBus ─────────────────┐│
                    │                    │  (AXI4-Lite + TileLink + AXI4)  ││
                    │   M08_ThreadSched ─┤                                ││
                    │   M13_ISADecoder ──┤                                ││
                    │   M15_JTAG ────────┤                                ││
                    │   M16_ISA ────────┤                                ││
                    │                    │  ┌── M02_SRAMScratchpad         ││
                    │                    │  ├── CSR window (M01,M05-M08,   ││
                    │                    │  │   M13-M16)                   ││
                    │                    │  ├── M03_DRAMController (AXI4)  ││
                    │                    │  └── Reserved                   ││
                    │                    └────────────────────────────────┘│
                    │                                                      │
                    │   M01_DataflowController ──► op dispatch ──────────┐ │
                    │        │         │         │          │            │ │
                    │        ▼         ▼         ▼          ▼            │ │
                    │   M00_SystolicArray  M09_Attention  M10_FFNMatMul  │ │
                    │        │              M11_RMSNorm   M12_RoPESoftMax│ │
                    │        │                                            │ │
                    │        └──► M02_SRAM (data path) ◄── M03_DRAM ─────┘ │
                    │                                                      │
                    └──────────────────────────────────────────────────────┘
```

---

## 3. Per-Module RTL Interface

### 3.1 M00_SystolicArray

<!-- REQ-COMPUTE-001, REQ-COMPUTE-002, REQ-COMPUTE-003, REQ-COMPUTE-004, REQ-COMPUTE-007 -->

**Module**: `M00_SystolicArray`
**Category**: compute
**Reuse**: none (new RTL; existing synthesis netlist available for reference)

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys | input | 1 | System clock, 500 MHz |
| rst_sys_n | input | 1 | System reset, active low |
| -- Control Interface (from M01) -- | | | |
| syst_mode_i | input | 2 | Mode: 00=IDLE, 01=WEIGHT_LOAD, 10=COMPUTE, 11=OUTPUT_DRAIN |
| syst_precision_i | input | 2 | Precision: 00=FP8, 01=FP16, 10=INT8, 11=RSVD |
| syst_start_i | input | 1 | Start pulse; asserted 1 cycle |
| syst_done_o | output | 1 | Operation complete; asserted 1 cycle |
| syst_err_o | output | 1 | Error flag (NaN/Inf detected, overflow) |
| syst_row_cnt_i | input | 6 | Number of rows to compute (1..32) |
| syst_col_cnt_i | input | 6 | Number of columns to compute (1..32) |
| -- Weight Load Interface (from M02 SRAM) -- | | | |
| weight_data_i | input | 1024 | Weight data: 32 entries x FP32 (32-bit) or 64 entries x FP16 or 128 entries x FP8 |
| weight_addr_o | output | 12 | Weight SRAM read address (word-aligned) |
| weight_req_o | output | 1 | Weight read request |
| weight_valid_i | input | 1 | Weight data valid from SRAM |
| weight_ready_o | output | 1 | Weight load FIFO ready |
| -- Activation Input Interface (from M01/M02) -- | | | |
| act_data_i | input | 1024 | Activation data: 32 entries x FP32, or 64 x FP16, or 128 x FP8 |
| act_valid_i | input | 1 | Activation data valid |
| act_ready_o | output | 1 | Activation input FIFO ready |
| act_last_i | input | 1 | Last activation for current tile |
| -- Output Interface (to M01 accumulation buffer) -- | | | |
| out_data_o | output | 1024 | Output data (FP32 accumulator output, cast to target precision) |
| out_valid_o | output | 1 | Output data valid |
| out_ready_i | input | 1 | Output consumer ready |
| out_last_o | output | 1 | Last output for current tile |
| -- Configuration -- | | | |
| cfg_accum_reset_i | input | 1 | Reset accumulators to zero before new operation |

#### Timing Constraints

| Path | Constraint | Notes |
|------|-----------|-------|
| clk_sys period | 2.0 ns (500 MHz) | Nominal |
| weight_data_i → MAC register | 1.5 ns setup | SRAM output to first MAC pipeline stage |
| act_data_i → MAC register | 1.5 ns setup | Same as weight path |
| MAC chain critical path | 1.8 ns | Single MAC multiply-add (FP8: ~0.6ns, FP16: ~1.2ns, FP32: ~1.8ns) |
| out_data_o → out_ready_i | 1.0 ns | Output register to consumer |

#### Internal Architecture

```
                    ┌──────────────────────────────────────┐
                    │     Weight Preload Buffer (2 KB)     │
                    │  32 rows x 32 cols x 16-bit (FP16)   │
                    └──────────────┬───────────────────────┘
                                   │
   Activation Stream (west→east)   │
   ┌─────┐   ┌─────┐       ┌─────┐ │
   │ PE  │──→│ PE  │──→...─→│ PE  │ │  Row 0
   │(0,0)│   │(0,1)│       │(0,31│ │
   └──┬──┘   └──┬──┘       └──┬──┘ │
      │ (partial sum flows south)  │
   ┌──┴──┐   ┌──┴──┐       ┌──┴──┐ │
   │ PE  │──→│ PE  │──→...─→│ PE  │ │  Row 1
   │(1,0)│   │(1,1)│       │(1,31│ │
   └──┬──┘   └──┬──┘       └──┬──┘ │
      │          │             │    │
      ...        ...           ...  │
      │          │             │    │
   ┌──┴──┐   ┌──┴──┐       ┌──┴──┐ │
   │ PE  │──→│ PE  │──→...─→│ PE  │ │  Row 31
   │(31,0│   │(31,1│       │(31,3│ │
   └─────┘   └─────┘       └─────┘ │
                    ┌──────────────┴───────┐
                    │   Accumulator Buffer │
                    │   (32 x FP32 = 4 KB) │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴───────────┐
                    │  Precision Cast Unit │
                    │  (FP32→FP8/FP16/INT8)│
                    └──────────┬───────────┘
                               │
                          out_data_o
```

**PE (Processing Element) Micro-architecture**:
- Weight register (16-bit, loaded once per operation)
- Activation register (16-bit, streamed from west neighbor)
- MAC unit: act * weight + partial_sum(from north)
- Precision modes:
  - FP8 E4M3: 8-bit multiply, FP32 accumulate
  - FP16: 16-bit multiply, FP32 accumulate
  - INT8: 8-bit multiply, INT32 accumulate
- Pipeline: 3 stages (reg_act, reg_mul, reg_acc)

**Performance**:
- 1024 MACs/cycle @ 500 MHz = 512 GMAC/s
- FP8: 1024 x 500M x 2 (2x density) = 1.024 TOPS (effective ~2 TOPS with structured sparsity)
- FP16: 1024 x 500M = 0.512 TOPS (effective ~1 TOPS with 2:1 structured sparsity)
- INT8: 1024 x 500M x 2 = 1.024 TOPS (effective ~2 TOPS with 2:1 structured sparsity)

### 3.2 M01_DataflowController

<!-- REQ-COMPUTE-005, REQ-COMPUTE-008 -->

**Module**: `M01_DataflowController`
**Category**: control
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys | input | 1 | System clock, 500 MHz |
| rst_sys_n | input | 1 | System reset, active low |
| -- Systolic Array Control (to M00) -- | | | |
| syst_mode_o | output | 2 | Systolic array mode |
| syst_precision_o | output | 2 | Precision selection |
| syst_start_o | output | 1 | Start pulse |
| syst_done_i | input | 1 | Operation complete |
| syst_err_i | input | 1 | Error flag |
| syst_row_cnt_o | output | 6 | Row count |
| syst_col_cnt_o | output | 6 | Column count |
| syst_src_addr_o | output | 32 | Source SRAM address |
| syst_dst_addr_o | output | 32 | Destination SRAM address |
| syst_shape_o | output | 16 | Tile shape {rows, cols} packed |
| -- Operator Dispatch (to M09/M10/M11/M12) -- | | | |
| op_valid_o | output | 1 | Operator command valid |
| op_ready_i | input | 1 | Operator ready |
| op_code_o | output | 4 | Opcode: 0=NOP, 1=ATTN, 2=FFN, 3=RMSNORM, 4=ROPE, 5=SOFTMAX, 6=RESIDUAL |
| op_unit_sel_o | output | 4 | Target unit select (bitmask) |
| op_tid_o | output | 2 | Thread ID (0..3) |
| op_precision_o | output | 2 | Precision for this operation |
| op_src_addr_o | output | 32 | Source address in SRAM |
| op_dst_addr_o | output | 32 | Destination address in SRAM |
| op_params_o | output | 64 | Operation parameters (dims, stride, scale) |
| op_done_i | input | 1 | Operation complete from operator |
| op_err_i | input | 1 | Error from operator |
| -- Memory Request (to M03 DRAM) -- | | | |
| mem_req_valid_o | output | 1 | DMA request valid |
| mem_req_ready_i | input | 1 | DMA request ready |
| mem_req_type_o | output | 2 | 00=READ, 01=WRITE, 10=PREFETCH |
| mem_req_addr_o | output | 32 | DRAM physical address |
| mem_req_size_o | output | 16 | Transfer size in bytes |
| mem_req_tid_o | output | 2 | Thread ID |
| mem_resp_valid_i | input | 1 | DMA response valid |
| mem_resp_data_i | input | 256 | DMA response data |
| mem_resp_last_i | input | 1 | Last beat of DMA transfer |
| mem_resp_err_i | input | 1 | DMA error |
| -- Thread Scheduler Interface (to/from M08) -- | | | |
| sched_thread_en_i | input | 1 | Thread enable from M08 |
| sched_priority_i | input | 2 | Thread priority |
| sched_yield_o | output | 1 | Yield (thread waiting for resource) |
| sched_current_tid_o | output | 2 | Current active thread ID |
| sched_status_o | output | 4 | Thread status: 0=IDLE,1=RUNNING,2=WAIT_MEM,3=WAIT_OP,4=DONE,5=ERR |
| -- Interrupts -- | | | |
| irq_op_done_o | output | 1 | Operation complete interrupt |
| irq_err_o | output | 1 | Error interrupt |
| irq_tid_o | output | 2 | Thread ID for interrupt |
| -- Register Bus (from M04) -- | | | |
| reg_addr_i | input | 12 | Register address (word offset) |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |
| -- Configuration -- | | | |
| start_en_i | input | 1 | Global enable (from M07 reset release) |
| soft_reset_i | input | 1 | Software reset |

#### Internal Pipeline State Machine

See [FSM: M01_DataflowController](#41-m01_dataflowcontroller-fsm) for detailed state transitions.

### 3.3 M02_SRAMScratchpad

<!-- REQ-MEM-004, REQ-MEM-005 -->

**Module**: `M02_SRAMScratchpad`
**Category**: storage
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys | input | 1 | System clock, 500 MHz |
| rst_sys_n | input | 1 | System reset, active low |
| -- Bank 0: Weight Buffer A (ping) -- | | | |
| b0_wdata_i | input | 256 | Write data (from M03 DMA) |
| b0_waddr_i | input | 12 | Write address |
| b0_wen_i | input | 1 | Write enable |
| b0_raddr_i | input | 12 | Read address (from M00 weight load) |
| b0_rdata_o | output | 1024 | Read data (to M00, wide port) |
| b0_ren_i | input | 1 | Read enable |
| -- Bank 1: Weight Buffer B (pong) -- | | | |
| b1_wdata_i | input | 256 | Write data |
| b1_waddr_i | input | 12 | Write address |
| b1_wen_i | input | 1 | Write enable |
| b1_raddr_i | input | 12 | Read address |
| b1_rdata_o | output | 1024 | Read data |
| b1_ren_i | input | 1 | Read enable |
| -- Bank 2: Activation Buffer -- | | | |
| b2_wdata_i | input | 256 | Write data |
| b2_waddr_i | input | 12 | Write address |
| b2_wen_i | input | 1 | Write enable |
| b2_raddr_i | input | 12 | Read address |
| b2_rdata_o | output | 256 | Read data |
| b2_ren_i | input | 1 | Read enable |
| -- Bank 3: KV Cache + Thread Context -- | | | |
| b3_wdata_i | input | 256 | Write data |
| b3_waddr_i | input | 12 | Write address |
| b3_wen_i | input | 1 | Write enable |
| b3_raddr_i | input | 12 | Read address |
| b3_rdata_o | output | 256 | Read data |
| b3_ren_i | input | 1 | Read enable |
| -- ECC Error Reporting -- | | | |
| ecc_err_corrected_o | output | 1 | Single-bit error corrected |
| ecc_err_uncorrected_o | output | 1 | Double-bit error detected |
| ecc_err_addr_o | output | 12 | Error address |
| ecc_err_bank_o | output | 2 | Error bank |
| -- Register Bus (from M04) -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

#### SRAM Organization

| Bank | Size | Data Width (Write) | Data Width (Read) | Usage |
|------|------|--------------------|--------------------|-------|
| Bank 0 | 128 KB | 256-bit | 1024-bit | Weight tile (ping) |
| Bank 1 | 128 KB | 256-bit | 1024-bit | Weight tile (pong) |
| Bank 2 | 128 KB | 256-bit | 256-bit | Activation buffer |
| Bank 3 (lo) | 64 KB | 256-bit | 256-bit | KV cache workspace |
| Bank 3 (hi) | 64 KB | 256-bit | 32-bit | Thread context |

**ECC**: SECDED (8-bit ECC per 64-bit data word). ECC bits stored in separate SRAM sub-array.

### 3.4 M03_DRAMController

<!-- REQ-MEM-001, REQ-MEM-002, REQ-MEM-003, REQ-D2D-001 through REQ-D2D-004 -->

**Module**: `M03_DRAMController`
**Category**: storage
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys_i | input | 1 | System clock, 500 MHz |
| rst_sys_n_i | input | 1 | System reset |
| clk_d2d_i | input | 1 | D2D clock, 625 MHz |
| clk_d2d_pll_i | input | 1 | D2D PLL reference (from M06) |
| -- Bus Command (from M04 AXI4) -- | | | |
| bus_cmd_valid_i | input | 1 | Command valid |
| bus_cmd_ready_o | output | 1 | Command ready |
| bus_cmd_addr_i | input | 32 | DRAM physical address |
| bus_cmd_rw_i | input | 1 | 0=Read, 1=Write |
| bus_cmd_data_i | input | 256 | Write data |
| bus_cmd_mask_i | input | 32 | Byte mask |
| bus_rsp_valid_o | output | 1 | Response valid |
| bus_rsp_data_o | output | 256 | Read data |
| bus_rsp_error_o | output | 1 | Error response |
| bus_rsp_latency_o | output | 16 | Read latency in clk_sys cycles |
| -- D2D PHY Interface (to DRAM die) -- | | | |
| d2d_cmd_valid_o | output | 1 | D2D command valid |
| d2d_cmd_ready_i | input | 1 | D2D command ready |
| d2d_cmd_addr_o | output | 32 | D2D address |
| d2d_cmd_rw_o | output | 1 | D2D read/write |
| d2d_cmd_burst_o | output | 4 | D2D burst length (1..16) |
| d2d_wdata_valid_o | output | 1 | Write data valid |
| d2d_wdata_o | output | 128 | Write data |
| d2d_wdata_ready_i | input | 1 | Write data ready |
| d2d_rdata_valid_i | input | 1 | Read data valid |
| d2d_rdata_i | input | 128 | Read data |
| d2d_rdata_ready_o | output | 1 | Read data ready |
| -- DMA Engine (from M01) -- | | | |
| dma_req_valid_i | input | 1 | DMA request |
| dma_req_ready_o | output | 1 | DMA request ready |
| dma_req_type_i | input | 2 | 00=READ, 01=WRITE |
| dma_req_addr_i | input | 32 | Source/target DRAM address |
| dma_req_size_i | input | 16 | Transfer size (bytes) |
| dma_wdata_i | input | 256 | DMA write data (from SRAM) |
| dma_wdata_valid_i | input | 1 | DMA write data valid |
| dma_rdata_o | output | 256 | DMA read data (to SRAM) |
| dma_rdata_valid_o | output | 1 | DMA read data valid |
| dma_done_o | output | 1 | DMA transfer complete |
| dma_err_o | output | 1 | DMA error |
| -- ECC -- | | | |
| ecc_err_corrected_o | output | 1 | Single-bit error corrected |
| ecc_err_uncorrected_o | output | 1 | Double-bit error detected |
| -- Register Bus (from M04) -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

#### D2D Interface Timing

| Parameter | Value | Notes |
|-----------|-------|-------|
| clk_d2d frequency | 625 MHz DDR | Data on both edges |
| Data width | 128-bit | Per direction |
| Bandwidth | 128 x 625M x 2 = 10 GB/s | Per direction |
| Command bus | 8-bit | Address, RW, burst |
| TSV count | ~280 | 128 data + 8 cmd + ECC + ctrl + P/G |
| TSV latency | < 5 ns | Electrical propagation |
| Total D2D latency | < 100 ns | Command + TSV + DRAM access (row hit) |

### 3.5 M04_SystemBus

<!-- REQ-IO-001 (indirect: debug bus), REQ-IO-002 (indirect: ISA bus) -->

**Module**: `M04_SystemBus`
**Category**: interconnect
**Reuse**: `cbb/axi4-crossbar`

#### Port List (Summary)

| Port Group | Protocol | Width | Masters | Slaves |
|-----------|----------|-------|---------|--------|
| tl_m0 | TileLink UL | 32-bit | M15 JTAG | Debug slave |
| tl_m1 | TileLink UL | 32-bit | M16 ISA | Command slave |
| reg_s2 | Register Bus | 32-bit | M08 ThreadSched | Register access |
| axi_m3 | AXI4 | 256-bit | M03 DRAM | Bulk data |
| axi_m4 | AXI4 | 32-bit | CSR window | Control registers |
| tl_s0 | TileLink UL | 32-bit | Bus arbiter | M02 SRAM |
| tl_s1 | TileLink UL | 32-bit | Bus arbiter | CSR window |

### 3.6 M05_PowerManager

**Module**: `M05_PowerManager`
**Category**: infrastructure
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_aon_i | input | 1 | Always-on clock, 32 kHz |
| rst_aon_n_i | input | 1 | Always-on reset |
| -- DVFS Control (to M06) -- | | | |
| dvfs_op_o | output | 2 | DVFS operation: 00=NOP, 01=RAMP_UP, 10=RAMP_DOWN, 11=HOLD |
| dvfs_req_o | output | 1 | DVFS request |
| dvfs_ack_i | input | 1 | DVFS acknowledge from M06 |
| -- Power Gating -- | | | |
| pg_main_en_o | output | 1 | Main domain power gate enable |
| pg_dram_en_o | output | 1 | DRAM domain power gate enable |
| pg_io_en_o | output | 1 | I/O domain isolation enable |
| -- Power State -- | | | |
| power_state_o | output | 3 | Current power state: 0=SLEEP,1=IDLE,2=DVFS_LOW,3=ACTIVE |
| -- Wake Events -- | | | |
| wake_isa_i | input | 1 | Wake from ISA interface |
| wake_timer_i | input | 1 | Wake from internal timer |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

### 3.7 M06_ClockManager

**Module**: `M06_ClockManager`
**Category**: infrastructure
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| ext_clk_i | input | 1 | External oscillator, 25 MHz |
| pll_lock_i | input | 1 | PLL lock indicator (external analog) |
| -- DVFS (from M05) -- | | | |
| dvfs_op_i | input | 2 | DVFS operation |
| dvfs_req_i | input | 1 | DVFS request |
| clk_gating_en_i | input | 1 | Clock gating enable |
| -- Power Domain Status -- | | | |
| pd_aon_vdd_i | input | 1 | AON domain voltage stable |
| -- Clock Outputs -- | | | |
| clk_sys_o | output | 1 | System clock, 500 MHz nominal |
| clk_aon_o | output | 1 | Always-on clock, 32 kHz |
| clk_io_o | output | 1 | I/O clock, 50 MHz |
| -- Clock Gating -- | | | |
| clk_gating_o | output | 17 | Per-module clock gate enable (one-hot for M00-M16) |
| -- Status -- | | | |
| dvfs_ack_o | output | 1 | DVFS acknowledge |
| clk_status_o | output | 8 | Clock status: {pll_locked, clk_sys_stable, clk_io_stable, clk_aon_stable, dvfs_busy, ...} |
| pll_pwr_en_o | output | 1 | PLL power enable |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

### 3.8 M07_ResetManager

**Module**: `M07_ResetManager`
**Category**: infrastructure
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_aon_i | input | 1 | Always-on clock, 32 kHz |
| rst_por_n_i | input | 1 | External POR, active low |
| -- Reset Outputs -- | | | |
| rst_aon_n_o | output | 1 | AON domain reset |
| rst_sys_n_o | output | 1 | System domain reset |
| rst_io_n_o | output | 1 | I/O domain reset |
| -- Status -- | | | |
| pll_lock_i | input | 1 | PLL locked (from M06) |
| clk_sys_stable_i | input | 1 | clk_sys stable (from M06) |
| clk_io_stable_i | input | 1 | clk_io stable (from M06) |
| -- Watchdog -- | | | |
| wdt_kick_i | input | 1 | Watchdog kick (from M08) |
| wdt_timeout_o | output | 1 | Watchdog timeout |
| -- Reset Source Capture -- | | | |
| reset_source_o | output | 3 | Reset cause: 0=POR,1=WDT,2=SW,3=SEC_FAIL,4=EXT |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

### 3.9 M08_ThreadScheduler

<!-- REQ-COMPUTE-006 -->

**Module**: `M08_ThreadScheduler`
**Category**: control
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys | input | 1 | System clock, 500 MHz |
| rst_sys_n | input | 1 | System reset |
| rst_por_n | input | 1 | POR (for context initialization) |
| clk_enable | input | 1 | Clock enable |
| power_gate_n | input | 1 | Power gate (active low) |
| -- Thread Command (from M13 ISADecoder) -- | | | |
| thread_cmd_valid | input | 1 | Command valid |
| thread_cmd_ready | output | 1 | Command ready |
| thread_cmd_opcode | input | 4 | Opcode: 0=CREATE,1=START,2=STOP,3=CONFIG |
| thread_cmd_thread_id | input | 2 | Target thread ID |
| thread_cmd_priority | input | 2 | Thread priority (0..3) |
| thread_cmd_addr | input | 32 | Thread entry point / config address |
| thread_cmd_data | input | 32 | Thread config data |
| -- Register Bus (from M04) -- | | | |
| reg_req_valid | input | 1 | Register request valid |
| reg_req_ready | output | 1 | Register request ready |
| reg_req_addr | input | 12 | Register address |
| reg_req_rw | input | 1 | 0=Read, 1=Write |
| reg_req_data | input | 32 | Write data |
| reg_rsp_valid | output | 1 | Response valid |
| reg_rsp_data | output | 32 | Read data |
| reg_rsp_error | output | 1 | Response error |
| -- Dispatch (to M01) -- | | | |
| dispatch_valid | output | 1 | Thread dispatch valid |
| dispatch_ready | input | 1 | M01 ready |
| dispatch_tid | output | 2 | Thread ID |
| dispatch_priority | output | 2 | Priority |
| dispatch_opcode | output | 4 | Operation to execute |
| dispatch_addr | output | 32 | Operation address |
| -- Status -- | | | |
| thread_status | output | 8 | Per-thread status (2 bits x 4 threads) |
| irq_thread_done | output | 1 | Thread completion interrupt |

### 3.10 M09_AttentionUnit

<!-- REQ-COMPUTE-008 -->

**Module**: `M09_AttentionUnit`
**Category**: compute
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys_i | input | 1 | System clock, 500 MHz |
| rst_sys_n_i | input | 1 | System reset |
| pg_main_en_i | input | 1 | Power gate enable |
| -- Activation Input (from M01/M02) -- | | | |
| act_valid_i | input | 1 | Activation valid |
| act_data_i | input | 256 | Activation data (8 x FP32 or 16 x FP16) |
| act_pos_i | input | 8 | Token position in sequence |
| act_layer_i | input | 4 | Layer index (0..7) |
| act_ready_o | output | 1 | Ready for activation |
| -- Q/K/V Input (from M00 systolic array) -- | | | |
| q_valid_i | input | 1 | Q valid |
| q_data_i | input | 256 | Q data (8 x FP32) |
| k_valid_i | input | 1 | K valid |
| k_data_i | input | 256 | K data |
| v_valid_i | input | 1 | V valid |
| v_data_i | input | 256 | V data |
| qkv_ready_o | output | 1 | Ready for QKV |
| -- KV Cache Interface (to M03 DRAM via M02) -- | | | |
| kv_addr_o | output | 32 | KV cache address |
| kv_wdata_o | output | 256 | KV write data |
| kv_wen_o | output | 1 | KV write enable |
| kv_rdata_i | input | 256 | KV read data |
| kv_valid_o | output | 1 | KV request valid |
| kv_ready_i | input | 1 | KV request ready |
| -- Attention Output (to M01/M02) -- | | | |
| attn_valid_o | output | 1 | Attention output valid |
| attn_data_o | output | 256 | Attention output (8 x FP32) |
| attn_ready_i | input | 1 | Consumer ready |
| attn_done_o | output | 1 | Attention operation complete |
| -- Operator Command (from M01) -- | | | |
| op_valid_i | input | 1 | Operation command valid |
| op_code_i | input | 4 | Opcode |
| op_params_i | input | 64 | Parameters |
| op_done_o | output | 1 | Operation complete |
| op_err_o | output | 1 | Error |

### 3.11 M10_FFNMatMul

<!-- REQ-COMPUTE-008 -->

**Module**: `M10_FFNMatMul`
**Category**: compute
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys_i | input | 1 | System clock, 500 MHz |
| rst_sys_n_i | input | 1 | System reset |
| pg_main_en_i | input | 1 | Power gate enable |
| -- Activation Input (from M01/M02) -- | | | |
| act_valid_i | input | 1 | Activation valid |
| act_data_i | input | 256 | Activation data |
| act_ready_o | output | 1 | Ready |
| -- Weight Access (via M02 SRAM) -- | | | |
| weight_req_o | output | 1 | Weight request |
| weight_addr_o | output | 12 | Weight SRAM address |
| weight_data_i | input | 1024 | Weight data |
| weight_valid_i | input | 1 | Weight valid |
| -- Systolic Array Control -- | | | |
| syst_mode_o | output | 2 | Systolic array mode |
| syst_start_o | output | 1 | Start |
| syst_done_i | input | 1 | Done |
| -- FFN Output (to M01/M02) -- | | | |
| ffn_valid_o | output | 1 | Output valid |
| ffn_data_o | output | 256 | Output data |
| ffn_ready_i | input | 1 | Consumer ready |
| ffn_done_o | output | 1 | FFN operation complete |
| -- SiLU Activation (internal) -- | | | |
| -- Operator Command (from M01) -- | | | |
| op_valid_i | input | 1 | Command valid |
| op_code_i | input | 4 | Opcode |
| op_params_i | input | 64 | Parameters |
| op_done_o | output | 1 | Complete |
| op_err_o | output | 1 | Error |

### 3.12 M11_RMSNormUnit (NEW)

<!-- REQ-COMPUTE-008 -->

**Module**: `M11_RMSNormUnit`
**Category**: compute
**Reuse**: none (new RTL development)

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys_i | input | 1 | System clock, 500 MHz |
| rst_sys_n_i | input | 1 | System reset |
| pg_main_en_i | input | 1 | Power gate enable |
| -- Data Input (from M01/M02) -- | | | |
| data_valid_i | input | 1 | Input data valid |
| data_i | input | 256 | Input data (8 x FP32 or 16 x FP16) |
| data_last_i | input | 1 | Last element of vector |
| data_ready_o | output | 1 | Ready for input |
| -- Gamma Weight Input (from M02 SRAM) -- | | | |
| gamma_valid_i | input | 1 | Gamma weight valid |
| gamma_i | input | 256 | Gamma weight (8 x FP32) |
| gamma_ready_o | output | 1 | Ready for gamma |
| -- Output (to M01/M02) -- | | | |
| out_valid_o | output | 1 | Output valid |
| out_data_o | output | 256 | Normalized output (8 x FP32) |
| out_last_o | output | 1 | Last element of output vector |
| out_ready_i | input | 1 | Consumer ready |
| out_done_o | output | 1 | RMSNorm complete |
| -- Operator Command (from M01) -- | | | |
| op_valid_i | input | 1 | Command valid |
| op_code_i | input | 4 | Opcode (3=RMSNORM) |
| op_params_i | input | 64 | Parameters: {dim[15:0], eps[31:16], precision[33:32]} |
| op_done_o | output | 1 | Operation complete |
| op_err_o | output | 1 | Error (divide by zero, NaN) |

#### Algorithm

```
RMSNorm(x) = x / sqrt(mean(x^2) + epsilon) * gamma

Two-pass implementation:
  Pass 1: Accumulate sum(x_i^2) for i in 0..dim-1
  Pass 2: Compute rms = sqrt(sum/dim + eps); out_i = (x_i / rms) * gamma_i

  Pipeline: 4 stages
    Stage 0: x_i^2  (multiply)
    Stage 1: Accumulate sum (FP32 adder tree, 8→1)
    Stage 2: rms = sqrt(sum/dim + eps) (divider + sqrt)
    Stage 3: (x_i / rms) * gamma_i (divide + multiply)
```

### 3.13 M12_RoPESoftMaxUnit (NEW)

<!-- REQ-COMPUTE-008 -->

**Module**: `M12_RoPESoftMaxUnit`
**Category**: compute
**Reuse**: none (new RTL development; replaces old M11_RMSNormRoPE + M12_SoftMax)

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys_i | input | 1 | System clock, 500 MHz |
| rst_sys_n_i | input | 1 | System reset |
| pg_main_en_i | input | 1 | Power gate enable |
| -- RoPE Input (for Q/K) -- | | | |
| rope_valid_i | input | 1 | Input valid |
| rope_data_i | input | 256 | Input data (8 x FP32) |
| rope_pos_i | input | 16 | Position index |
| rope_head_dim_i | input | 8 | Head dimension |
| rope_ready_o | output | 1 | Ready for RoPE input |
| -- RoPE Output -- | | | |
| rope_out_valid_o | output | 1 | RoPE output valid |
| rope_out_data_o | output | 256 | RoPE-applied data |
| rope_out_ready_i | input | 1 | Consumer ready |
| -- SoftMax Input (from M00/M09) -- | | | |
| softmax_valid_i | input | 1 | Input valid |
| softmax_data_i | input | 256 | Input data (attention scores) |
| softmax_last_i | input | 1 | Last element of row |
| softmax_ready_o | output | 1 | Ready for softmax input |
| -- SoftMax Output -- | | | |
| softmax_out_valid_o | output | 1 | Output valid |
| softmax_out_data_o | output | 256 | Softmax output (probabilities) |
| softmax_out_last_o | output | 1 | Last element of output row |
| softmax_out_ready_i | input | 1 | Consumer ready |
| -- Operator Command (from M01) -- | | | |
| op_valid_i | input | 1 | Command valid |
| op_code_i | input | 4 | Opcode: 4=ROPE, 5=SOFTMAX |
| op_params_i | input | 64 | Parameters |
| op_done_o | output | 1 | Operation complete |
| op_err_o | output | 1 | Error |

#### RoPE Algorithm

```
RoPE(x, pos) for dimension pair (2i, 2i+1):
  theta_i = 1 / (10000^(2i/d))
  cos_val = cos(pos * theta_i)
  sin_val = sin(pos * theta_i)
  x_2i'   = x_2i * cos_val - x_2i+1 * sin_val
  x_2i+1' = x_2i+1 * cos_val + x_2i * sin_val

Implementation: Sin/Cos LUT (2048 entries, 16-bit fixed-point)
  Pipeline: 3 stages
    Stage 0: LUT lookup (theta, pos → cos, sin)
    Stage 1: x_2i * cos, x_2i+1 * sin (parallel multiply)
    Stage 2: Add/subtract + output register
```

#### SoftMax Algorithm (Online)

```
Online SoftMax for numerical stability:
  m_0 = -inf
  d_0 = 0
  For each x_j:
    m_j = max(m_{j-1}, x_j)
    d_j = d_{j-1} * exp(m_{j-1} - m_j) + exp(x_j - m_j)
  Final: softmax(x_j) = exp(x_j - m_N) / d_N

  Pipeline: 5 stages
    Stage 0: max(m_prev, x_j)          (FP32 compare)
    Stage 1: m_prev - m_new, x_j - m_new (FP32 subtract)
    Stage 2: exp(m_prev - m_new), exp(x_j - m_new) (FP32 exp, LUT-based)
    Stage 3: d_prev * exp(m_prev - m_new) + exp(x_j - m_new) (FP32 multiply-add)
    Stage 4: Final divide: exp(x_j - m_N) / d_N (FP32 divide)
```

### 3.14 M13_ISADecoder

**Module**: `M13_ISADecoder`
**Category**: control
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys | input | 1 | System clock, 500 MHz |
| rst_sys_n | input | 1 | System reset |
| -- ISA Command (from M16) -- | | | |
| isa_cmd_valid | input | 1 | Command valid |
| isa_cmd_ready | output | 1 | Command ready |
| isa_cmd_data | input | 32 | ISA instruction word |
| -- Thread Command (to M08) -- | | | |
| thread_cmd_valid | output | 1 | Thread command valid |
| thread_cmd_ready | input | 1 | Thread command ready |
| thread_cmd_opcode | output | 4 | Thread opcode |
| thread_cmd_thread_id | output | 2 | Thread ID |
| thread_cmd_priority | output | 2 | Priority |
| thread_cmd_addr | output | 32 | Address |
| thread_cmd_data | output | 32 | Data |
| -- Decode Status -- | | | |
| decode_err | output | 1 | Decode error (illegal instruction) |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

### 3.15 M14_SecureBoot

**Module**: `M14_SecureBoot`
**Category**: security
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_sys | input | 1 | System clock, 500 MHz |
| rst_sys_n | input | 1 | System reset |
| rst_por_n | input | 1 | POR reset |
| -- Firmware Access (via M03 DRAM) -- | | | |
| fw_addr | output | 32 | Firmware address in DRAM |
| fw_size | output | 32 | Firmware size |
| fw_data_req | output | 1 | Firmware data request |
| fw_data_addr | output | 32 | Firmware data address |
| fw_data_valid | input | 1 | Data valid |
| fw_data | input | 256 | Firmware data |
| fw_data_last | input | 1 | Last data beat |
| -- Signature -- | | | |
| sig_r | input | 256 | ECDSA signature R |
| sig_s | input | 256 | ECDSA signature S |
| sig_valid | input | 1 | Signature valid |
| -- OTP Interface -- | | | |
| otp_key_addr | output | 8 | OTP key address |
| otp_key_data | input | 256 | OTP key data |
| otp_key_valid | input | 1 | Key valid |
| otp_read_ack | input | 1 | Read acknowledge |
| otp_read_req | output | 1 | Read request |
| otp_locked | input | 1 | OTP locked |
| -- Status -- | | | |
| sec_boot_en | input | 1 | Secure boot enable |
| sec_status | output | 4 | Security status: 0=IDLE,1=VERIFYING,2=PASS,3=FAIL,4=LOCKED |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

### 3.16 M15_JTAGInterface

**Module**: `M15_JTAGInterface`
**Category**: io
**Reuse**: `cbb/jtag-tap`

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| TCK | input | 1 | JTAG test clock |
| TMS | input | 1 | JTAG test mode select |
| TDI | input | 1 | JTAG test data in |
| TDO | output | 1 | JTAG test data out |
| TRST_n | input | 1 | JTAG test reset (active low) |
| -- Internal Interface -- | | | |
| sec_status_i | input | 4 | Security status from M14 |
| jtag_locked_o | output | 1 | JTAG locked by security |
| debug_bus_o | output | 32 | Debug bus to M04 |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

#### TAP FSM (IEEE 1149.1)

The JTAG TAP controller implements the standard 16-state IEEE 1149.1 FSM:

```
Test-Logic-Reset → Run-Test/Idle → Select-DR-Scan → Capture-DR → Shift-DR → Exit1-DR → Pause-DR → Exit2-DR → Update-DR
                                                                                                              → Select-IR-Scan → Capture-IR → Shift-IR → Exit1-IR → Pause-IR → Exit2-IR → Update-IR
```

Refer to IEEE 1149.1-2013 for complete state diagram. The TAP FSM is a well-known standard; RTL implementation follows the canonical state encoding. IR width: 4 bits (see §14.3 for instruction codes).

### 3.17 M16_ISAInterface

**Module**: `M16_ISAInterface`
**Category**: io
**Reuse**: none

#### Port List

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| clk_io_i | input | 1 | I/O clock, 50 MHz |
| rst_io_n_i | input | 1 | I/O reset |
| -- External ISA Pins -- | | | |
| isa_cmd_i | input | 32 | ISA command word |
| isa_cmd_valid_i | input | 1 | Command valid |
| isa_cmd_ready_o | output | 1 | Command ready |
| isa_rsp_o | output | 32 | ISA response word |
| isa_rsp_valid_o | output | 1 | Response valid |
| isa_rsp_ready_i | input | 1 | Response ready |
| -- Internal ISA Bus (to M13, CDC) -- | | | |
| isa_cmd_sys_o | output | 32 | Command (sys domain) |
| isa_cmd_sys_valid_o | output | 1 | Command valid |
| isa_cmd_sys_ready_i | input | 1 | Command ready |
| -- Security Gate -- | | | |
| sec_status_i | input | 4 | Security status from M14 |
| isa_locked_o | output | 1 | ISA locked by security |
| -- CRC-32 -- | | | |
| crc_err_o | output | 1 | CRC check failed |
| -- Register Bus -- | | | |
| reg_addr_i | input | 12 | Register address |
| reg_wdata_i | input | 32 | Write data |
| reg_write_i | input | 1 | Write strobe |
| reg_read_i | input | 1 | Read strobe |
| reg_rdata_o | output | 32 | Read data |

---

## 4. State Machines

### 4.1 M01_DataflowController FSM

```
State Diagram:
                    ┌─────────┐
          ┌────────►│  IDLE   │◄────────┐
          │         └────┬────┘         │
          │              │ start_en &   │
          │              │ thread_valid │
          │              ▼              │
          │         ┌─────────┐         │
          │         │  FETCH  │         │
          │         │  (op)   │         │
          │         └────┬────┘         │
          │              │              │
          │    ┌─────────┼─────────┐    │
          │    ▼         ▼         ▼    │
          │ ┌──────┐ ┌──────┐ ┌──────┐ │
          │ │DMA_  │ │LOAD_ │ │DISP_ │ │
          │ │SETUP │ │WGTS  │ │OPER  │ │
          │ └──┬───┘ └──┬───┘ └──┬───┘ │
          │    │         │         │    │
          │    ▼         ▼         ▼    │
          │ ┌──────┐ ┌──────┐ ┌──────┐ │
          │ │DMA_  │ │WGTS_ │ │OPER_ │ │
          │ │WAIT  │ │DONE  │ │WAIT  │ │
          │ └──┬───┘ └──┬───┘ └──┬───┘ │
          │    │         │         │    │
          │    └─────────┼─────────┘    │
          │              │ all_done     │
          │              ▼              │
          │         ┌─────────┐         │
          │         │WRITEBACK│         │
          │         └────┬────┘         │
          │              │              │
          │              ▼              │
          │         ┌─────────┐         │
          │         │  DONE   │─────────┘
          │         └─────────┘
          │              │ error
          │              ▼
          │         ┌─────────┐
          └─────────│  ERROR  │
                    └─────────┘
```

### 4.2 M05_PowerManager FSM

```
State Diagram:
                    ┌──────────┐
          ┌────────►│  SLEEP   │ (<=5 mW)
          │         │ (state 0)│
          │         └────┬─────┘
          │              │ wake_isa | wake_timer | POR
          │              ▼
          │         ┌──────────┐
          │         │  IDLE    │ (<=0.1 W)
          │         │ (state 1)│◄────────────────────┐
          │         └────┬─────┘                     │
          │              │ dvfs_req (perf needed)    │
          │              ▼                           │
          │         ┌──────────┐                     │
          │         │ DVFS_LOW │ (0.8 W, 250 MHz)    │
          │         │ (state 2)│                     │
          │         └────┬─────┘                     │
          │              │ dvfs_req (peak perf)      │
          │              ▼                           │
          │         ┌──────────┐                     │
          │         │  ACTIVE  │ (1.8 W, 500 MHz)    │
          │         │ (state 3)│                     │
          │         └────┬─────┘                     │
          │              │ idle_detect (no threads)  │
          │              └───────────────────────────┘
          │
          │         Any state --(deep_idle_timeout)──┘
          │              │
          │              ▼
          │         ┌──────────┐
          └─────────│  SLEEP   │
                    └──────────┘
```

### 4.3 M07_ResetManager FSM

```
State Diagram:
                    ┌──────────┐
                    │ POR_ASSERT│ (rst_por_n=0)
                    └────┬─────┘
                         │ 100 us debounce
                         ▼
                    ┌──────────┐
                    │ AON_INIT │ (rst_aon_n=0)
                    └────┬─────┘
                         │ clk_aon stable (1 ms)
                         ▼
                    ┌──────────┐
                    │SECURE_BOOT│ (M14 verify)
                    └────┬─────┘
                         │ sec_status_pass
                         ▼
                    ┌──────────┐
                    │ PLL_INIT │ (pll_pwr_en=1)
                    └────┬─────┘
                         │ pll_lock (100 us)
                         ▼
                    ┌──────────┐
                    │ SYS_INIT │ (rst_sys_n=0)
                    └────┬─────┘
                         │ clk_sys stable (16 cycles)
                         ▼
                    ┌──────────┐
                    │ IO_INIT  │ (rst_io_n=0)
                    └────┬─────┘
                         │ clk_io stable (16 cycles)
                         ▼
                    ┌──────────┐
                    │  RUNNING │
                    └──────────┘
```

### 4.4 M08_ThreadScheduler FSM

```
Per-Thread State:
                    ┌──────────┐
                    │ BLOCKED  │ (waiting for resource)
                    └────┬─────┘
                         │ resource available
                         ▼
                    ┌──────────┐
          ┌────────►│  READY   │◄────────┐
          │         └────┬─────┘         │
          │              │ schedule      │ yield
          │              ▼               │
          │         ┌──────────┐         │
          │         │ RUNNING  │─────────┘
          │         └────┬─────┘
          │              │ op_done
          │              ▼
          │         ┌──────────┐
          └─────────│  DONE    │
                    └──────────┘
```

### 4.5 M14_SecureBoot FSM

```
State Diagram:
                    ┌──────────┐
                    │  IDLE    │
                    └────┬─────┘
                         │ sec_boot_en & rst_por_n
                         ▼
                    ┌──────────┐
                    │ VERIFYING│ (SHA-256 hash + ECDSA verify)
                    └────┬─────┘
                    ┌────┴─────┐
                    ▼          ▼
              ┌──────────┐ ┌──────────┐
              │  PASS    │ │  FAIL    │
              │ (state 3)│ │ (state 4)│
              └────┬─────┘ └────┬─────┘
                   │            │
                   ▼            ▼
              Boot continues  LOCKDOWN
              JTAG open       JTAG locked
              ISA open        ISA locked
```

---

## 5. Pipeline Stages

### 5.1 Systolic Array Pipeline (M00)

```
                    ┌─────────────────────────────────────────┐
                    │         Systolic Array Pipeline          │
                    │                                         │
  Stage 0:          │  Weight Preload Buffer                  │
  (weight_load)     │  - Load 32x32 weight matrix (2 KB)      │
                    │  - From SRAM Bank 0/1 (1024-bit wide)   │
                    │  - Latency: 32 cycles (64 ns)           │
                    │                                         │
  Stage 1:          │  Activation Stream + Weight Multiply    │
  (compute)         │  - West→East activation flow            │
                    │  - North→South partial sum flow         │
                    │  - 3 sub-stages per PE:                 │
                    │    a. Register activation (from west)    │
                    │    b. Multiply: act * weight             │
                    │    c. Accumulate: mul + partial_sum_north│
                    │  - Latency: 32 + 32 = 64 cycles per tile│
                    │  - Pipeline fill: 32 cycles             │
                    │  - Pipeline drain: 32 cycles            │
                    │                                         │
  Stage 2:          │  Accumulator Buffer + Precision Cast    │
  (output)          │  - FP32 → target precision (FP8/FP16)   │
                    │  - Rounding: round-to-nearest-even      │
                    │  - Output to SRAM Bank 2                │
                    │  - Latency: 4 cycles                     │
                    └─────────────────────────────────────────┘
```

### 5.2 Attention Unit Pipeline (M09)

```
                    ┌─────────────────────────────────────────┐
                    │         Attention Pipeline               │
                    │                                         │
  Stage 0: QKV      │  QKV Aggregation                        │
  Aggregation       │  - Receive Q, K, V from M00              │
                    │  - Reshape to multi-head (8 heads)       │
                    │  - Write K, V to KV cache (M03 DRAM)     │
                    │  - Latency: ~100 cycles                  │
                    │                                         │
  Stage 1: QK^T     │  Score Computation (via M00)             │
  (via M00)         │  - Q: 1 x 576 (decode) or N x 576       │
                    │  - K^T: 576 x seq_len                    │
                    │  - S = QK^T / sqrt(d_k)                  │
                    │  - Latency: ~N cycles (decode)           │
                    │                                         │
  Stage 2: SoftMax  │  SoftMax (via M12)                       │
  (via M12)         │  - Online softmax per row                │
                    │  - Latency: ~N cycles                    │
                    │                                         │
  Stage 3: AV       │  Weighted Sum (via M00)                  │
  (via M00)         │  - A_softmax: 1 x seq_len                │
                    │  - V: seq_len x 576                      │
                    │  - Output: 1 x 576                       │
                    │  - Latency: ~seq_len*576/1024 cycles     │
                    │                                         │
  Stage 4: Output   │  Output Projection + Residual            │
                    │  - Wo * concat(heads) + residual        │
                    │  - Latency: ~576*576/1024 cycles         │
                    └─────────────────────────────────────────┘
```

### 5.3 FFN Pipeline (M10)

```
                    ┌─────────────────────────────────────────┐
                    │            FFN Pipeline                  │
                    │                                         │
  Stage 0: Gate     │  Gate Projection (via M00)               │
  Projection        │  - Input: 1 x 576 (or N x 576)          │
                    │  - Weight: W_gate 576 x 2304             │
                    │  - Latency: (576*2304)/1024 ≈ 1296 cyc  │
                    │                                         │
  Stage 1: Up       │  Up Projection (via M00)                 │
  Projection        │  - Input: 1 x 576                        │
                    │  - Weight: W_up 576 x 2304               │
                    │  - Latency: (576*2304)/1024 ≈ 1296 cyc  │
                    │  - Can run in parallel with gate         │
                    │                                         │
  Stage 2: SiLU     │  SiLU Activation (via M11/M12)           │
  Activation        │  - SiLU(x) = x * sigmoid(x)             │
                    │  - Element-wise, 2304 elements           │
                    │  - Latency: 2304/8 ≈ 288 cycles         │
                    │                                         │
  Stage 3: Down     │  Down Projection (via M00)               │
  Projection        │  - Input: gate_result ⊙ SiLU(up_result) │
                    │  - Weight: W_down 2304 x 576            │
                    │  - Latency: (2304*576)/1024 ≈ 1296 cyc  │
                    │                                         │
  Stage 4: Output   │  Residual Add + Write-back              │
                    │  - output = down_out + residual          │
                    │  - Latency: 288 cycles                   │
                    └─────────────────────────────────────────┘
```

---

## 6. Register Map

### 6.1 System Address Map

| Start Address | End Address | Size | Module | Description |
|---------------|-------------|------|--------|-------------|
| 0x0000_0000 | 0x0FFF_FFFF | 256 MB | M03 DRAM | Firmware image |
| 0x1000_0000 | 0x1FFF_FFFF | 256 MB | M03 DRAM | Model weights |
| 0x2000_0000 | 0x3FFF_FFFF | 512 MB | M03 DRAM | KV cache |
| 0x4000_0000 | 0x7FFF_FFFF | 1 GB | M03 DRAM | Reserved / scratch |
| 0xF000_0000 | 0xF000_0FFF | 4 KB | M05 PowerManager | CSR |
| 0xF000_1000 | 0xF000_1FFF | 4 KB | M06 ClockManager | CSR |
| 0xF000_2000 | 0xF000_2FFF | 4 KB | M07 ResetManager | CSR |
| 0xF000_3000 | 0xF000_3FFF | 4 KB | M08 ThreadScheduler | CSR |
| 0xF000_4000 | 0xF000_4FFF | 4 KB | M01 DataflowController | CSR |
| 0xF000_5000 | 0xF000_5FFF | 4 KB | M03 DRAMController | CSR |
| 0xF000_6000 | 0xF000_6FFF | 4 KB | M14 SecureBoot | CSR |
| 0xF000_7000 | 0xF000_7FFF | 4 KB | M13 ISADecoder | CSR |
| 0xF000_8000 | 0xF000_8FFF | 4 KB | M15 JTAGInterface | CSR |
| 0xF000_9000 | 0xF000_9FFF | 4 KB | M16 ISAInterface | CSR |
| 0xF800_0000 | 0xFBFF_FFFF | 64 MB | M02 SRAM | Direct access |

### 6.2 M01_DataflowController CSR (0xF000_4000)

| Offset | Register | Width | Access | Reset | Description |
|--------|----------|-------|--------|-------|-------------|
| 0x00 | DFC_CTRL | 32 | R/W | 0x0000_0000 | Control: [0]=enable, [1]=soft_reset, [3:2]=precision_default |
| 0x04 | DFC_STATUS | 32 | R | 0x0000_0000 | Status: [0]=busy, [1]=error, [7:4]=fsm_state, [15:8]=active_thread |
| 0x08 | DFC_OP_QUEUE | 32 | W | 0x0000_0000 | Enqueue operation: [3:0]=opcode, [7:4]=unit_sel, [15:8]=precision |
| 0x0C | DFC_OP_PARAMS | 32 | W | 0x0000_0000 | Operation parameters: dims, stride |
| 0x10 | DFC_SRC_ADDR | 32 | R/W | 0x0000_0000 | Source address (SRAM offset) |
| 0x14 | DFC_DST_ADDR | 32 | R/W | 0x0000_0000 | Destination address (SRAM offset) |
| 0x18 | DFC_DMA_ADDR | 32 | R/W | 0x0000_0000 | DMA DRAM address |
| 0x1C | DFC_DMA_SIZE | 32 | R/W | 0x0000_0000 | DMA transfer size (bytes) |
| 0x20 | DFC_IRQ_EN | 32 | R/W | 0x0000_0000 | Interrupt enable: [0]=op_done, [1]=error |
| 0x24 | DFC_IRQ_STATUS | 32 | R/W1C | 0x0000_0000 | Interrupt status (write-1-clear) |
| 0x28 | DFC_ERR_CODE | 32 | R | 0x0000_0000 | Error code: [7:0]=code, [15:8]=thread_id |
| 0x2C | DFC_PERF_CNT | 32 | R | 0x0000_0000 | Cycle counter for current operation |

### 6.3 M05_PowerManager CSR (0xF000_0000)

| Offset | Register | Width | Access | Reset | Description |
|--------|----------|-------|--------|-------|-------------|
| 0x00 | PM_CTRL | 32 | R/W | 0x0000_0001 | [0]=enable, [3:1]=target_state, [4]=pg_main, [5]=pg_dram |
| 0x04 | PM_STATUS | 32 | R | 0x0000_0001 | [2:0]=current_state, [3]=pg_main_active, [4]=pg_dram_active |
| 0x08 | PM_DVFS_CTRL | 32 | R/W | 0x0000_0000 | [0]=dvfs_req, [1]=dvfs_dir, [7:2]=target_freq_mhz/10 |
| 0x0C | PM_IDLE_TIMEOUT | 32 | R/W | 0x0000_03E8 | Idle timeout (ms) before IDLE entry |
| 0x10 | PM_SLEEP_TIMEOUT | 32 | R/W | 0x0000_2710 | Sleep timeout (ms) before SLEEP entry |
| 0x14 | PM_WAKE_SRC | 32 | R | 0x0000_0000 | Wake source: [0]=isa, [1]=timer, [2]=por |

### 6.4 M06_ClockManager CSR (0xF000_1000)

| Offset | Register | Width | Access | Reset | Description |
|--------|----------|-------|--------|-------|-------------|
| 0x00 | CM_CTRL | 32 | R/W | 0x0000_0001 | [0]=pll_en, [1]=clk_gating_en, [7:2]=clk_sys_div |
| 0x04 | CM_STATUS | 32 | R | 0x0000_0000 | [0]=pll_locked, [1]=clk_sys_stable, [2]=clk_io_stable |
| 0x08 | CM_CLK_GATING | 32 | R/W | 0x0000_0000 | Per-module clock gate: bit[N]=1 means gated |
| 0x0C | CM_FREQ_CFG | 32 | R/W | 0x0000_01F4 | Target clk_sys frequency (MHz) |

### 6.5 M08_ThreadScheduler CSR (0xF000_3000)

| Offset | Register | Width | Access | Reset | Description |
|--------|----------|-------|--------|-------|-------------|
| 0x00 | TS_CTRL | 32 | R/W | 0x0000_0000 | [0]=enable, [1]=round_robin_en, [3:2]=max_threads |
| 0x04 | TS_STATUS | 32 | R | 0x0000_0000 | [7:0]=thread_status (2 bits per thread) |
| 0x08 | TS_THREAD_CFG(n) | 32 | R/W | 0x0000_0000 | n=0..3: [1:0]=priority, [2]=enable, [31:16]=entry_addr_hi |
| 0x0C+4n | TS_THREAD_ADDR(n) | 32 | R/W | 0x0000_0000 | Thread entry point address |
| 0x1C | TS_WDT_KICK | 32 | W | 0x0000_0000 | Write 0xACCE55 to kick watchdog |

### 6.6 M14_SecureBoot CSR (0xF000_6000)

| Offset | Register | Width | Access | Reset | Description |
|--------|----------|-------|--------|-------|-------------|
| 0x00 | SB_CTRL | 32 | R/W | 0x0000_0000 | [0]=sec_boot_en, [1]=force_verify |
| 0x04 | SB_STATUS | 32 | R | 0x0000_0000 | [3:0]=status (0=IDLE,1=VERIFYING,2=PASS,3=FAIL,4=LOCKED) |
| 0x08 | SB_FW_ADDR | 32 | R/W | 0x0000_0000 | Firmware image DRAM address |
| 0x0C | SB_FW_SIZE | 32 | R/W | 0x0000_0000 | Firmware image size (bytes) |
| 0x10 | SB_SIG_R(n) | 32 | R | 0x0000_0000 | ECDSA signature R word n (n=0..7) |
| 0x30 | SB_SIG_S(n) | 32 | R | 0x0000_0000 | ECDSA signature S word n (n=0..7) |
| 0x50 | SB_LIFECYCLE | 32 | R/W | 0x0000_0000 | [1:0]=lifecycle: 0=TEST,1=DEV,2=PROD,3=RMA |

---

## 7. Buffer/SRAM Sizing

### 7.1 SRAM Allocation (M02, 512 KB Total)

| Buffer | Size | Bank | Width | Purpose |
|--------|------|------|-------|---------|
| Weight Buffer A (ping) | 128 KB | Bank 0 | 1024-bit read | Current layer weight tile |
| Weight Buffer B (pong) | 128 KB | Bank 1 | 1024-bit read | Next layer weight tile (prefetch) |
| Activation Buffer | 128 KB | Bank 2 | 256-bit R/W | Current layer activations |
| KV Cache Workspace | 64 KB | Bank 3 (lo) | 256-bit R/W | KV cache working set for current layer |
| Thread Context | 64 KB | Bank 3 (hi) | 32-bit R/W | Thread context save/restore (4 threads x 16 KB) |

### 7.2 Buffer Sizing Rationale

**Weight Buffer (128 KB per bank)**:
- TinyStories 15M model: max weight matrix = 576 x 2304 (FFN gate/up)
- FP16: 576 x 2304 x 2 bytes = 2.65 MB -> too large for single tile
- Tiling: 32 x 32 tile x FP16 = 2 KB per tile; 128 KB stores 64 tiles
- Double-buffered (ping-pong): 128 KB x 2 = 256 KB total

**Activation Buffer (128 KB)**:
- Prefill: 256 tokens x 576 dims x 2 bytes (FP16) = 288 KB
- 288 KB > 128 KB, so prefill uses streaming: process in smaller batches
- Decode: 1 token x 576 dims x 2 bytes = 1.125 KB -> easily fits

**KV Cache Workspace (64 KB)**:
- Per-layer KV cache: 2 x 576 x 2 bytes per token = 2.25 KB
- Concurrent working set: ~8 tokens x 2.25 KB = 18 KB -> fits in 64 KB
- Full KV cache (2048 tokens x 8 layers) stored in DRAM (36 MB)

### 7.3 Internal Buffers (Register Files)

| Module | Buffer | Size | Description |
|--------|--------|------|-------------|
| M00 | Accumulator Buffer | 4 KB | 32 x FP32 = 128 B x 32 rows = 4 KB |
| M00 | Weight Preload Buffer | 2 KB | 32 x 32 x 16-bit = 2 KB |
| M09 | Q/K/V Buffer | 4.5 KB | 3 x 576 x 16-bit = 3.375 KB + headroom |
| M10 | Gate/Up Buffer | 9 KB | 2 x 2304 x 16-bit = 9 KB |
| M11 | RMSNorm Pipeline | 576 B | 576 x 8-bit pipeline registers |
| M12 | RoPE LUT | 4 KB | 2048 x 16-bit (sin/cos) = 4 KB |
| M12 | SoftMax Pipeline | 2 KB | Max + sum registers + pipe stages |
| M08 | Thread Context (4x) | 64 KB | 4 threads x 16 KB (register file + PC) |
| M03 | DMA FIFO | 8 KB | Read FIFO + Write FIFO for D2D |

---

## 8. Arbitration Policies

### 8.1 System Bus Arbitration (M04)

**Policy**: Priority-based round-robin with aging

| Master | Priority | Description |
|--------|----------|-------------|
| M15 JTAG | 0 (highest) | Debug access; must not be blocked |
| M16 ISA | 1 | Host command interface |
| M08 ThreadScheduler | 2 | Thread management CSR access |
| M14 SecureBoot | 3 | Security CSR access (boot only) |

**Aging**: Priority escalates by 1 level every 256 cycles of waiting. Prevents starvation of low-priority masters.

### 8.2 DRAM Access Arbitration (M03)

**Policy**: Multi-level priority with preemption

| Requester | Priority | Bandwidth Guarantee |
|-----------|----------|---------------------|
| DMA Engine (M01) | 0 (highest) | Min 80% of DRAM bandwidth |
| KV Cache (M09) | 1 | Min 10% of DRAM bandwidth |
| CSR Access (M04) | 2 | Best-effort |
| Firmware (M14) | 3 | Only during boot |

**Preemption**: DMA transfers can be preempted by KV cache reads after current burst completes.

### 8.3 Thread Scheduling (M08)

**Policy**: Priority-based round-robin with aging

| Priority | Typical Thread Type |
|----------|---------------------|
| 0 (highest) | Prefill inference (latency-critical) |
| 1 | Decode inference (throughput) |
| 2 | Weight prefetch (background) |
| 3 (lowest) | Maintenance (ECC scrub, etc.) |

**Algorithm**:
1. Select highest priority among READY threads
2. If multiple at same priority, round-robin
3. Age counter increments every 1024 cycles
4. Age >= threshold (4096) -> promote to next priority level

### 8.4 Operator Bus Arbitration (M01 → M09/M10/M11/M12)

**Policy**: Token-based pipeline dispatch

- M01 dispatches one operation at a time to each operator
- Operators signal ready=0 when pipeline full
- M01 holds valid=1 and waits for ready=1
- No time-division multiplexing; operators are statically partitioned by function

---

## 9. Handshake Protocols

### 9.1 Valid/Ready (Operator Pipeline)

```
Standard valid/ready handshake for all operator-to-operator data paths:

  clk_sys   ─┬─────┬─────┬─────┬─────┬─────
             │     │     │     │     │
  valid      ──────┘     └─────────────┘
             │     │     │     │     │
  ready      ─────────────────────────────
             │     │     │     │     │
  data       ──────X─────X─────X─────X─────

Transfer occurs on posedge clk_sys when valid=1 AND ready=1.
```

### 9.2 AXI4-Lite (Register Bus)

```
Write Channel (M04):
  Master asserts awvalid + awaddr
  Slave asserts awready -> transfer address
  Master asserts wvalid + wdata
  Slave asserts wready -> transfer data
  Slave asserts bvalid + bresp
  Master asserts bready -> complete write

Read Channel (M04):
  Master asserts arvalid + araddr
  Slave asserts arready -> transfer address
  Slave asserts rvalid + rdata + rresp
  Master asserts rready -> complete read
```

### 9.3 AXI4 (DRAM Data Path)

Full AXI4 with burst support for DRAM bulk transfers:

| Parameter | Value |
|-----------|-------|
| Address Width | 32-bit |
| Data Width | 256-bit |
| ID Width | 4-bit |
| Max Burst Length | 16 beats (4096 bytes per burst) |
| Burst Type | INCR (incrementing) |
| Response | OKAY, EXOKAY, SLVERR, DECERR |

### 9.4 D2D Protocol (M03 ↔ DRAM Die)

```
D2D Command Channel:
  cmd_valid: 1-bit, asserted for 1 cycle per command
  cmd_addr: 32-bit physical DRAM address
  cmd_rw: 1=Read, 0=Write
  cmd_burst: 4-bit burst length (1..16)
  cmd_ready: DRAM die backpressure

D2D Write Data Channel:
  wdata_valid: 1-bit, per beat
  wdata: 128-bit DDR (256-bit per clock)
  wdata_ready: backpressure from DRAM die

D2D Read Data Channel:
  rdata_valid: 1-bit, per beat
  rdata: 128-bit DDR (256-bit per clock)
  rdata_ready: NPU-side ready

Timing (row hit):
  Command → First Data: 16 cycles @ 625 MHz = 25.6 ns
  TSV propagation: < 5 ns
  Total D2D latency: < 100 ns (including DRAM array access)
```

### 9.5 Thread Dispatch Handshake (M08 → M01)

```
M08 asserts dispatch_valid + dispatch_tid + dispatch_opcode
M01 asserts dispatch_ready when able to accept new thread
Transfer on (valid & ready)

M01 asserts sched_yield when thread is waiting for resource
M08 marks thread as BLOCKED, schedules next READY thread
```

---

## 10. Implementation Constraints (ASAP7)

### 10.1 ASAP7 Cell Mapping Notes

| Logic Function | ASAP7 Cell | Notes |
|---------------|------------|-------|
| Standard cell | asap7sc6t_26 | 6-track standard cell library |
| SRAM | asap7sc7p5t_27/28 | 7.5-track SRAM bitcell |
| Flip-flop | DFFHQNx1_ASAP7_75t_R | High-density FF |
| Clock gate | ICGx1_ASAP7_75t_R | Integrated clock gate |
| Level shifter | LVLHLx1_ASAP7_75t_R | High-to-low level shifter |
| Isolation cell | ISOLx1_ASAP7_75t_R | Power-gating isolation |
| PLL | Analog macro (behavioral) | External analog; behavioral model in RTL |
| TSV I/O | Custom pad | Wafer-to-wafer TSV interface |

### 10.2 Timing Budgets

| Path | Target Delay | Notes |
|------|-------------|-------|
| clk_sys period | 2.0 ns | 500 MHz nominal |
| Clock uncertainty | 0.1 ns | PLL jitter + clock tree skew |
| Input delay (SRAM→M00) | 0.5 ns | SRAM read to MAC register |
| Output delay (M00→SRAM) | 0.5 ns | MAC output to SRAM write |
| M00 MAC critical path | 1.5 ns | FP16 multiply-add (3 pipeline stages) |
| M04 crossbar | 1.2 ns | AXI4-Lite address decode + mux |
| M09 attention score | 1.8 ns | FP32 multiply-add for QK^T |
| M11 RMSNorm | 1.5 ns | FP32 sqrt + divide |
| M12 softmax | 1.8 ns | FP32 exp (LUT + interpolate) |
| D2D clk_d2d period | 1.6 ns | 625 MHz |
| CDC synchronizer | 2 FF stages | MTBF > 10^9 hours |

### 10.3 Clock Tree Constraints

| Domain | Max Skew | Max Latency | Max Transition |
|--------|----------|-------------|----------------|
| clk_sys | 50 ps | 500 ps | 100 ps |
| clk_io | 100 ps | 1 ns | 200 ps |
| clk_d2d | 50 ps | 300 ps | 80 ps |

### 10.4 Area Budget per Module

| Module | Est. Area (mm^2) | % of Budget |
|--------|-----------------|-------------|
| M00 SystolicArray | 15.0 | 16.7% |
| M01 DataflowController | 3.0 | 3.3% |
| M02 SRAMScratchpad | 25.0 | 27.8% |
| M03 DRAMController | 8.0 | 8.9% |
| M04 SystemBus | 5.0 | 5.6% |
| M05 PowerManager | 1.0 | 1.1% |
| M06 ClockManager | 2.0 | 2.2% |
| M07 ResetManager | 0.5 | 0.6% |
| M08 ThreadScheduler | 3.0 | 3.3% |
| M09 AttentionUnit | 5.0 | 5.6% |
| M10 FFNMatMul | 4.0 | 4.4% |
| M11 RMSNormUnit | 1.5 | 1.7% |
| M12 RoPESoftMaxUnit | 3.0 | 3.3% |
| M13 ISADecoder | 1.0 | 1.1% |
| M14 SecureBoot | 2.0 | 2.2% |
| M15 JTAGInterface | 0.5 | 0.6% |
| M16 ISAInterface | 0.5 | 0.6% |
| Interconnect overhead | 10.0 | 11.1% |
| **Total** | **90.0** | **100%** |

---

## 11. FP8 E4M3 Format

### 11.1 Bit Layout

```
FP8 E4M3 (IEEE 754 FP8 extension):
  7    6 5 4    3 2 1 0
  ┌───┬───────┬──────────┐
  │ S │  EXP  │   MANT   │
  │   │  (4)  │   (3)    │
  └───┴───────┴──────────┘

  S: Sign bit (1 bit)
  EXP: Exponent (4 bits, bias=7)
  MANT: Mantissa (3 bits, implicit leading 1 for normals)
```

### 11.2 Value Encoding

| Category | Exp | Mant | Value |
|----------|-----|------|-------|
| NaN | 1111 | != 000 | NaN |
| +/-Inf | 1111 | 000 | +/-Inf |
| Normal max | 1110 | 111 | +/-448.0 |
| Normal min | 0001 | 000 | +/-2^-6 = 0.015625 |
| Subnormal max | 0000 | 111 | +/-0.013671875 |
| Subnormal min | 0000 | 001 | +/-2^-9 = 0.001953125 |
| +/-Zero | 0000 | 000 | +/-0 |

### 11.3 Rounding Rules

**Round-to-nearest-even (RNE)** for all FP8 operations:
- Guard bit, round bit, sticky bit (GRS)
- If G=1 and (R=1 or S=1 or LSB=1): round up
- Otherwise: truncate

**Subnormal Handling**: Flush-to-zero (FTZ). Subnormal inputs (exp=0, mant!=0) are treated as zero. Subnormal results are flushed to zero. This is standard ML practice for performance and avoids the significant latency penalty of subnormal arithmetic.

**Canonical NaN**: Quiet NaN is encoded as `S=0, Exp=1111, Mant=100` (0x7C). Signalling NaN is not used; all NaN inputs are treated as quiet NaN.

**Signed Zero**: +0 and -0 are treated as equal in comparisons. Division by zero produces +/-Inf matching the sign of the numerator.

**Special Values**:
- Overflow (exp > 14): saturate to +/-Inf (or max normal, configurable via CSR)
- Underflow (exp < 1): flush to zero (FTZ)
- NaN propagation: any NaN input → canonical NaN output (0x7C)

### 11.4 FP8 MAC Unit

```
FP8 MAC micro-architecture:
  Input: A (FP8), B (FP8), C (FP32 accumulator)
  Output: C' = A * B + C (FP32)

  Pipeline:
    Stage 0: Decode FP8 → {sign, exp, mant}
    Stage 1: Multiply mantissas (3+1 x 3+1 = 8-bit), add exponents (4+4 = 8-bit)
    Stage 2: Normalize + round to FP32
    Stage 3: FP32 accumulate (C' = product + C)
```

---

## 12. Module-to-Module Data Flow

### 12.1 Prefill Data Flow (per Transformer Layer)

```
Layer Input (from DRAM or previous layer)
    │
    ▼
┌──────────────────────────────────────────────────────────────────┐
│  Step 1: RMSNorm (M11)                                            │
│  ┌──────────┐                                                     │
│  │ M03 DMA  │──► M02 Bank 2 (activation) ──► M11 RMSNorm         │
│  │ (DRAM)   │    256 tokens x 576 dims       ──► M02 Bank 2      │
│  └──────────┘                                                     │
├──────────────────────────────────────────────────────────────────┤
│  Step 2: QKV Projection (M00 via M01)                             │
│  ┌──────────┐    ┌──────────┐                                     │
│  │ M02 B0/1 │──►│ M00 Syst │──► Q, K, V (each 256 x 576)        │
│  │ (weights)│    │  Array   │    ──► M02 Bank 2                  │
│  └──────────┘    └──────────┘                                     │
├──────────────────────────────────────────────────────────────────┤
│  Step 3: RoPE (M12) on Q, K                                       │
│  ┌──────────┐                                                     │
│  │ M02 B2   │──► M12 RoPE ──► Q_rope, K_rope                     │
│  │ (Q,K)    │                  ──► M02 Bank 2                     │
│  └──────────┘                                                     │
├──────────────────────────────────────────────────────────────────┤
│  Step 4: Attention (M09 + M00 + M12)                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                    │
│  │ M02 B2   │──►│ M00 QK^T │──►│ M12      │──► scores           │
│  │ (Q,K,V)  │    │ (scores) │    │ SoftMax  │                    │
│  └──────────┘    └──────────┘    └──────────┘                    │
│                       │                │                          │
│                       ▼                ▼                          │
│                  ┌──────────┐    ┌──────────┐                    │
│                  │ M00 AV   │◄───│ M02 B2   │──► KV cache write  │
│                  │ (output) │    │ (V)      │    (M03 DMA → DRAM) │
│                  └──────────┘    └──────────┘                    │
│                       │                                           │
│                       ▼                                           │
│                  Attention output (256 x 576) → M02 Bank 2        │
├──────────────────────────────────────────────────────────────────┤
│  Step 5: FFN (M10 + M00 + M11)                                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                    │
│  │ M02 B2   │──►│ M00 Gate │    │ M00 Up   │ (parallel)          │
│  │ (attn)   │    │ (2304)   │    │ (2304)   │                    │
│  └──────────┘    └──────────┘    └──────────┘                    │
│                       │                │                          │
│                       ▼                ▼                          │
│                  ┌──────────┐    ┌──────────┐                    │
│                  │ gate_out │    │ up_out   │                    │
│                  └──────────┘    └──────────┘                    │
│                       │                │                          │
│                       ▼                ▼                          │
│                  ┌──────────────────────────┐                    │
│                  │  SiLU(gate) ⊙ up_out    │                    │
│                  │  (M11 element-wise)      │                    │
│                  └──────────┬───────────────┘                    │
│                             │                                     │
│                             ▼                                     │
│                  ┌──────────┐                                     │
│                  │ M00 Down │──► FFN output (256 x 576)          │
│                  │ (576)    │    + residual add                  │
│                  └──────────┘    → M02 Bank 2                    │
├──────────────────────────────────────────────────────────────────┤
│  Step 6: Write-back                                               │
│  ┌──────────┐                                                     │
│  │ M02 B2   │──► M03 DMA ──► DRAM (next layer input)             │
│  └──────────┘                                                     │
└──────────────────────────────────────────────────────────────────┘
```

### 12.2 Decode Data Flow (per Token, per Layer)

```
Single Token Input (from DRAM KV cache / previous layer output)
    │
    ▼
  M11 RMSNorm ──► M00 QKV ──► M12 RoPE (Q,K) ──► M09 Attention
                                                       │
                              ┌────────────────────────┘
                              │
                              ├─► M03 DMA: read K_cache[0..N-1], V_cache[0..N-1]
                              ├─► M00: QK^T (1 x N)
                              ├─► M12: SoftMax
                              └─► M00: AV (1 x 576)
                                       │
                                       ▼
                              M10 FFN (Gate + Up + SiLU + Down)
                                       │
                                       ▼
                              M03 DMA: write output to DRAM
                              M03 DMA: update KV cache (new K, V)
```

### 12.3 Weight Prefetch Flow (Thread 1, overlapping with Thread 0 compute)

```
M08 ThreadScheduler dispatches Thread 1 (prefetch)
    │
    ▼
  M01 DataflowController: DMA request
    │
    ▼
  M03 DRAMController: DMA read from DRAM weight region
    │
    ▼
  M02 SRAM: write to Bank 0/1 (pong buffer)
    │
    ▼
  M01: weight_load_done → M08: thread_yield
    │
    ▼
  M08: barrier sync at layer boundary
    │
    ▼
  M00: swap weight buffer (ping ↔ pong)
```

---

## 13. Verification Plan Seed

### 13.1 Verification Strategy

| Level | Scope | Tool | Owner |
|-------|-------|------|-------|
| Block-level | Per-module (M00-M16) | Verilator | bba-guru-verification |
| Integration | Module-to-module data flow | Verilator | bba-guru-verification |
| System-level | End-to-end TinyStories inference | Verilator | bba-guru-verification |
| Formal | CDC, handshake protocols | yosys-smtbmc | bba-guru-verification |
| Gate-level | Post-synthesis netlist | Verilator + OpenSTA | bba-guru-synthesis |

### 13.2 Key Verification Items

| Item | Module | Priority | Method |
|------|--------|----------|--------|
| Systolic array MAC correctness | M00 | HIGH | Random test vectors, compare vs C model |
| FP8/FP16/INT8 precision | M00 | HIGH | Exhaustive for 8-bit, random for 16-bit |
| Weight stationary mode | M00 | HIGH | Directed test: load weights, stream activations |
| Pipeline stage synchronization | M01 | HIGH | Assertion-based: no data loss, no deadlock |
| DMA transfer correctness | M03 | HIGH | Random addresses, sizes, check data integrity |
| KV cache R/W consistency | M09/M03 | HIGH | Write K,V, read back, verify |
| Attention output vs golden | M09 | HIGH | Compare vs PyTorch reference |
| RMSNorm vs golden | M11 | HIGH | Compare vs PyTorch reference |
| RoPE vs golden | M12 | HIGH | Compare vs PyTorch reference |
| Online softmax vs naive softmax | M12 | HIGH | Numerical comparison, check max error < 1e-5 |
| CDC synchronization | M04/M16 | MEDIUM | Assertion: no metastability propagation |
| ECC single-bit correction | M02/M03 | MEDIUM | Inject single-bit error, verify correction |
| ECC double-bit detection | M02/M03 | MEDIUM | Inject double-bit error, verify detection |
| Secure boot flow | M14 | MEDIUM | Valid + invalid signature test |
| Power state transitions | M05 | MEDIUM | Check all transitions, verify isolation |
| Reset sequence | M07 | MEDIUM | Check all reset domains release order |
| JTAG boundary scan | M15 | LOW | IEEE 1149.1 compliance test |
| ISA command interface | M16 | LOW | All opcodes, CRC check, error handling |

### 13.3 Assertion Coverage

| Assertion Type | Target Count | Description |
|---------------|-------------|-------------|
| Valid/Ready protocol | ~50 | No data loss, no deadlock, no overflow |
| AXI4 protocol | ~20 | Handshake rules, burst boundaries |
| CDC synchronization | ~10 | 2-FF synchronizer, no combinational CDC |
| FIFO overflow/underflow | ~16 | All internal FIFOs |
| FSM legal states | ~17 | All module FSMs stay in legal states |
| ECC error flags | ~4 | Corrected/uncorrected assertion |
| Power sequence | ~6 | Power-up/down ordering |

---

## 14. DFT Plan Seed

### 14.1 Scan Chain Strategy

| Attribute | Target |
|-----------|--------|
| Scan coverage | >= 95% stuck-at |
| Scan chain count | 16 chains |
| Scan chain length | ~5000 FF per chain (balanced) |
| Scan compression | 10x (optional) |
| Test clock | clk_sys (scan shift: 50 MHz max) |
| Scan enable | scan_en (dedicated pin or JTAG-controlled) |

### 14.2 Memory BIST

| Memory | Type | Algorithm | Size |
|--------|------|-----------|------|
| M02 SRAM Bank 0 | SRAM | March C- | 128 KB |
| M02 SRAM Bank 1 | SRAM | March C- | 128 KB |
| M02 SRAM Bank 2 | SRAM | March C- | 128 KB |
| M02 SRAM Bank 3 | SRAM | March C- | 128 KB |
| M03 DMA FIFO | Register File | March LR | 8 KB |
| All register files | Flip-flop | Scan test | ~80K FF |

### 14.3 JTAG Instructions

| IR Code | Instruction | Description |
|---------|------------|-------------|
| 0000 | BYPASS | Bypass register |
| 0001 | IDCODE | Device ID (32-bit) |
| 0010 | SAMPLE/PRELOAD | Sample I/O or preload boundary scan |
| 0011 | EXTEST | External test (boundary scan) |
| 0100 | INTEST | Internal test |
| 0101 | SCAN_TEST | Internal scan chain access |
| 0110 | MBIST_RUN | Run memory BIST |
| 0111 | MBIST_RESULT | Read MBIST result |

### 14.4 Test Access Port (TAP)

| Signal | Direction | Description |
|--------|-----------|-------------|
| TCK | Input | Test clock (max 50 MHz) |
| TMS | Input | Test mode select |
| TDI | Input | Test data in |
| TDO | Output | Test data out |
| TRST_n | Input | Test reset (active low, optional) |

---

## 15. CDC Waivers

| From Clock | To Clock | Signal | Justification |
|-----------|----------|--------|---------------|
| clk_sys | clk_io | M04 bus → M15/M16 | 2-stage sync (single-bit) / Async FIFO (data); standard async domain crossing |
| clk_io | clk_sys | M15/M16 → M04 bus | 2-stage sync / Async FIFO |
| clk_sys | clk_aon | M05 DVFS cmd | Handshake (req/ack); low rate (< 1 kHz) |
| clk_aon | clk_sys | M05/M06/M07 status | 2-stage sync; status/control signals, stable for many cycles |
| clk_sys | clk_d2d | M03 sys → M03 d2d | Async FIFO (M03 internal); high throughput, 10 GB/s |

---

## 16. Path Exceptions

| Type | From | To | Cycles | Justification |
|------|------|----|--------|---------------|
| false_path | clk_sys | clk_aon | — | DVFS handshake; async crossing, no timing requirement |
| false_path | clk_aon | clk_sys | — | Status sync; async crossing |
| false_path | clk_sys | clk_io | — | CDC; async crossing |
| multicycle | M00 weight_buf | M00 PE_reg | 2 | Weight load path: SRAM read → distributed register; 2-cycle latency acceptable |
| multicycle | M03 dma_req | M03 d2d_cmd | 3 | DMA command → D2D command; multi-cycle processing |

---

## 17. Requirements Traceability Matrix

### 17.1 PRD → MAS Mapping

| PRD REQ ID | MAS Section | MAS Module(s) | KPI |
|-----------|-------------|---------------|-----|
| REQ-COMPUTE-001 | §3.1, §11.4 | M00 | FP8 >= 2 TOPS |
| REQ-COMPUTE-002 | §3.1 | M00 | FP16 >= 1 TOPS |
| REQ-COMPUTE-003 | §3.1 | M00 | INT8 >= 2 TOPS |
| REQ-COMPUTE-004 | §3.1, §5.1 | M00 | Weight stationary mode |
| REQ-COMPUTE-005 | §3.2, §4.1 | M01 | Pipeline util >= 80% |
| REQ-COMPUTE-006 | §3.9, §8.3 | M08 | >= 2 concurrent threads |
| REQ-COMPUTE-007 | §3.1, §11.3 | M00, M09, M10, M11, M12 | Mixed precision support |
| REQ-COMPUTE-008 | §3.10-3.13, §12 | M09, M10, M11, M12 | Transformer ops coverage |
| REQ-MEM-001 | §3.4 | M03 | DRAM >= 2 GB |
| REQ-MEM-002 | §3.4 | M03 | DRAM BW >= 10 GB/s |
| REQ-MEM-003 | §3.4 | M03 | DRAM latency <= 100 ns |
| REQ-MEM-004 | §3.3, §7.1 | M02 | SRAM >= 512 KB |
| REQ-MEM-005 | §3.3, §3.4 | M02, M03 | ECC SECDED |
| REQ-IO-001 | §3.16, §14.3 | M15 | JTAG IEEE 1149.1 |
| REQ-IO-002 | §3.17 | M16 | ISA interface |
| REQ-PERF-001 | §3.7, §10.2 | M06 | Core >= 500 MHz |
| REQ-PERF-002 | §5.2, §12.2 | M00, M01, M08 | Decode TPS >= 100 (FP32) |
| REQ-PERF-003 | §5.2, §12.2 | M00, M01, M08 | Decode TPS >= 200 (FP16) |
| REQ-PERF-004 | §5.2, §12.1 | M01, M03, M08 | TTFT <= 50 ms |
| REQ-PWR-001 | §3.6, §4.2 | M05 | TDP <= 2W |
| REQ-PWR-002 | §3.6, §4.2 | M05, M06 | Idle <= 0.1W |
| REQ-PWR-003 | §3.6, §4.2 | M05, M06 | DVFS >= 2 points |
| REQ-AREA-001 | §10.4 | All | Die <= 90 mm^2 |
| REQ-D2D-001 | §3.4 | M03 | D2D BW >= 10 GB/s |
| REQ-D2D-002 | §9.4 | M03 | D2D protocol |
| REQ-D2D-003 | §3.4 | M03 | D2D <= 5 pJ/bit |
| REQ-D2D-004 | §3.4 | M03 | D2D latency <= 100 ns |
| REQ-SEC-001 | §3.15, §4.5 | M14 | Secure boot |
| REQ-SEC-002 | §3.15 | M14 | Supply chain security |
| REQ-REL-001 | §10.2 | All | MTTF >= 100k hrs |
| REQ-REL-002 | §3.3, §3.4 | M02, M03 | SER <= 1000 FIT |

### 17.2 ARCH → MAS Mapping

| ARCH Section | MAS Section | Status |
|-------------|-------------|--------|
| §3.1 Systolic Array | §3.1, §5.1 | Complete |
| §3.2 Spatial Dataflow | §3.2, §4.1 | Complete |
| §3.3 Operator Pipeline | §3.10-3.13, §5.2-5.3 | Complete |
| §4.1 Memory Hierarchy | §7.1-7.3 | Complete |
| §4.2 SRAM Scratchpad | §3.3 | Complete |
| §4.3 DRAM Controller | §3.4 | Complete |
| §4.4 Memory Map | §6.1 | Complete |
| §5.1 Clock Domains | §3.7 | Complete |
| §5.2 Clock Distribution | §3.7 | Complete |
| §5.3 CDC Strategy | §15 | Complete |
| §5.4 Reset Architecture | §3.8, §4.3 | Complete |
| §6.1 Power Domains | §3.6 | Complete |
| §6.2 Power States | §4.2 | Complete |
| §6.3 DVFS | §3.6 | Complete |
| §7.1 Bus Topology | §3.5 | Complete |
| §7.2 D2D Interconnect | §3.4, §9.4 | Complete |
| §8.1 Secure Boot | §3.15, §4.5 | Complete |
| §9 DFT | §14 | Complete |

---

## 18. Design Decisions and Tradeoffs

### MAS-ADR-001: M11 + M12 Module Split
- **Decision**: Split old M11_RMSNormRoPE into M11_RMSNormUnit and M12_RoPESoftMaxUnit
- **Rationale**: RMSNorm and RoPE+SoftMax have different pipeline depths, different bus interfaces, and different usage patterns. Combining them created unnecessary coupling.
- **Tradeoff**: Two modules instead of one; small increase in top-level wiring. Justified by cleaner interfaces and independent development.

### MAS-ADR-002: 1024-bit SRAM Read Width for Weight Buffer
- **Decision**: 1024-bit wide read port for Banks 0 and 1
- **Rationale**: 32 MACs x 32-bit (FP32) = 1024-bit; one cycle to feed the entire systolic array row. 256-bit write port for DMA (4:1 write-to-read ratio).
- **Tradeoff**: Wide SRAM read port increases area; justified by 64 GB/s read bandwidth requirement.

### MAS-ADR-003: 256-bit Write, 1024-bit Read for Weight Banks
- **Decision**: Asymmetric read/write widths for weight banks
- **Rationale**: DMA writes 256-bit (matches AXI4 data width), systolic array reads 1024-bit (matches 32-wide MAC array). Asymmetric ports optimize for actual usage patterns.
- **Tradeoff**: Custom SRAM macro or register file implementation; acceptable for ASAP7.

### MAS-ADR-004: Round-Robin + Aging for Bus Arbitration
- **Decision**: Priority-based round-robin with aging escalation
- **Rationale**: Pure round-robin can starve high-priority debug access; pure priority can starve low-priority maintenance. Aging prevents starvation while preserving priority.
- **Tradeoff**: Slightly more complex arbiter; +20% area vs pure round-robin.

### MAS-ADR-005: Online Softmax
- **Decision**: Online softmax algorithm (streaming)
- **Rationale**: Avoids storing full attention score matrix (N x N); reduces SRAM requirement by O(N^2). Standard in Transformer accelerators.
- **Tradeoff**: More complex control logic; 5 pipeline stages vs 3 for naive softmax. Justified by memory savings.

### MAS-ADR-006: DRAM BFM for Verification
- **Decision**: Verilog behavioral model (BFM) for DRAM die
- **Rationale**: DRAM die co-design is not in Babel scope; BFM provides cycle-accurate interface for verification. D2D protocol defined in §9.4 is the contract between NPU and DRAM.
- **Tradeoff**: Cannot verify DRAM-side timing; acceptable for RTL verification phase.

---

## 19. Open Issues

| ID | Issue | Impact | Resolution |
|----|-------|--------|------------|
| MAS-OPEN-001 | M11 and M12 are new RTL; no existing implementation | HIGH | bba-guru-rtl must create from scratch; algorithmic reference provided in §3.12-3.13 and datapath/ documents |
| MAS-OPEN-002 | SRAM macro availability in ASAP7 (1024-bit read port) | MEDIUM | Fallback: use 4-way interleaved 256-bit SRAM macros with address interleaving; adds <= 4 cycles overhead to weight load |
| MAS-OPEN-003 | PLL behavioral model accuracy | LOW | Use ideal clock for RTL sim; OpenSTA for timing |
| MAS-OPEN-004 | FP8 E4M3 golden model | MEDIUM | Reference implementation in C for verification |
| MAS-OPEN-005 | 2:1 structured sparsity for TOPS calculation | MEDIUM | Not yet implemented; TOPS numbers assume sparsity |
| MAS-OPEN-006 | Old netlist uses `ext_clk_50MHz`; ARCH/MAS specify 25 MHz | LOW | Rename top-level port to `ext_clk_25MHz` in RTL re-generation; PLL multiplies to VCO frequency |

---

## 20. Quality Checklist

- [x] All 17 modules (M00-M16) have complete RTL interface definitions
- [x] All modules have FSM definitions with states and transitions
- [x] All pipeline stages defined for M00, M09, M10
- [x] Register map complete with 6 modules (M01, M05, M06, M08, M14)
- [x] SRAM buffer sizing complete (512 KB total, 4 banks)
- [x] Arbitration policies defined for M04, M03, M08, M01
- [x] Handshake protocols defined: valid/ready, AXI4-Lite, AXI4, D2D, Thread dispatch
- [x] ASAP7 implementation constraints and timing budgets
- [x] FP8 E4M3 format specification (FTZ policy added per spec review)
- [x] Module-to-module data flow diagrams (prefill, decode, weight prefetch)
- [x] CDC waivers documented (5 crossings)
- [x] Path exceptions documented (5 exceptions)
- [x] PRD-to-MAS and ARCH-to-MAS traceability matrices
- [x] JTAG TAP FSM reference added (IEEE 1149.1 standard)
- [x] SRAM fallback plan documented (4-way interleaved 256-bit)
- [ ] M11 and M12 TBD: RTL implementation (assigned to bba-guru-rtl)
- [ ] M11 and M12 TBD: FSM documents (assigned to bba-guru-rtl)
- [ ] M11 and M12 TBD: datapath documents (assigned to bba-guru-rtl)
- [ ] SHA256 hashes in mas.json need real computation (placeholders match schema pattern)
- [ ] Top-level port rename: ext_clk_50MHz → ext_clk_25MHz (see MAS-OPEN-006)