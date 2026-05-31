---
module: M11
type: datapath
status: complete
parent: NPU_top
module_type: compute
generated: 2026-05-31T18:00:00+08:00
---

# M11_RMSNormUnit Datapath

## Block Diagram

```mermaid
graph TB
    subgraph "M11_RMSNormUnit"
        DATA_IN[Data Input<br/>256-bit] --> PASS1[Pass 1: x^2 Accumulate]
        PASS1 --> SUM_REG[Sum Register<br/>FP32]
        SUM_REG --> RMS_CALC[RMS Calculation<br/>sqrt(sum/dim + eps)]
        RMS_CALC --> RMS_REG[RMS Register<br/>FP32]

        DATA_IN --> DELAY[Delay Line<br/>for Pass 2]
        DELAY --> PASS2[Pass 2: x/rms * gamma]
        GAMMA[Gamma Weight<br/>from M02 SRAM] --> PASS2
        PASS2 --> OUT_BUF[Output Buffer<br/>256-bit]
    end

    M01[M01 DataflowCtrl] --> |op_valid_i<br/>op_params_i| PASS1
```

## Two-Pass Algorithm

```
RMSNorm(x) = x / sqrt(mean(x^2) + epsilon) * gamma

Pass 1 (Accumulate x^2):
  sum = 0
  For i in 0..dim-1:
    sum += x[i]^2
  rms = sqrt(sum / dim + epsilon)

Pass 2 (Normalize):
  For i in 0..dim-1:
    out[i] = (x[i] / rms) * gamma[i]

Pipeline (4 stages):
  Stage 0: x_i^2 multiply
    - 8 parallel FP32 multipliers (256-bit → 8 x FP32)
    - Latency: 1 cycle per 8 elements

  Stage 1: Accumulate
    - FP32 adder tree: 8→4→2→1 (3 cycles)
    - Accumulator register updated each group
    - Latency: dim/8 cycles

  Stage 2: RMS calculation
    - sum/dim: FP32 divide
    - + epsilon: FP32 add
    - sqrt: FP32 sqrt (LUT-based, 2 cycles)
    - Latency: 4 cycles

  Stage 3: Normalize + gamma multiply
    - x_i / rms: FP32 divide (8 parallel)
    - * gamma_i: FP32 multiply (8 parallel)
    - Latency: dim/8 cycles

Total: dim/8 + 3 + 4 + dim/8 = dim/4 + 7 cycles
  For dim=576: 576/4 + 7 = 151 cycles
  @ 500 MHz: 302 ns
```

## Delay Line

```
Pass 1 stores x_i values in a delay line for Pass 2 processing.
Depth: dim/8 = 72 entries (8 x FP32 per entry)
Implementation: Shift register FIFO, 72 deep x 256-bit wide
```