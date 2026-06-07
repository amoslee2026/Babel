---
module: M00
type: MAS
status: complete
chiplet_features: [D2D]
---

# M00: Systolic Array

## 1. Overview

M00 是 TinyStories NPU 的核心计算单元，采用 128x128 PE (Processing Element) 阵阵结构，支持 WS (Weight Stationary) 和 OS (Output Stationary) 双模式数据流，实现高效的矩阵乘法运算。

**核心指标**：

| Precision | TOPS | REQ Reference |
|-----------|------|---------------|
| FP8 (E4M3/E5M2) | >= 2 | REQ-COMPUTE-001 |
| FP16 | >= 1 | REQ-COMPUTE-002 |
| INT8 | >= 2 | REQ-COMPUTE-003 |
| FP32 | 0.5 (参考) | REQ-COMPUTE-007 |

**时钟域**：CLK_SYS (250-500 MHz)
**电源域**：PD_MAIN (DVFS 支持)

## 2. Interface

### 2.1 PE Array Control Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `pe_mode` | 1 | Input | WS=0 / OS=1 模式选择 |
| `pe_precision` | 2 | Input | FP8=00 / FP16=01 / INT8=10 / FP32=11 |
| `pe_start` | 1 | Input | 启动计算脉冲 |
| `pe_done` | 1 | Output | 计算完成标志 |
| `pe_row_cnt` | 8 | Input | 活动行数 (0-127) |
| `pe_col_cnt` | 8 | Input | 活动列数 (0-127) |

### 2.2 Data Flow Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `weight_in` | 128*data_w | Input | 权重输入流 (按行) |
| `input_in` | 128*data_w | Input | 输入数据流 (按列) |
| `output_out` | 128*data_w | Output | 输出数据流 |
| `partial_out` | 128*acc_w | Output | OS模式部分累加输出 |
| `weight_addr` | 16 | Input | 权重 SRAM 基地址 |
| `input_addr` | 16 | Input | 输入 SRAM 基地址 |
| `output_addr` | 16 | Input | 输出 SRAM 基地址 |

**Data Width (data_w)**：

| Precision | data_w | acc_w (累加器) |
|-----------|--------|----------------|
| FP8 | 8 bit | 32 bit |
| FP16 | 16 bit | 32 bit |
| INT8 | 8 bit | 32 bit |
| FP32 | 32 bit | 32 bit |

### 2.3 Precision Control Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `fp8_format` | 1 | Input | E4M3=0 / E5M2=1 格式选择 |
| `round_mode` | 2 | Input | 舍入模式 (RN/RZ/RU/RD) |
| `saturation` | 1 | Input | 溢出饱和控制 |
| `mix_precision_en` | 1 | Input | 混合精度模式使能 REQ-COMPUTE-007 |

## 3. Functional Description

### 3.1 WS Mode (Weight Stationary)

**数据流原理**：权重预加载到 PE 阵列后保持固定，输入数据沿列方向流动，部分结果沿行方向流动并累加。

**时序流程**：

```
Phase 1: Weight Preload (N cycles)
  - 从 SRAM 加载权重矩阵 W[MxK] 到 PE 阵列
  - PE[i][j] 存储 W[i][j]

Phase 2: Input Streaming (M+N-1 cycles)
  - 输入矩阵 X[KxN] 沿列方向流入
  - 每个 PE 接收 input 流，执行 MAC 操作
  - 部分累加沿行方向传递

Phase 3: Output Collection (M cycles)
  - 最终结果 Y[MxN] 从右侧流出
  - 写入 SRAM output_addr
```

**适用场景**：
- 大批量矩阵乘法 (batch >= 16)
- Transformer FFN 层 (weights 固定，activation 流动)
- 权重复用率高的场景

**利用率公式**：
```
Utilization_WS = M*N / (M+N-1) * Pipeline_Depth
Peak: M=N 时，利用率 ≈ 50% 单周期，Pipeline 提升至 >= 80%
```

### 3.2 OS Mode (Output Stationary)

**数据流原理**：输出元素固定在 PE 中累加完成，权重和输入数据分别沿行、列方向流动。

**时序流程**：

```
Phase 1: Output Initialize (1 cycle)
  - 目标输出位置 Y[i][j] 映射到 PE[i][j]
  - 累加器清零

Phase 2: Weight/Input Streaming (K cycles)
  - 权重 W[i][*] 沿行方向流动
  - 输入 X[*][j] 沿列方向流动
  - PE[i][j] 接收 W[i][k] 和 X[k][j]，累加
  - Y[i][j] = Σ W[i][k] * X[k][j]

Phase 3: Output Writeback (M*N cycles)
  - 完成的累加值写入 SRAM
  - 支持部分累加输出 (大矩阵分块计算)
```

**适用场景**：
- 小批量推理 (batch < 16)
- 减少 SRAM 访问次数
- 输出固定，权重/输入可重用

**利用率公式**：
```
Utilization_OS = K / K = 100% (理想)
实际: Pipeline 填充开销，整体 >= 80% REQ-COMPUTE-005
```

### 3.3 Precision Handling (FP8/FP16/INT8/FP32)

#### 3.3.1 FP8 Format Support

| Format | Layout | Range | Use Case |
|--------|--------|-------|----------|
| E4M3 | S.EEE.MMMM (1-4-3) | ±448, max 448 | 权重存储，KV cache |
| E5M2 | S.EEEEE.MM (1-5-2) | ±57344, max 57344 | Activation，梯度 |

**FP8 MAC Pipeline**：

```
FP8_Input (8b) ──┬──> FP8_to_FP16 ──> FP16_MAC ──> FP32_Acc ──> FP8_Quantize ──> FP8_Output
FP8_Weight (8b) ─┘
```

**量化舍入模式**：

| Mode | Code | Description |
|------|------|-------------|
| RN | 00 | Round to Nearest (ties to even) |
| RZ | 01 | Round toward Zero |
| RU | 10 | Round toward +∞ (up) |
| RD | 11 | Round toward -∞ (down) |

#### 3.3.2 Mixed Precision Mode

**REQ-COMPUTE-007** 支持混合精度计算：

| Scenario | Input | Weight | Accumulate | Output |
|----------|-------|--------|------------|--------|
| FP16 inference | FP16 | FP16 | FP32 | FP16 |
| INT8 quantized | INT8 | INT8 | FP32 | FP16/INT8 |
| FP8 KV cache | FP8 | FP8 | FP32 | FP8 |
| FP32 baseline | FP32 | FP32 | FP32 | FP32 |

**精度损失控制**：REQ-COMPUTE-007 要求 INT8/FP8 相对 FP32 精度损失 <= 0.5%

#### 3.3.3 Overflow Handling

| Condition | Action |
|-----------|--------|
| `saturation=1` | 饱和到最大/最小可表示值 |
| `saturation=0` | Wrap-around (modulo overflow) |

## 4. Data Path (PE Array Structure)

### 4.1 PE Architecture

每个 Processing Element (PE) 包含：

```
┌─────────────────────────────────────┐
│ PE[i][j]                            │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│ │ Weight  │ │ Input   │ │ MAC     │ │
│ │ Reg     │ │ Reg     │ │ Unit    │ │
│ │ [data_w]│ │ [data_w]│ │ [acc_w] │ │
│ └─────────┘ └─────────┘ └─────────┘ │
│ ┌─────────┐ ┌─────────┐            │
│ │Accum    │ │ Output  │            │
│ │Reg[32b] │ │ Reg     │            │
│ └─────────┘ └─────────┘            │
└─────────────────────────────────────┘
```

### 4.2 128x128 Array Topology

```
          Input Flow (Column-wise)
                ↓ ↓ ↓ ↓
     ┌─────────────────────────────┐
     │ PE[0][0] PE[0][1] ... PE[0][127]│ → Output Row 0
     │ PE[1][0] PE[1][1] ... PE[1][127]│ → Output Row 1
     │   ...    ...    ...    ...    │
W    │ PE[127][0] ... ... PE[127][127]│ → Output Row 127
e    └─────────────────────────────┘
i       ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↑
g       Weight Preload (Row-wise) or Flow (OS Mode)
h
t
```

### 4.3 Pipeline Stages

| Stage | Latency | Function |
|-------|---------|----------|
| S0: Input Register | 1 cycle | 数据输入寄存 |
| S1: Weight Register | 1 cycle | 权重寄存 (WS: preload, OS: flow) |
| S2: MAC | 1 cycle | 乘法 + 加法 |
| S3: Accumulator | 1 cycle | 累加器更新 |
| S4: Output Register | 1 cycle | 输出寄存 |

**Total PE Pipeline Latency**: 5 cycles
**Array Pipeline Fill**: 128 + 127 = 255 cycles (full array)

### 4.4 Activity Control

支持动态调整活动 PE 数量以优化功耗：

```
pe_row_cnt = M (0-127): 活动行数
pe_col_cnt = N (0-127): 活动列数
Inactive PE: clock gating, power gating eligible
```

### 4.5 Matrix Size Boundary Handling (B01 Fix)

**REQ-M00-010: Matrix Size Constraint**

| Dimension | Maximum | Boundary Behavior |
|-----------|---------|-------------------|
| M (output rows) | 128 | M > 128 → ERROR_FLAG + Split computation |
| N (output cols) | 128 | N > 128 → ERROR_FLAG + Split computation |
| K (accumulation) | 256 | K > 256 → ERROR_FLAG + Block computation |

**Boundary Error Response**：
- `pe_size_error_o`: 1-bit output, high when M/N/K exceed limits
- `pe_size_error_code_o[2:0]`: Error code (001=M overflow, 010=N overflow, 100=K overflow)
- Recommended handling: Split matrix into 128x128 tiles, compute sequentially

## 5. Timing

### 5.1 TOPS Performance

**计算公式**：
```
TOPS = Array_Size * Frequency * Operations_per_PE
     = 128 * 128 * F_MHz * 2 (MAC = 1 mul + 1 add)
```

| Frequency | Precision | TOPS |
|-----------|-----------|------|
| 500 MHz | FP8 | 128*128*500M*2 = 16.384 TOPS (理论峰值) |
| 500 MHz | FP16 | 8.192 TOPS (理论峰值) |
| 500 MHz | INT8 | 16.384 TOPS (理论峰值) |

**实际 TOPS (考虑利用率)**：

| Precision | Peak TOPS | Utilization | Effective TOPS | REQ |
|-----------|-----------|-------------|----------------|-----|
| FP8 | 16.384 | 80% | 13.1 >= 2 | REQ-COMPUTE-001 PASS |
| FP16 | 8.192 | 80% | 6.55 >= 1 | REQ-COMPUTE-002 PASS |
| INT8 | 16.384 | 80% | 13.1 >= 2 | REQ-COMPUTE-003 PASS |

### 5.2 Pipeline Latency

| Operation | WS Mode | OS Mode |
|-----------|---------|---------|
| Weight Preload | M cycles | - (streaming) |
| Compute Init | N cycles | K cycles |
| Pipeline Fill | M+N-1 cycles | K cycles |
| Output Drain | M cycles | M*N cycles |
| **Total** | M+N-1+M cycles | K+M*N cycles |

**示例 (128x128 矩阵乘法)**：
- WS Mode: 128+127+128 = 383 cycles
- OS Mode: 128+128*128 = 16512 cycles (无 Pipeline 优势)

### 5.3 Timing Constraints

| Constraint | Value | Notes |
|------------|-------|-------|
| Setup Time | <= 2 ns | @ 500 MHz |
| Hold Time | >= 0.5 ns | |
| Clock-to-Q | <= 1 ns | PE register |

### 5.4 DVFS Operating Points

| Point | Frequency | Voltage | TOPS (FP8) | Power |
|-------|-----------|---------|------------|--------|
| High | 500 MHz | 0.9 V | >= 2 TOPS | Max |
| Medium | 350 MHz | 0.8 V | >= 1.4 TOPS | 70% |
| Low | 250 MHz | 0.7 V | >= 1 TOPS | 50% |

REQ-PWR-003 要求支持 >= 2 DVFS 工作点。

## 6. Implementation Notes

### 6.1 Design Considerations

1. **Dual-Mode Trade-off**：
   - WS 模式适合大批量，OS 模式适合小批量
   - M01 Dataflow Controller 根据批次大小自动选择模式

2. **Precision Hardware Cost**：
   - FP8/INT8 MAC: 8b * 8b + 32b acc = 最小面积
   - FP16 MAC: 16b * 16b + 32b acc = 中等面积
   - FP32 MAC: 32b * 32b + 32b acc = 最大面积
   - 建议共享 FP16/FP32 MAC 单元，FP8/INT8 使用专用紧凑单元

3. **SRAM Bandwidth Matching**：
   - Weight preload: 128 * data_w per cycle = SRAM bandwidth requirement
   - Input streaming: 128 * data_w per cycle
   - 建议 SRAM 带宽 >= 256 * 16b = 4096 bit/cycle @ 500 MHz

4. **Power Optimization**：
   - Inactive PE array region: clock gating + power gating
   - FP8/INT8 mode: reduced precision power savings
   - DVFS: 降低频率和电压以减少功耗

### 6.2 Verification Strategy

| Test Category | Description |
|---------------|-------------|
| Functional | WS/OS mode correctness, all precision combinations |
| Timing | Pipeline latency, TOPS throughput, DVFS transition |
| Corner Cases | Small matrices (M/N/K < 128), partial array operation |
| Precision | FP8 quantization error <= 0.5% vs FP32 baseline REQ-COMPUTE-007 |
| Power | Clock/power gating effectiveness, DVFS power reduction |

### 6.3 Integration Notes

- **M01 Dataflow Controller**: 提供数据流控制，模式选择
- **M02 SRAM**: 512 KB scratchpad，支持权重/输入/输出缓存
- **M09-M12 Operator Units**: Attention/FFN/RMSNorm/RoPE/SoftMax 调用 PE 阵阵
- **M08 Multi-thread Scheduler**: 多线程调度，共享 PE 阵列

### 6.4 Physical Design Guidelines

| Parameter | Target | Notes |
|-----------|--------|-------|
| PE Size | <= 50 um² | 128x128 array area target |
| Array Aspect Ratio | 1:1 or 2:1 | Square or rectangular layout |
| Routing | Data flow direction优先 | WS: row-wise, OS: column-wise |
| Clock Distribution | Mesh or H-tree | Low skew across array |

### 6.5 References

- REQ-COMPUTE-001~007: Compute performance requirements
- REQ-PWR-003: DVFS support
- REQ-COMPUTE-005: Pipeline utilization >= 80%
- Block Diagram: `/spec/ARCH/block_diagram.md`
- Chip Overview: `/spec/ARCH/chip_overview.md`