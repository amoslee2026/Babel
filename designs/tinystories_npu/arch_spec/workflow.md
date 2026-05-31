---
doc_id: DOC-D2-03-ARCH-WORKFLOW
doc_type: ARCH
title: Execution Workflow — tinystories_npu
version: 1.0
status: draft
parent: DOC-D2-01-ARCH
generated: 2026-05-31T14:00:00+08:00
---

# Execution Workflow — tinystories_npu

## 1. Power-On to Inference Ready

```
┌─────────────────────────────────────────────────────────────────┐
│                        BOOT SEQUENCE                             │
│                                                                 │
│  POR ─► M07 Reset Sequencer                                     │
│    │                                                             │
│    ├─[0] clk_aon stable, rst_aon_n released                     │
│    │    M05 PowerManager initializes to IDLE state               │
│    │    M06 ClockManager starts internal RC oscillator           │
│    │                                                             │
│    ├─[1] M14 SecureBoot executes:                               │
│    │    - Read firmware header from DRAM 0x0000_0000             │
│    │    - Verify ECDSA signature against OTP public key          │
│    │    - On PASS: sec_status_pass=1, continue boot              │
│    │    - On FAIL: sec_status_fail=1 → lockdown mode             │
│    │                                                             │
│    ├─[2] M06 enables PLL:                                       │
│    │    - VCO locks to 1 GHz                                     │
│    │    - clk_sys = VCO/2 = 500 MHz                              │
│    │    - clk_io  = VCO/20 = 50 MHz                              │
│    │    - PLL lock signal → M07                                  │
│    │                                                             │
│    ├─[3] M07 releases rst_sys_n, rst_io_n                        │
│    │    - All main-domain modules come out of reset               │
│    │    - M04 SystemBus arbitration active                       │
│    │                                                             │
│    └─[4] Firmware runtime starts:                                │
│         - ISA I/F (M16) enabled if sec_status_pass               │
│         - JTAG (M15) enabled if lifecycle = TEST/DEV             │
│         - Model weights preloaded to DRAM at 0x1000_0000         │
│         - System enters ACTIVE state                             │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Inference Execution Flow

### 2.1 Host Command Sequence

```
Host (via ISA I/F M16)
  │
  ├─► CMD_LOAD_MODEL <model_addr> <model_size>
  │     M13 ISADecoder → M01 DataflowController
  │     M01 → M03: DMA weights from ISA buffer to DRAM weight region
  │
  ├─► CMD_INFERENCE_PREFILL <prompt_addr> <prompt_len>
  │     └─► Prefill Flow (see §2.2)
  │
  └─► CMD_INFERENCE_DECODE [repeat N times]
        └─► Decode Flow (see §2.3)
```

### 2.2 Prefill Flow (Prompt Processing)

```
M08 ThreadScheduler receives CMD_INFERENCE_PREFILL
  │
  ├─► Thread 0: Prefill Pipeline
  │     │
  │     ├─► Stage 0: M11 RMSNorm
  │     │     Input: Token embeddings (N tokens × 576 dims, from DRAM)
  │     │     Output: Normalized embeddings → SRAM Bank 2
  │     │     Latency: ~576 cycles per token
  │     │
  │     ├─► Stage 1: M00 QKV Projection (via Systolic Array)
  │     │     Input: RMSNorm output (N × 576)
  │     │     Weights: Q_w, K_w, V_w (each 576×576, from SRAM Bank 0/1)
  │     │     Output: Q, K, V (each N × 576) → SRAM Bank 2
  │     │     Latency: ~(N×576×576×3) / 1024 MAC/cycle ≈ 580 cycles for N=256
  │     │
  │     ├─► Stage 2: M09 Multi-Head Attention
  │     │     Input: Q, K, V from SRAM
  │     │     Output: Attention output (N × 576)
  │     │     │
  │     │     │  2a. M00: QK^T (score matrix, N×N)
  │     │     │      Latency: ~N²×576 / 1024 cycles
  │     │     │
  │     │     │  2b. M12: Softmax (per row)
  │     │     │      Latency: ~N cycles
  │     │     │
  │     │     │  2c. M00: AV (weighted sum, N×576)
  │     │     │      Latency: ~N×576×N / 1024 cycles
  │     │     │
  │     │     └─► Output: Attention output → SRAM
  │     │
  │     ├─► Stage 3: M10 FFN
  │     │     Input: Attention output (N × 576)
  │     │     Weights: W_gate (576×2304), W_up (576×2304), W_down (2304×576)
  │     │     │
  │     │     │  3a. M00: Gate projection (N×576 × 576×2304)
  │     │     │  3b. M00: Up projection   (N×576 × 576×2304)
  │     │     │  3c. M11: SiLU activation (element-wise)
  │     │     │  3d. M00: Down projection (N×2304 × 2304×576)
  │     │     │
  │     │     └─► Output: FFN output (N × 576) → DRAM (via M03 DMA)
  │     │
  │     └─► Repeat for all 8 layers
  │
  └─► Last layer output → stored in DRAM as KV cache initial state
      └─► Interrupt/Done signal to host via M16
```

### 2.3 Decode Flow (Token-by-Token Generation)

```
For each new token (auto-regressive loop):

  M08 ThreadScheduler dispatch:
    │
    ├─► Thread 0: Compute Pipeline
    │     │
    │     ├─► M11 RMSNorm: 1 token × 576 dims
    │     │     Latency: ~576 cycles
    │     │
    │     ├─► M00 QKV Projection: 576 × (3×576)
    │     │     Latency: ~(576×576×3) / 1024 ≈ 972 cycles
    │     │
    │     ├─► M09 Attention:
    │     │     │
    │     │     │  [M03 DMA: read K_cache[0..N-1], V_cache[0..N-1] from DRAM]
    │     │     │  [M00: QK^T (1 × N)]  → N cycles
    │     │     │  [M12: Softmax]        → ~N cycles
    │     │     │  [M00: AV (1 × 576)]   → N×576/1024 cycles
    │     │     │
    │     │     └─► Attention output (1 × 576)
    │     │
    │     ├─► M10 FFN: 1×576 × 576×2304 × 2304×576
    │     │     Latency: ~(576×2304×2) / 1024 ≈ 2592 cycles
    │     │
    │     └─► M03 DMA: write output to DRAM, update KV cache
    │
    ├─► Thread 1: Prefetch next layer weights
    │     M03 DMA: DRAM → SRAM Bank 0/1 (next layer weight tile)
    │     Overlaps with Thread 0 compute
    │
    └─► Barrier sync at layer boundary
        └─► Final layer output → M16 returns token logits to host

Per-layer decode latency (FP16, single thread, ideal):
  RMSNorm:           576 cycles
  QKV Projection:    ~972 cycles
  Attention:          ~N + N + N×576/1024 ≈ 2300 cycles (N=256)
  FFN:              ~2592 cycles
  DMA overhead:      ~500 cycles
  ─────────────────────────
  Total/layer:      ~6940 cycles @ 500 MHz = 13.88 µs
  All 8 layers:     ~111 µs
  Theoretical TPS:  1 / 111µs ≈ 9,000 token/s

Actual TPS (with DRAM KV cache read overhead, N=256):
  KV cache read: 2.25 KB × 256 tokens × 8 layers = 4.5 MB
  At 10 GB/s: 4.5 MB / 10 GB/s = 0.45 ms
  Total/layer: 13.88 µs compute + 56 µs memory = 69.88 µs
  8 layers: ~559 µs → ~1,788 TPS
  ✓ Exceeds 200 TPS target (REQ-PERF-003)
```

## 3. Power State Transitions

```
                    ┌──────────┐
          ┌────────►│  ACTIVE  │◄────────┐
          │         │ 1.8W max │         │
          │         └────┬─────┘         │
          │              │               │
          │   DVFS down  │  DVFS up      │
          │   (M05)      │  (M05)        │
          │              ▼               │
          │         ┌──────────┐         │
          │         │ DVFS_LOW │         │
          │         │ 0.8W     │         │
          │         └────┬─────┘         │
          │              │               │
          │   idle       │  wake         │
          │   detect     │  event        │
          │   (M08)      │               │
          │              ▼               │
          │         ┌──────────┐         │
          └─────────│  IDLE    │─────────┘
                    │ ≤0.1W    │
                    └────┬─────┘
                         │
               deep idle │  wake event
               timeout   │  (ISA I/F)
                         ▼
                    ┌──────────┐
                    │  SLEEP   │
                    │ ≤5 mW    │
                    │ (POR/ISA │
                    │  to wake)│
                    └──────────┘

Transition triggers:
  ACTIVE → DVFS_LOW: M08 detects low utilization (<30%), M05 initiates DVFS
  DVFS_LOW → ACTIVE: M08 detects pending inference, M05 ramps voltage/frequency
  ACTIVE/DVFS_LOW → IDLE: M08 detects no active threads for >1ms
  IDLE → SLEEP: No ISA command for >100ms (programmable)
  SLEEP → ACTIVE: ISA I/F wakeup event or POR
```

## 4. Error Handling Flow

```
┌─────────────────────────────────────────────────────┐
│                  ERROR HANDLING                       │
│                                                       │
│  ECC Error (M02/M03):                                 │
│    Single-bit: Correct silently, log in status reg    │
│    Double-bit: Assert error_irq → M04 bus error       │
│      → M01 halts current op                           │
│      → M08 aborts thread                              │
│      → M16 reports error to host                      │
│                                                       │
│  DMA Timeout (M03):                                   │
│    DRAM read > timeout threshold → bus error          │
│    → M01 retries (max 3) or aborts                    │
│                                                       │
│  Secure Boot Failure (M14):                           │
│    → lockdown mode (JTAG lock, ISA lock)              │
│    → Only POR can exit lockdown                       │
│                                                       │
│  Watchdog Timeout:                                    │
│    → M07 asserts WDT reset                            │
│    → Reset main domain (same as rst_sys_n)            │
│    → WDT status logged in M07 reset_status reg        │
│                                                       │
│  Operator Exception (M09/M10/M11/M12):                │
│    NaN/Inf detection → error signal to M01            │
│    → M01 halts pipeline                               │
│    → Error code logged in M01 status register         │
└─────────────────────────────────────────────────────┘
```

## 5. Thread Scheduling Policy (M08)

```
Priority-based round-robin with aging:

Thread States:
  BLOCKED → READY → RUNNING → BLOCKED (waiting for resource)
                    │
                    └─► DONE (thread complete)

Scheduling Algorithm:
  1. Each thread has: priority (0-3), age counter, resource mask
  2. Round-robin among READY threads at same priority
  3. Age increment each scheduling tick → higher priority after aging threshold
  4. Resource arbitration:
     - M00 Systolic Array: single owner (locked per op)
     - M02 SRAM banks: shared, bank-level locking
     - M03 DRAM: shared, priority-based arbitration
     - Operator units: single owner (locked per op)

Thread Dispatch Latency:
  - Thread context switch: 16 cycles (save/restore 16 registers)
  - Dispatch decision: 4 cycles
  - Total: 20 cycles = 40 ns @ 500 MHz
```

## 6. ISA Command Processing Flow

```
ISA I/F (M16) → ISADecoder (M13) → ThreadScheduler (M08) → DataflowController (M01)

Command Format (32-bit ISA instruction):
  [31:26] opcode | [25:21] rd | [20:16] rs1 | [15:11] rs2 | [10:0] funct

Key Opcodes:
  ISA_LOAD    (0x01): Load data from ISA I/F to DRAM
  ISA_STORE   (0x02): Store data from DRAM to ISA I/F
  ISA_PREFILL (0x10): Start prefill inference
  ISA_DECODE  (0x11): Generate one token (decode step)
  ISA_CONFIG  (0x20): Configure model parameters (layers, dims)
  ISA_STATUS  (0x21): Read NPU status

Processing:
  1. M16 validates ISA CRC and security token (if lockdown)
  2. M13 decodes opcode → M08 thread command
  3. M08 creates thread with specified priority, resources
  4. M01 dispatches operations to compute/memory modules
  5. Completion: M16 sends response packet with status
```