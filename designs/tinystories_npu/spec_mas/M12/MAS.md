---
module: M12
type: MAS
status: complete
parent: null
module_type: compute
generated: "2026-05-17T14:55:00+08:00"
---

# M12: SoftMax Unit

## 1. Overview

M12 SoftMax Unit 是 TinyStories NPU 的 Transformer 算子模块之一，位于 PD_MAIN Power Domain，专门处理 SoftMax 概率计算。该模块实现数值稳定的 SoftMax 运算，包含 Max Finder（最大值查找器）、Exponential Approximator（指数近似器）、Sum Accumulator（求和累加器）和 Normalizer（归一化器）四大功能单元，确保在 FP16/FP8 精度下准确输出概率分布，满足 REQ-SW-003 规定的算子支持要求。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| Max Finder | 输入向量最大值查找，用于数值稳定性 | REQ-SW-003 |
| Exponential Approximator | 查表法 + 泰勒展开混合近似，精度误差 < 0.1% | REQ-SW-003 |
| Sum Accumulator | 并行累加，支持 FP16/FP8 精度 | REQ-SW-003 |
| Normalizer | 除法归一化，输出概率分布 | REQ-SW-003 |
| Numerical Stability | Max subtraction 防止溢出，安全计算范围 | - |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，与计算子系统同步 |
| Power Domain | PD_MAIN | 0.6-0.9 V，随 DVFS 动态调整 |
| Target Latency | < 100 cycles | 单次 SoftMax 计算延迟 |

### 1.3 SoftMax Mathematical Definition

```
SoftMax(x_i) = exp(x_i - max(x)) / sum(exp(x_j - max(x)))

where:
  - x: input vector (attention scores)
  - max(x): maximum value in input vector
  - exp(): exponential function (approximated)
  - sum(): sum over all elements

Numerical Stability:
  - Subtract max(x) before exp() to prevent overflow
  - Result range: (0, 1), guaranteed probability distribution
```

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk_sys | Input | 1 | System Clock，250-500 MHz |
| rst_sys_n | Input | 1 | System 异步复位，低有效 |
| clk_gate_en | Input | 1 | Clock Gate 使能（来自 Power Manager） |

#### 2.1.2 Score Input Interface (from M02 SRAM / M09 Attention)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| score_valid | Input | 1 | Score 数据有效 |
| score_ready | Output | 1 | Score 接收就绪 |
| score_data | Input | 512 | Score 向量数据（FP16, 256 elements） |
| score_len | Input | 8 | Score 向量长度（1-256） |
| score_seq_id | Input | 16 | Sequence ID 标识 |
| score_precision | Input | 2 | 精度模式（0=FP16, 1=FP8_E4M3, 2=FP8_E5M2） |

#### 2.1.3 Probability Output Interface (to M02 SRAM)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| prob_valid | Output | 1 | Probability 输出有效 |
| prob_ready | Input | 1 | Probability 接收就绪 |
| prob_data | Output | 512 | Probability 向量数据（FP16, 256 elements） |
| prob_len | Output | 8 | Probability 向量长度 |
| prob_seq_id | Output | 16 | Sequence ID 标识 |
| prob_checksum | Output | 32 | 输出校验和（sum verification） |

#### 2.1.4 Control Interface (from M01 Dataflow Controller)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| softmax_start | Input | 1 | SoftMax 计算启动 |
| softmax_abort | Input | 1 | SoftMax 计算中止 |
| softmax_config | Input | 16 | 配置参数（精度、近似方法等） |
| softmax_busy | Output | 1 | SoftMax 计算进行中 |

#### 2.1.5 Status Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| softmax_done | Output | 1 | SoftMax 计算完成 |
| softmax_error | Output | 1 | 错误标志（溢出、精度异常） |
| softmax_latency | Output | 16 | 实际计算周期数 |
| softmax_cycles | Output | 32 | 累计计算周期数（统计） |

#### 2.1.6 Pipeline Stage Interface (Internal)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| stage1_max | Internal | 16 | Stage 1 输出：最大值 |
| stage2_exp_valid | Internal | 512 | Stage 2 输出：exp 结果向量 |
| stage3_sum | Internal | 32 | Stage 3 输出：累加和 |
| stage4_prob | Internal | 512 | Stage 4 输出：归一化概率 |

### 2.2 Register Map

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | SM_CTRL | RW | 32 | SoftMax 控制寄存器 |
| 0x0004 | SM_STATUS | R | 32 | SoftMax 状态寄存器 |
| 0x0008 | SM_CONFIG | RW | 32 | SoftMax 配置寄存器 |
| 0x000C | SM_PRECISION | RW | 32 | 精度设置寄存器 |
| 0x0010 | SM_APPROX_CTRL | RW | 32 | 指数近似控制寄存器 |
| 0x0014 | SM_APPROX_TABLE_BASE | RW | 32 | 查表法基地址寄存器 |
| 0x0018 | SM_PIPELINE_CTRL | RW | 32 | Pipeline 控制寄存器 |
| 0x001C | SM_LATENCY | R | 32 | 计算延迟统计寄存器 |
| 0x0020 | SM_ERROR_STATUS | R | 32 | 错误状态寄存器 |
| 0x0024 | SM_STATS_COUNTERS | R | 32 | 统计计数器寄存器 |
| 0x0028 | SM_DEBUG_DATA | RW | 32 | 调试数据寄存器 |

#### 2.2.1 Register Bit Definitions

**SM_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enable | SoftMax Unit 使能 |
| [1] | start | 计算启动（自清零） |
| [2] | abort | 计算中止 |
| [3] | reset_pipeline | Pipeline 复位 |
| [4] | debug_en | 调试模式使能 |
| [5] | irq_en | 中断使能 |
| [6:7] | reserved | 保留 |
| [8:15] | vector_len | 向量长度配置（备用） |
| [16:31] | reserved | 保留 |

**SM_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | SoftMax Unit 就绪 |
| [1] | busy | 计算进行中 |
| [2] | done | 计算完成 |
| [3] | error | 错误标志 |
| [4] | pipeline_stage1 | Stage 1 (Max Finder) 激活 |
| [5] | pipeline_stage2 | Stage 2 (Exp Approx) 激活 |
| [6] | pipeline_stage3 | Stage 3 (Sum Acc) 激活 |
| [7] | pipeline_stage4 | Stage 4 (Normalizer) 源活 |
| [8:15] | current_len | 当前向量长度 |
| [16:23] | precision_mode | 当前精度模式 |
| [24:31] | reserved | 保留 |

**SM_CONFIG (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:1] | precision | 精度模式（0=FP16, 1=FP8_E4M3, 2=FP8_E5M2） |
| [2:3] | approx_method | 指数近似方法（0=LUT, 1=Taylor, 2=Hybrid） |
| [4] | parallel_sum | 并行累加使能 |
| [5] | checksum_en | 输出校验和使能 |
| [6] | overflow_check | 溢出检测使能 |
| [7] | saturate_output | 输出饱和处理 |
| [8:15] | lut_entries | 查表项数（16-256） |
| [16:31] | reserved | 保留 |

**SM_APPROX_CTRL (0x0010)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:7] | lut_precision_bits | 查表精度位数 |
| [8:11] | taylor_order | 泰勒展开阶数（1-4） |
| [12:15] | input_range_bits | 输入范围限制位数 |
| [16:23] | exp_output_scale | 输出缩放因子 |
| [24:31] | reserved | 保留 |

**SM_ERROR_STATUS (0x0020)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | overflow_input | 输入溢出错误 |
| [1] | overflow_exp | 指数溢出错误 |
| [2] | underflow_exp | 指数下溢错误 |
| [3] | sum_zero | 累加和为零错误 |
| [4] | precision_loss | 精度丢失警告 |
| [5] | timeout | 计算超时错误 |
| [6:7] | reserved | 保留 |
| [8:15] | error_vector_idx | 错误发生位置索引 |
| [16:31] | reserved | 保留 |

## 3. Functional Description

### 3.1 SoftMax Pipeline Architecture

SoftMax Unit 采用 4-Stage Pipeline 架构，实现高效并行计算。

```
Score Input (512-bit FP16 vector)
    |
    v
+--------+    +--------+    +--------+    +--------+
| Stage  | -->| Stage  | -->| Stage  | -->| Stage  |
|   1    |    |   2    |    |   3    |    |   4    |
| Max    |    | Exp    |    | Sum    |    | Norm   |
| Finder |    | Approx |    | Acc    |    |        |
+--------+    +--------+    +--------+    +--------+
    |             |             |             |
    v             v             v             v
 max_val      exp_vec[256]    sum_val     prob_vec[256]
                                              |
                                              v
                                     Probability Output
```

### 3.2 Stage 1: Max Finder

Max Finder 在输入向量中查找最大值，用于数值稳定性处理。

#### 3.2.1 Max Finder Algorithm

```
Max Finding (Parallel Tree Reduction):

Level 0: 256 inputs --> 128 comparisons
Level 1: 128 intermediates --> 64 comparisons
Level 2: 64 intermediates --> 32 comparisons
Level 3: 32 intermediates --> 16 comparisons
Level 4: 16 intermediates --> 8 comparisons
Level 5: 8 intermediates --> 4 comparisons
Level 6: 4 intermediates --> 2 comparisons
Level 7: 2 intermediates --> 1 max value

Total: 8 levels, log2(256) comparisons
Latency: 8 cycles (parallel tree)
```

#### 3.2.2 Max Finder Implementation

| Parameter | Value | Description |
|-----------|-------|-------------|
| Input Width | 512 bits | 256 x FP16 (16-bit each) |
| Comparator Width | 16 bits | FP16 comparator |
| Tree Depth | 8 levels | Parallel reduction tree |
| Output Width | 16 bits | max(x) value |

### 3.3 Stage 2: Exponential Approximator

Exponential Approximator 计算 exp(x_i - max(x))，使用混合近似方法。

#### 3.3.1 Approximation Methods

| Method | Description | Accuracy | Latency | Area |
|--------|-------------|----------|---------|------|
| LUT (Look-Up Table) | 直接查表 + 线性插值 | < 0.05% error | 1 cycle | Medium |
| Taylor Expansion | 2-4阶泰勒展开 | < 0.1% error | 4 cycles | Small |
| Hybrid | LUT + Taylor 补偿 | < 0.02% error | 2 cycles | Medium |

#### 3.3.2 LUT Implementation

```
LUT Structure:
  - Address Range: input - max(x) --> normalized to [-8, 0]
  - LUT Entries: configurable (16-256 entries, default 128)
  - Entry Width: 16 bits (FP16 exp result)
  - Interpolation: Linear interpolation between entries

LUT Address Calculation:
  addr = (input_value - max_value) * lut_scale_factor
  addr = clamp(addr, 0, lut_entries - 1)

LUT Read + Interpolation:
  exp_result = lut_table[addr] + 
               (lut_table[addr+1] - lut_table[addr]) * interpolation_factor
```

#### 3.3.3 Taylor Expansion

```
Taylor Expansion (around x=0):

exp(x) = 1 + x + x^2/2! + x^3/3! + ...

Hardware Implementation:
  - Order 2: exp(x) ≈ 1 + x + x^2/2  (simple, fast)
  - Order 3: exp(x) ≈ 1 + x + x^2/2 + x^3/6  (balanced)
  - Order 4: exp(x) ≈ 1 + x + x^2/2 + x^3/6 + x^4/24  (accurate)

Optimization:
  - Pre-computed factorial constants (1/2, 1/6, 1/24)
  - Shift-based division for power-of-2 terms
  - Saturate at safe range to prevent overflow
```

#### 3.3.4 Hybrid Approximation

```
Hybrid Method:
  1. LUT coarse approximation (1 cycle)
  2. Taylor correction for residual (1 cycle)

Advantages:
  - LUT provides base accuracy
  - Taylor compensates LUT discretization error
  - Total latency: 2 cycles
  - Accuracy: < 0.02% error
```

#### 3.3.5 Numerical Stability

```
Safe Input Range:
  - input - max(x): [-8, 0] (normalized)
  - exp(x) range: [exp(-8), 1] = [0.000335, 1]
  - No overflow guaranteed

Edge Cases:
  - exp(-8) ≈ 0.000335 --> treated as 0 in FP8
  - exp(0) = 1 --> max value always yields 1
  - Sum always >= 1 (at least one element = 1)
```

### 3.4 Stage 3: Sum Accumulator

Sum Accumulator 计算所有 exp 结果的总和，用于归一化。

#### 3.4.1 Parallel Sum Algorithm

```
Parallel Sum (Tree Reduction):

Level 0: 256 exp values --> 128 additions
Level 1: 128 intermediates --> 64 additions
Level 2: 64 intermediates --> 32 additions
Level 3: 32 intermediates --> 16 additions
Level 4: 16 intermediates --> 8 additions
Level 5: 8 intermediates --> 4 additions
Level 6: 4 intermediates --> 2 additions
Level 7: 2 intermediates --> 1 sum value

Total: 8 levels, log2(256) additions
Latency: 8 cycles (parallel tree)
Output: sum(exp_vec) for normalization
```

#### 3.4.2 Sum Accumulator Implementation

| Parameter | Value | Description |
|-----------|-------|-------------|
| Input Width | 512 bits | 256 x FP16 exp values |
| Adder Width | 32 bits | FP32 accumulator (precision retention) |
| Tree Depth | 8 levels | Parallel reduction tree |
| Output Width | 32 bits | sum(exp) in FP32 |

#### 3.4.3 Precision Handling

```
FP16 Sum Accumulation:
  - Internal accumulator: FP32 (32-bit)
  - Prevents precision loss during accumulation
  - Final output: FP32 sum for division

FP8 Sum Accumulation:
  - Internal accumulator: FP16 (16-bit)
  - Limited precision, acceptable for FP8 output
  - Final output: FP16 sum for division
```

### 3.5 Stage 4: Normalizer

Normalizer 实现除法归一化，输出概率分布。

#### 3.5.1 Division Algorithm

```
Division Method: Newton-Raphson Iteration

Initial approximation: 1/sum ≈ approx_inv(sum)
Iteration: x_n+1 = x_n * (2 - sum * x_n)

Iterations:
  - 1 iteration: fast, ~5% error
  - 2 iterations: balanced, ~1% error
  - 3 iterations: accurate, ~0.1% error

Hardware Implementation:
  - Initial: LUT-based reciprocal approximation
  - Iteration: Multiplier-based refinement
  - Final: prob_i = exp_i * inv_sum
```

#### 3.5.2 Normalizer Implementation

| Parameter | Value | Description |
|-----------|-------|-------------|
| Input Width | 512 bits | 256 x FP16 exp values |
| Sum Input | 32 bits | sum(exp) in FP32 |
| Division Iterations | 2-3 | Newton-Raphson iterations |
| Output Width | 512 bits | 256 x FP16 prob values |

#### 3.5.3 Division-by-Zero Protection (B43 Fix)

**REQ-M12-010: SoftMax Sum=Zero Fallback**

| Condition | Handling |
|-----------|----------|
| sum_val == 0 | Uniform distribution |

**Error Signal**: `sm_sum_zero_o` (1-bit)

#### 3.5.4 Output Verification

```
Probability Distribution Check:
  - All outputs: (0, 1) range guaranteed
  - Sum of outputs: ~1.0 (within precision tolerance)
  
Checksum Verification:
  - Output sum computed (FP32)
  - checksum = sum(prob_vec)
  - Expected: checksum ≈ 1.0
  - Deviation tolerance: < 0.01 for FP16
```

### 3.6 Pipeline Control

#### 3.6.1 Pipeline Flow Control

```
Pipeline Stages Flow:

Stage 1 (Max Finder):
  - Input: score_data valid
  - Output: max_val
  - Stall condition: score_valid=0

Stage 2 (Exp Approx):
  - Input: score_data, max_val
  - Output: exp_vec
  - Stall condition: stage1 not ready

Stage 3 (Sum Acc):
  - Input: exp_vec
  - Output: sum_val
  - Stall condition: stage2 not ready

Stage 4 (Normalizer):
  - Input: exp_vec, sum_val
  - Output: prob_vec
  - Stall condition: stage3 not ready OR prob_ready=0
```

#### 3.6.2 Pipeline Timing

| Stage | Latency | Description |
|-------|---------|-------------|
| Stage 1 | 8 cycles | Max Finder (parallel tree) |
| Stage 2 | 2 cycles | Exp Approximator (Hybrid) |
| Stage 3 | 8 cycles | Sum Accumulator (parallel tree) |
| Stage 4 | 3 cycles | Normalizer (Newton-Raphson) |
| **Total** | **21 cycles** | Full pipeline latency |

### 3.7 Error Handling

#### 3.7.1 Error Detection

| Error Type | Detection Condition | Handling |
|------------|---------------------|----------|
| Input Overflow | score_data > FP16 max | Saturate + flag |
| Exp Overflow | exp > FP16 max | Saturate to max + flag |
| Exp Underflow | exp < FP16 min | Saturate to 0 + flag |
| Sum Zero | sum_val = 0 | Error flag + bypass |
| Precision Loss | sum deviation > threshold | Warning flag |

#### 3.7.2 Error Recovery

```
Error Recovery Sequence:
  1. Set softmax_error=1, update error_status
  2. Record error_vector_idx (error position)
  3. Stall pipeline if critical error
  4. Generate IRQ if irq_en=1
  5. Wait for abort or config update to resume
```

## 4. Timing

### 4.1 Pipeline Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_stage1 | 8 cycles | Max Finder latency |
| t_stage2 | 2 cycles | Exp Approximator latency |
| t_stage3 | 8 cycles | Sum Accumulator latency |
| t_stage4 | 3 cycles | Normalizer latency |
| t_total | 21 cycles | Full pipeline latency |
| t_pipeline_interval | 21 cycles | Pipeline throughput (one vector per interval) |

### 4.2 Interface Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_score_ready | 1 cycle | Score input ready response |
| t_prob_valid | 1 cycle | Probability output valid assertion |
| t_config_update | 2 cycles | Configuration update latency |
| t_error_response | 1 cycle | Error flag response |

### 4.3 Timing at Different Clock Frequencies

| CLK_SYS | Latency (cycles) | Latency (time) | Throughput |
|---------|------------------|----------------|------------|
| 500 MHz | 21 cycles | 42 ns | 23.8M vectors/s |
| 250 MHz | 21 cycles | 84 ns | 11.9M vectors/s |

### 4.4 Backpressure Handling

| Scenario | Response |
|----------|----------|
| Score input stall | Pipeline Stage 1 stalls, backpressure propagates |
| Prob output stall | Pipeline Stage 4 stalls, stages 1-3 continue (buffer) |
| Both stall | Full pipeline stall, no data loss |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **Numerical Stability First**: Max subtraction 是 SoftMax 计算的关键，必须在 exp 之前完成。

2. **精度平衡**: FP16 精度下使用 FP32 内部累加器，FP8 精度下使用 FP16 内部累加器。

3. **Pipeline Depth**: 21 cycles pipeline latency，吞吐量与延迟平衡。

4. **Approximation Trade-off**: Hybrid 方法在精度和速度之间取得最佳平衡。

5. **Parallel Processing**: Max Finder 和 Sum Accumulator 使用并行树结构，log2(N) 延迟。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol |
|-----------|---------------|----------|
| Score Input | M02 SRAM / M09 Attention | Valid/Ready handshake |
| Prob Output | M02 SRAM | Valid/Ready handshake |
| Control | M01 Dataflow Controller | Command interface |
| Debug | M15 JTAG | IEEE 1149.1 |

### 5.3 Verification Requirements

| Test Category | Description |
|---------------|-------------|
| Functional | 验证 SoftMax 数学正确性 |
| Numerical Stability | 验证 Max subtraction 防止溢出 |
| Approximation Accuracy | 验证指数近似精度 < 0.1% |
| Precision Modes | 验证 FP16/FP8 精度模式 |
| Pipeline | 验证 Pipeline 流控和 backpressure |
| Error Handling | 验证所有错误检测和恢复 |

### 5.4 Power Budget Allocation

| Domain | Budget | Allocation |
|--------|--------|------------|
| Max Finder | 15 mW | Parallel comparator tree |
| Exp Approximator | 25 mW | LUT + Taylor logic |
| Sum Accumulator | 15 mW | Parallel adder tree |
| Normalizer | 20 mW | Newton-Raphson divider |
| Control + Registers | 10 mW | FSM + Register file |
| **Total** | **85 mW** | @ 500 MHz, OP0 |

### 5.5 Clock Domain Crossing

| Crossing | From | To | Method |
|----------|------|----|----|
| Score Input | M02 SRAM (CLK_SYS) | M12 (CLK_SYS) | Same domain, no CDC |
| Prob Output | M12 (CLK_SYS) | M02 SRAM (CLK_SYS) | Same domain, no CDC |
| Control | M01 (CLK_SYS) | M12 (CLK_SYS) | Same domain, no CDC |

### 5.6 Reset Strategy

| Reset | Source | Effect |
|-------|--------|--------|
| rst_sys_n | System | 全部寄存器复位，Pipeline 清空 |
| Soft Reset | SM_CTRL[3] | Pipeline 复位，配置保留 |
| Pipeline Reset | Stage-specific | 单个 Stage 复位 |

### 5.7 Area Estimate

| Component | Area (um^2) | Percentage |
|-----------|-------------|------------|
| Max Finder Tree | 15,000 | 18% |
| LUT Table | 20,000 | 24% |
| Taylor Logic | 10,000 | 12% |
| Sum Accumulator Tree | 15,000 | 18% |
| Normalizer | 18,000 | 21% |
| Control + Registers | 8,000 | 9% |
| **Total** | **88,000 um^2** | 100% |
| **Normalized** | **~0.088 mm^2** | @ ASAP7 7nm |

### 5.8 LUT Table Configuration

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| lut_entries | 128 | 16-256 | 查表项数 |
| lut_precision_bits | 10 | 8-12 | 查表精度位数 |
| input_range_bits | 4 | 3-5 | 输入范围限制 |
| exp_output_scale | 16 | 8-32 | 输出缩放因子 |