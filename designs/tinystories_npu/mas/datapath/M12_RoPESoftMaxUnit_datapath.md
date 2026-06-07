---
module: M12
type: datapath
status: complete
parent: NPU_top
module_type: compute
generated: 2026-05-31T18:00:00+08:00
---

# M12_RoPESoftMaxUnit Datapath

## Block Diagram

```mermaid
graph TB
    subgraph "M12_RoPESoftMaxUnit"
        subgraph "RoPE Path"
            ROPE_IN[RoPE Input<br/>256-bit] --> LUT[Sin/Cos LUT<br/>2048 x 16-bit]
            ROPE_IN --> ROPE_MUL[Complex Multiply<br/>(x_2i, x_2i+1) * (cos, sin)]
            ROPE_MUL --> ROPE_OUT[RoPE Output]
        end

        subgraph "SoftMax Path"
            SM_IN[SoftMax Input<br/>256-bit] --> MAX[Running Max<br/>m_j = max(m, x_j)]
            MAX --> SUB[Subtract<br/>x_j - m_j]
            SUB --> EXP[FP32 Exp<br/>LUT + Interpolate]
            EXP --> ACCUM[Running Sum<br/>d_j = d * exp(m_prev - m_j) + exp(x_j - m_j)]
            ACCUM --> DIVIDE[Final Divide<br/>exp(x_j - m_N) / d_N]
            DIVIDE --> SM_OUT[SoftMax Output]
        end
    end

    M01[M01 DataflowCtrl] --> |op_code_i| ROPE_IN
    M01 --> |op_code_i| SM_IN
```

## RoPE Datapath

```
RoPE(x, pos) for dimension pair (2i, 2i+1):
  theta_i = 1 / (10000^(2i/d))
  cos_val = cos(pos * theta_i)
  sin_val = sin(pos * theta_i)
  x_2i'   = x_2i * cos_val - x_2i+1 * sin_val
  x_2i+1' = x_2i+1 * cos_val + x_2i * sin_val

Pipeline (3 stages):
  Stage 0: LUT Lookup
    - Compute theta_i = 1 / (10000^(2i/d))
    - LUT address = (pos * theta_i) % 2*pi, quantized to 2048 entries
    - Read cos, sin values (16-bit fixed-point)
    - Latency: 1 cycle per pair

  Stage 1: Parallel Multiply
    - x_2i * cos, x_2i+1 * sin (4 parallel FP16 multiplies)
    - x_2i+1 * cos, x_2i * sin
    - Latency: 1 cycle

  Stage 2: Add/Subtract + Output
    - x_2i' = x_2i * cos - x_2i+1 * sin
    - x_2i+1' = x_2i+1 * cos + x_2i * sin
    - Latency: 1 cycle

Total: 3 cycles per dimension pair, 8 pairs per cycle (256-bit)
  For d=576: 576/2/8 = 36 cycles
```

## SoftMax Datapath (Online Algorithm)

```
Online SoftMax:
  m_0 = -inf, d_0 = 0
  For each x_j:
    m_j = max(m_{j-1}, x_j)
    d_j = d_{j-1} * exp(m_{j-1} - m_j) + exp(x_j - m_j)
  Final: softmax(x_j) = exp(x_j - m_N) / d_N

Pipeline (5 stages):
  Stage 0: Running Max
    - m_new = max(m_prev, x_j)
    - 8 parallel FP32 compares
    - Latency: 1 cycle per 8 elements

  Stage 1: Subtract
    - m_prev - m_new, x_j - m_new
    - 8 parallel FP32 subtracts
    - Latency: 1 cycle

  Stage 2: FP32 Exp
    - exp(y) via LUT + linear interpolation
    - LUT: 256 entries, 16-bit fixed-point
    - Range reduction: y = k * ln(2) + r, exp(y) = 2^k * exp(r)
    - Latency: 2 cycles

  Stage 3: Running Sum
    - d_new = d_prev * exp(m_prev - m_new) + exp(x_j - m_new)
    - FP32 multiply-add
    - Latency: 1 cycle

  Stage 4: Final Divide (after all x_j processed)
    - softmax(x_j) = exp(x_j - m_N) / d_N
    - 8 parallel FP32 divides
    - Latency: 1 cycle per 8 elements

Total: (seq_len/8) * 5 + seq_len/8 cycles
  For seq_len=256: 256/8 * 5 + 256/8 = 160 + 32 = 192 cycles
  @ 500 MHz: 384 ns
```