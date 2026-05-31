---
doc_id: DOC-D2-02-ARCH-DATFLOW
doc_type: ARCH
title: Data Flow Architecture — tinystories_npu
version: 1.0
status: draft
parent: DOC-D2-01-ARCH
generated: 2026-05-31T14:00:00+08:00
---

# Data Flow Architecture — tinystories_npu

## 1. Overview

The tinystories_npu data flow implements a **spatial architecture** where data movement between compute, memory, and I/O is orchestrated by the DataflowController (M01). The architecture separates control-plane traffic (AXI4-Lite register bus via M04) from data-plane traffic (dedicated high-bandwidth paths).

## 2. Data Plane Topology

```
                          ┌──────────────┐
                          │  DRAM (2 GB) │
                          │  (3D Stacked)│
                          └──────┬───────┘
                                 │ TSV (128-bit DDR, 10 GB/s)
                                 │
                          ┌──────┴───────┐
                          │ M03 DRAM Ctrl │
                          │ (D2D PHY +    │
                          │  DMA Engine)  │
                          └──────┬───────┘
                                 │ 256-bit internal bus
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
              ┌──────────┐ ┌──────────┐ ┌──────────┐
              │ M02 SRAM │ │ M01 Data │ │ M00 Sys  │
              │ (512 KB) │ │ flow Ctrl│ │ Array    │
              │ Banks 0-3│ │          │ │ (32×32)  │
              └────┬─────┘ └────┬─────┘ └────┬─────┘
                   │            │            │
                   │    ┌───────┴───────┐    │
                   │    │ Operator Bus  │    │
                   │    │ (512-bit)     │    │
                   │    └───┬───┬───┬───┘    │
                   │        │   │   │        │
                   ▼        ▼   ▼   ▼        ▼
              ┌─────────────────────────────────┐
              │       Operator Pipeline          │
              │  ┌──────┐┌──────┐┌──────┐┌────┐ │
              │  │ Attn ││ FFN  ││RMSN  ││RoPE│ │
              │  │ (M09)││(M10) ││(M11) ││M12 │ │
              │  └──────┘└──────┘└──────┘└────┘ │
              └─────────────────────────────────┘
```

## 3. Data Path Descriptions

### 3.1 Weight Load Path (DRAM → SRAM → Systolic Array)

```
Phase 1: DRAM → SRAM (DMA)
  M01 issues DMA command to M03
  M03 reads weight tile from DRAM (burst read, 128B per burst)
  M03 writes to M02 SRAM Bank 0/1 (ping-pong)
  DMA size: 256 KB (one weight tile for 576×576 matmul)

Phase 2: SRAM → Systolic Array
  M01 issues systolic load command
  M02 streams weight data to M00 (1024-bit wide, 32 MACs × 32-bit in parallel)
  Weight loading: 32 rows × 32 cols × 2 bytes (FP16) = 2 KB
  Load latency: 2 KB / 64 B/cycle = 32 cycles @ 500 MHz = 64 ns

Bandwidth: 1024-bit × 500 MHz = 64 GB/s peak
```

### 3.2 Activation Flow Path (DRAM → SRAM → Operators)

```
Prefill Phase (prompt tokens: 1..256):
  Token embeddings in DRAM (256 × 576 × 2B/FP16 = 288 KB)
  └─► M03 DMA to M02 Bank 2 (activation buffer)
      └─► M01 dispatches to:
          ├─► M11 RMSNorm: 256 vectors × 576 dims
          ├─► M00 QKV Projection: 256 × 576 × 3 × 576 matrix multiply
          ├─► M09 Attention: QK^T + softmax + AV, 256² score matrix
          └─► M10 FFN: 256 × 576 × 2304 × 576 matrix multiply

Decode Phase (1 token at a time):
  Single token embedding from SRAM Bank 2
  └─► M11 RMSNorm: 1 vector × 576 dims
      └─► M00 QKV Projection: 576 × 3 × 576 matrix multiply
          └─► M09 Attention: QK^T (1 × seq_len) + weighted sum
              └─► M10 FFN: 576 × 2304 × 576 matrix multiply
                  └─► Output stored to SRAM → M03 DMA to DRAM
```

### 3.3 KV Cache Path (M09 ↔ M03 ↔ DRAM)

```
KV Cache Write (decode):
  M09 computes new K, V for current token
  └─► M03 DMA writes K, V to DRAM KV cache region
      (2 × 576 × 2B = 2.25 KB per token per layer)
      Total for 2048 tokens × 8 layers: ~36 MB

KV Cache Read (attention):
  M03 DMA reads all previous K, V for current attention step
  └─► M02 Bank 3 (KV workspace, 64 KB)
      └─► M09 reads K, V for attention score computation
```

### 3.4 Output Path (Operators → SRAM → DRAM)

```
Operator output → SRAM Bank 2 (activation write-back)
  └─► M01 detects pipeline stage completion
      └─► M03 DMA writes output to DRAM (next layer input)
          └─► Final layer output: logits → token sampling (host/ISA)
```

## 4. Pipeline Timing (Prefill)

```
Time ─────────────────────────────────────────────────────►

Layer 0:
  RMSNorm  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  QKV Proj ░░░░████████████████████░░░░░░░░░░░░░░░░░░░░░░░
  Attention░░░░░░░░░░░░░░░░████████████████████░░░░░░░░░░░
  FFN      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████████████

Layer 1:
  RMSNorm  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████░░
  QKV Proj ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██████
  ...

Pipeline Utilization = (active compute cycles) / (total cycles)
Target: ≥80% (REQ-COMPUTE-005)
```

## 5. Bandwidth Analysis

| Data Path | Width | Clock | Peak BW | Sustained BW | Bottleneck |
|-----------|-------|-------|---------|-------------|------------|
| DRAM → SRAM (DMA) | 128-bit DDR | 625 MHz | 10 GB/s | 8 GB/s (80%) | TSV interface |
| SRAM → Systolic Array | 1024-bit | 500 MHz | 64 GB/s | 50 GB/s | SRAM read ports |
| Systolic Array → Accumulator | 32×FP32 | 500 MHz | 64 GB/s | — | — |
| Operator Bus | 512-bit | 500 MHz | 32 GB/s | 25 GB/s | Bus arbitration |
| Control Bus (AXI4-Lite) | 32-bit | 50 MHz | 200 MB/s | 50 MB/s | Not a bottleneck (CSR only) |

### Key Insight:

The architecture is **compute-bound** for large matrix multiplications and **memory-bound** for KV cache reads during decode. The 10 GB/s DRAM bandwidth is the limiting factor for KV cache access (36 MB for full context).

**Decode TPS calculation (FP16):**
- Per-token per-layer compute: QKV (576×576×3) + Attention (1×2048×576) + FFN (576×2304 + 576×576)
  = ~3M MACs × 2 (FP16) = ~6M ops per layer
- 8 layers: ~48M ops per token
- Systolic array: 1024 MACs/cycle × 500M = 512G MAC/s
- Theoretical TPS = 512G / 48M ≈ 10,666 token/s (compute-bound limit)
- Actual TPS limited by memory: KV cache read 2.25 KB × 2048 tokens × 8 layers = 36 MB per token
  at 10 GB/s → 3.6 ms per token → ~277 TPS
- With double-buffering and compute/memory overlap: expect ≥200 TPS ✓

## 6. Thread-Level Parallelism

```
Thread 0 (Compute-bound)          Thread 1 (Memory-bound)
┌─────────────────────┐          ┌─────────────────────┐
│ Attention Score     │          │ Load next layer     │
│ (M09, M00)          │          │ weights from DRAM   │
│                     │          │ (M03 → M02)         │
│ ~500 cycles         │          │ ~2000 cycles        │
└─────────┬───────────┘          └──────────┬──────────┘
          │                                 │
          └─────────┬───────────────────────┘
                    │
          ┌─────────┴───────────┐
          │    Barrier / Sync   │
          │    (M08 ThreadSched)│
          └─────────────────────┘
```

Thread 0 processes compute while Thread 1 prefetches data, achieving effective pipeline utilization ≥80%.

## 7. Flow Control and Backpressure

```
Operator Pipeline Backpressure:

  M11 RMSNorm ─► valid/ready ─► M00 QKV Projection
                                     │
                          valid/ready │
                                     ▼
                               M09 Attention ─► valid/ready ─► M10 FFN
                                                                    │
                                                         valid/ready │
                                                                    ▼
                                                              M01 write-back

Backpressure Rules:
  - Each stage asserts ready=0 when internal buffer full
  - Upstream stage stalls (holds valid=1, waits for ready=1)
  - M01 DataflowController monitors all stages; adjusts dispatch rate
  - Deadlock prevention: all buffers sized for worst-case pipeline fill
```

## 8. SRAM Bank Allocation Map

| Bank | Size | Usage | Access Pattern |
|------|------|-------|---------------|
| Bank 0 | 128 KB | Weight tile (ping) | Read-only, 1024-bit wide |
| Bank 1 | 128 KB | Weight tile (pong) | Read-only, 1024-bit wide |
| Bank 2 | 128 KB | Activation buffer | Read/write, 256-bit wide |
| Bank 3 | 64 KB | KV cache workspace | Read/write, 256-bit wide |
| Bank 3 (upper) | 64 KB | Thread context | Read/write, 32-bit wide |