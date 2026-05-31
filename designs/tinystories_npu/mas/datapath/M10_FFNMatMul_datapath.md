---
module: M10
type: datapath
status: complete
parent: NPU_top
module_type: compute
generated: 2026-05-31T18:00:00+08:00
---

# M10_FFNMatMul Datapath

## Block Diagram

```mermaid
graph TB
    subgraph "M10_FFNMatMul"
        ACT_IN[Activation Input<br/>1x576 or Nx576] --> ACT_BUF[Activation Buffer]
        ACT_BUF --> GATE_PATH[Gate Path]
        ACT_BUF --> UP_PATH[Up Path]

        GATE_PATH --> M00_GATE[M00 Gate Projection<br/>576→2304]
        UP_PATH --> M00_UP[M00 Up Projection<br/>576→2304]

        M00_GATE --> SILU[SiLU Activation<br/>element-wise]
        M00_UP --> UP_BUF[Up Buffer 9KB]

        SILU --> MUL[Element-wise Multiply<br/>gate ⊙ up]
        UP_BUF --> MUL

        MUL --> M00_DOWN[M00 Down Projection<br/>2304→576]
        M00_DOWN --> RESIDUAL[Residual Add]
        RESIDUAL --> OUT_BUF[Output Buffer]
    end

    SRAM_W[M02 SRAM Bank 0/1<br/>Weight Buffer] --> |weight_data_i| M00_GATE
    SRAM_W --> |weight_data_i| M00_UP
    SRAM_W --> |weight_data_i| M00_DOWN
    M01[M01 DataflowCtrl] --> |op_valid_i| ACT_BUF
```

## FFN Data Flow

```
FFN(x) = Down(SiLU(Gate(x)) ⊙ Up(x)) + x

Step 1: Gate Projection (via M00)
  Input: x (1 x 576 or N x 576)
  Weight: W_gate (576 x 2304)
  Output: gate = x * W_gate (1 x 2304)
  Latency: ~1296 cycles (576*2304/1024)

Step 2: Up Projection (via M00, parallel with Gate)
  Input: x (1 x 576)
  Weight: W_up (576 x 2304)
  Output: up = x * W_up (1 x 2304)
  Latency: ~1296 cycles (parallel with gate)

Step 3: SiLU Activation (element-wise)
  SiLU(y) = y * sigmoid(y)
  For each of 2304 elements:
    sigmoid(y) ≈ LUT-based approximation (16-segment piecewise)
  Latency: 2304/8 = 288 cycles

Step 4: Element-wise Multiply
  gated = SiLU(gate) ⊙ up  (1 x 2304)
  Latency: 288 cycles

Step 5: Down Projection (via M00)
  Input: gated (1 x 2304)
  Weight: W_down (2304 x 576)
  Output: down = gated * W_down (1 x 576)
  Latency: ~1296 cycles

Step 6: Residual Add
  output = down + x (residual connection)
  Latency: 72 cycles (576/8 elements)

Total FFN latency (decode): 1296 + 288 + 288 + 1296 + 72 = 3240 cycles
  @ 500 MHz: 6.48 us
```

## SiLU Implementation

```
SiLU(x) = x * sigmoid(x) = x / (1 + exp(-x))

Hardware implementation: LUT-based piecewise approximation

  Range      | sigmoid(x) approx
  -----------|------------------
  x < -6.0   | 0.0
  -6.0..-2.0 | 16-segment LUT
  -2.0..2.0  | 0.5 + x/4 (linear approximation)
  2.0..6.0   | 16-segment LUT
  x > 6.0    | 1.0

  Pipeline: 2 stages
    Stage 0: Range detection + LUT address
    Stage 1: LUT read + multiply (x * sigmoid)
```