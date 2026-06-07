---
module: M11
type: MAS
status: complete
parent: null
module_type: compute
chiplet_features: [RMSNorm, RoPE]
generated: "2026-05-17T15:30:00+08:00"
---

# M11: RMSNorm/RoPE Unit

## 1. Overview

M11 RMSNorm/RoPE Unit 是 TinyStories NPU 的 Transformer 算子处理模块，位于 Main Power Domain (PD_MAIN)，运行于 CLK_SYS 时钟域 (250-500 MHz)。该模块实现两项关键算子：RMS Normalization（归一化）和 Rotary Position Embedding（旋转位置编码），为 Transformer 接近层的输入预处理和位置编码注入提供硬件加速。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| RMSNorm Computation | Root Mean Square Normalization，dim=64 | REQ-COMPUTE-008 |
| RoPE Computation | Rotary Position Embedding，head_size=8 | REQ-COMPUTE-008 |
| Precision Support | FP16/FP32 计算 | REQ-COMPUTE-002 |
| Latency | RMSNorm < 10 cycles, RoPE < 15 cycles | REQ-PERF-001 |
| Throughput | >= 100M ops/s @ 500 MHz | REQ-PERF-001 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 可调 |
| Power Domain | PD_MAIN | 0.7-0.9 V，支持 Power Gate |
| Target Power | 50 mW @ OP0 | 算子计算功耗预算 |

### 1.3 Use Cases

| Use Case | Operator | Description | Frequency |
|----------|----------|-------------|-----------|
| Layer Input Norm | RMSNorm | 每层输入归一化 | 5次/forward (n_layers=5) |
| Attention Preprocess | RMSNorm | Attention 输入归一化 | 5次/forward |
| Position Encoding | RoPE | Q/K 位置编码注入 | 10次/forward |
| KV Cache Update | RoPE | Decode phase K 向量旋转 | Variable |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| clk_sys_i | Input | 1 | CLK_SYS | 主系统时钟 (250-500 MHz) |
| rst_sys_n_i | Input | 1 | CLK_SYS | 系统复位，低有效 |
| pg_main_en_i | Input | 1 | CLK_SYS | Power Gate 使能 (from M05) |

#### 2.1.2 SRAM Direct Interface (to M02)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sram_req_valid_o | Output | 1 | CLK_SYS | SRAM 访问请求有效 |
| sram_req_addr_o | Output | 20 | CLK_SYS | SRAM 地址 (word address) |
| sram_req_rw_o | Output | 1 | CLK_SYS | 读/写标识 (0=Read, 1=Write) |
| sram_req_wdata_o | Output | 64 | CLK_SYS | 写数据 (FP16 x 4) |
| sram_req_wstrb_o | Output | 8 | CLK_SYS | 写字节使能 |
| sram_rsp_valid_i | Input | 1 | CLK_SYS | SRAM 响应有效 |
| sram_rsp_rdata_i | Input | 64 | CLK_SYS | 读响应数据 |
| sram_rsp_error_i | Input | 1 | CLK_SYS | SRAM 错误标志 |

#### 2.1.3 Operator Control Interface (from M08/M13)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| op_start_i | Input | 1 | CLK_SYS | 算子启动命令 |
| op_type_i | Input | 2 | CLK_SYS | 算子类型 (0=RMSNorm, 1=RoPE, 2=Combined) |
| op_mode_i | Input | 3 | CLK_SYS | 算子模式配置 |
| op_dim_i | Input | 8 | CLK_SYS | 向量维度 (default: 64) |
| op_head_size_i | Input | 8 | CLK_SYS | Head size (default: 8) |
| op_pos_i | Input | 32 | CLK_SYS | 当前位置索引 (for RoPE) |
| op_precision_i | Input | 2 | CLK_SYS | 精度配置 (0=FP16, 1=FP32) |
| op_done_o | Output | 1 | CLK_SYS | 算子完成标志 |
| op_busy_o | Output | 1 | CLK_SYS | 算子忙碌标志 |
| op_error_o | Output | 1 | CLK_SYS | 算子错误标志 |

#### 2.1.4 Data Input Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| data_in_valid_i | Input | 1 | CLK_SYS | 输入数据有效 |
| data_in_addr_i | Input | 32 | CLK_SYS | 输入数据 SRAM 地址 |
| data_in_size_i | Input | 16 | CLK_SYS | 输入数据大小 (words) |
| weight_addr_i | Input | 32 | CLK_SYS | 权重数据 SRAM 地址 (RMSNorm) |

#### 2.1.5 Data Output Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| data_out_valid_o | Output | 1 | CLK_SYS | 输出数据有效 |
| data_out_addr_o | Output | 32 | CLK_SYS | 输出数据 SRAM 地址 |
| data_out_size_o | Output | 16 | CLK_SYS | 输出数据大小 (words) |
| data_out_done_o | Output | 1 | CLK_SYS | 输出写入完成 |

#### 2.1.6 RoPE Table Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| rope_table_addr_i | Input | 32 | CLK_SYS | Cos/Sin 预计算表基地址 |
| rope_table_size_i | Input | 16 | CLK_SYS | 表大小 (words) |
| rope_table_en_i | Input | 1 | CLK_SYS | 预计算表使能 |

#### 2.1.7 Status & Interrupt

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| op_status_o | Output | 8 | CLK_SYS | 算子状态寄存器 |
| op_irq_o | Output | 1 | CLK_SYS | 算子中断请求 |
| op_irq_type_o | Output | 3 | CLK_SYS | 中断类型编码 |
| cycle_count_o | Output | 32 | CLK_SYS | 算子执行周期计数 |

### 2.2 Register Map

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | OP_CTRL | RW | 32 | 算子控制寄存器 |
| 0x0004 | OP_STATUS | R | 32 | 算子状态寄存器 |
| 0x0008 | OP_CONFIG | RW | 32 | 算子配置寄存器 |
| 0x000C | RMSNORM_PARAM | RW | 32 | RMSNorm 参数寄存器 |
| 0x0010 | ROPE_PARAM | RW | 32 | RoPE 参数寄存器 |
| 0x0014 | DATA_IN_ADDR | RW | 32 | 输入数据地址寄存器 |
| 0x0018 | DATA_OUT_ADDR | RW | 32 | 输出数据地址寄存器 |
| 0x001C | WEIGHT_ADDR | RW | 32 | 权重地址寄存器 |
| 0x0020 | ROPE_TABLE_ADDR | RW | 32 | RoPE 表地址寄存器 |
| 0x0024 | CYCLE_COUNT | R | 32 | 周期计数寄存器 |
| 0x0028 | IRQ_ENABLE | RW | 32 | 中断使能寄存器 |
| 0x002C | IRQ_STATUS | R | 32 | 中断状态寄存器 |
| 0x0030 | IRQ_CLEAR | RW | 32 | 中断清除寄存器 |

#### 2.2.1 Register Bit Definitions

**OP_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | op_start | 算子启动 |
| [1:2] | op_type | 算子类型 (0=RMSNorm, 1=RoPE, 2=Combined) |
| [3:5] | op_mode | 算子模式 |
| [6] | op_abort | 算子中止 |
| [7] | irq_en | 中断使能 |
| [8:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**OP_CONFIG (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:7] | vector_dim | 向量维度 (default: 64) |
| [8:15] | head_size | Head size (default: 8) |
| [16:17] | precision | 计算精度 (0=FP16, 1=FP32, 2=INT8) |
| [18] | rope_table_en | RoPE 预计算表使能 |
| [19:31] | reserved | 保留 |

**RMSNORM_PARAM (0x000C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:31] | epsilon | epsilon 值 (FP32 format, default: 1e-5) |

**ROPE_PARAM (0x0010)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:31] | base | RoPE base 值 (default: 10000) |

**OP_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | 算子就绪 |
| [1] | busy | 算子执行中 |
| [2] | done | 算子完成 |
| [3] | error | 错误标志 |
| [4:7] | current_op | 当前执行算子 |
| [8:15] | progress | 执行进度 (%) |
| [16:31] | reserved | 保留 |

## 3. Functional Description

### 3.1 RMSNorm Computation

RMSNorm (Root Mean Square Normalization) 对输入向量进行归一化处理，稳定训练和推理过程。

#### 3.1.1 Algorithm

公式：
```
RMSNorm(x) = x / sqrt(mean(x^2) + epsilon) * w

其中:
  x = 输入向量 [dim=64]
  w = 权重向量 [dim=64]
  epsilon = 1e-5 (防止除零)
```

#### 3.1.2 Computation Pipeline

```
RMSNorm Pipeline (dim=64):
    |
    v
Phase 1: Square Sum (并行)
    |-- 64个并行乘法器: x[i]^2
    |-- 树形加法器 (7级): sum(x[i]^2)
    |-- 输出: ss = sum(x[i]^2)
    |
    v
Phase 2: Normalize Factor (串行)
    |-- ss /= dim (除法)
    |-- ss += epsilon (加法)
    |-- rms = 1/sqrt(ss) (sqrt + 倒数)
    |-- 输出: rms
    |
    v
Phase 3: Scale & Output (并行)
    |-- 64个并行乘法器: out[i] = w[i] * rms * x[i]
    |-- 输出: normalized vector
    |
    v
Write output to SRAM
```

#### 3.1.3 Hardware Implementation

| Component | Description | Latency |
|-----------|-------------|---------|
| Square Array | 64个并行乘法器 | 1 cycle |
| Tree Adder | 7级树形加法器 | 7 cycles |
| Divider | 32-bit 除法器 | 2 cycles |
| Sqrt Unit | Newton-Raphson sqrt | 3 cycles |
| Scale Array | 64个并行乘法器 | 1 cycle |
| **Total Pipeline** | **流水线深度** | **~10 cycles** |

#### 3.1.4 Division-by-Zero Protection (B38 Fix)

**REQ-M11-010: RMSNorm Zero Input Check**

| Condition | Handling |
|-----------|----------|
| ss == 0 | Return zero vector + error flag |

**Error Signal**: `rms_zero_input_o` (1-bit)

#### 3.1.5 Optimization: Sqrt Lookup Table

| Feature | Description |
|---------|-------------|
| Table Size | 1024 entries (10-bit index) |
| Range | [1e-5, 1.0] 覆盖典型 ss 范围 |
| Precision | FP16 精度足够 |
| Latency | 1 cycle (查表) |

### 3.2 RoPE Computation

RoPE (Rotary Position Embedding) 将位置信息注入 Query 和 Key 向量，通过旋转操作实现相对位置编码。

#### 3.2.1 Algorithm

原理：
```
频率: freq = 1 / base^(head_dim/head_size)
角度: theta = position * freq
旋转: [x0, x1] -> [x0*cos(theta) - x1*sin(theta), x0*sin(theta) + x1*cos(theta)]
```

参数配置：
| Parameter | Value | Description |
|-----------|-------|-------------|
| head_size | 8 | Head dimension (dim/n_heads = 64/8) |
| base | 10000 | RoPE base 值 |
| vector_dim | 64 | 输入向量维度 |
| pairs | 32 | 需旋转的元素对数 (dim/2) |

#### 3.2.2 Frequency Table (head_size=8)

| head_dim | freq | theta @ pos=1 | theta @ pos=512 |
|----------|------|---------------|-----------------|
| 0 | 1.0000 | 1.0 | 512.0 |
| 1 | 0.3162 | 0.316 | 161.5 |
| 2 | 0.1000 | 0.1 | 51.2 |
| 3 | 0.0316 | 0.032 | 16.15 |
| 4 | 0.0100 | 0.01 | 5.12 |
| 5 | 0.0032 | 0.003 | 1.615 |
| 6 | 0.0010 | 0.001 | 0.512 |
| 7 | 0.0003 | 0.0003 | 0.1615 |

#### 3.2.3 Computation Pipeline

```
RoPE Pipeline (dim=64, head_size=8):
    |
    v
Phase 1: Angle Computation (可预计算)
    |-- head_dim = i % head_size (每对元素)
    |-- freq = 1 / base^(head_dim/head_size)
    |-- theta = position * freq
    |-- cos_theta, sin_theta = cos(theta), sin(theta)
    |
    v
Phase 2: Rotation (并行)
    |-- 32对并行旋转器
    |-- x0' = x0 * cos_theta - x1 * sin_theta
    |-- x1' = x0 * sin_theta + x1 * cos_theta
    |
    v
Write rotated Q/K to SRAM
```

#### 3.2.4 Pre-computed Table (Recommended)

| Feature | Value | Description |
|---------|-------|-------------|
| Table Size | seq_len * head_size/2 * 2 | Cos/Sin 表 |
| Storage | 512 * 4 * 2 = 4096 floats | ~16 KB |
| Addressing | rope_table_addr + pos * head_size + head_dim | 查表索引 |

使用预计算表时：
- Phase 1 简化为查表操作 (1 cycle)
- 消除实时 pow, cos, sin 计算
- 总延迟降低到 ~5 cycles

#### 3.2.5 Hardware Implementation

| Component | Description | Latency (实时) | Latency (查表) |
|-----------|-------------|----------------|----------------|
| Angle Calc | 4次 pow + 8次 cos/sin | 8 cycles | 1 cycle (查表) |
| Rotation Array | 32对并行旋转 (复数乘法) | 2 cycles | 2 cycles |
| SRAM Write | 写回 Q/K 向量 | 2 cycles | 2 cycles |
| **Total** | **流水线延迟** | **~15 cycles** | **~5 cycles** |

### 3.3 Combined Operation Flow

M11 支持 RMSNorm + RoPE 组合执行，减少 SRAM 访问次数。

#### 3.3.1 Combined Pipeline

```
Combined RMSNorm + RoPE:
    |
    v
Step 1: Read input vector from SRAM
    |-- data_in_addr -> x[64]
    |-- weight_addr -> w[64]
    |
    v
Step 2: RMSNorm computation (~10 cycles)
    |-- normalized = RMSNorm(x, w, epsilon)
    |
    v
Step 3: RoPE computation (~5 cycles with table)
    |-- rotated = RoPE(normalized, pos, rope_table)
    |
    v
Step 4: Write output to SRAM
    |-- data_out_addr <- rotated
    |
    v
Signal op_done_o
```

#### 3.3.2 SRAM Access Optimization

| Mode | SRAM Reads | SRAM Writes | Total Access |
|------|------------|-------------|--------------|
| Separate | 2 (x, w) + 1 (norm) + 1 (table) = 4 | 2 (norm, rotated) | 6 |
| Combined | 2 (x, w) + 1 (table) = 3 | 1 (rotated) | 4 |

Combined 模式减少 33% SRAM 访问。

### 3.4 Precision Handling

| Precision | Data Format | Computation | Storage |
|-----------|-------------|-------------|---------|
| FP16 | IEEE FP16 (E5M10) | FP16 native | 64-bit = 4 x FP16 |
| FP32 | IEEE FP32 (E8M23) | FP32 native | 128-bit = 4 x FP32 |

精度转换：
- FP16 计算：使用 FP16 乘法器和加法器
- FP32 计算：需要更高精度时使用 FP32 单元

### 3.5 FSM Design

#### 3.5.1 State Diagram

```
      +-------+
      | IDLE  |<--------------------+
      +---+---+                     |
          |                         |
      op_start=1                    |
          v                         |
      +-------+                     |
      | FETCH |                     |
      +---+---+                     |
          |                         |
      data fetched                  |
          v                         |
      +-------+                     |
      | COMPUTE|                    |
      |  NORM  |                    |
      +---+---+                     |
          |                         |
      norm done                      |
          v                         |
      +-------+                     |
      | COMPUTE|                    |
      |  ROPE  |--------------------+
      +---+---+   (op_type=RoPE only)
          |
      all done
          v
      +-------+
      | WRITE |
      +---+---+
          |
      write done
          v
      +-------+
      | DONE  |
      +---+---+
          |
      ack received
          v
      +-------+
      | IDLE  |
      +-------+
```

#### 3.5.2 State Definitions

| State | Code | Description | Duration |
|-------|------|-------------|----------|
| IDLE | 0x0 | 等待算子启动 | - |
| FETCH | 0x1 | 从 SRAM 读取输入数据 | 2-4 cycles |
| COMPUTE_NORM | 0x2 | RMSNorm 计算 | ~10 cycles |
| COMPUTE_ROPE | 0x3 | RoPE 计算 | ~5-15 cycles |
| WRITE | 0x4 | 结果写回 SRAM | 2 cycles |
| DONE | 0x5 | 完成，等待 ACK | 1 cycle |

## 4. Timing

### 4.1 RMSNorm Timing

| Parameter | Value @ 500 MHz | Value @ 250 MHz | Description |
|-----------|-----------------|-----------------|-------------|
| t_sram_fetch | 4 ns | 8 ns | SRAM 数据读取 |
| t_square | 2 ns | 4 ns | 64个平方计算 (并行) |
| t_sum_tree | 14 ns | 28 ns | 树形加法 (7级) |
| t_divider | 4 ns | 8 ns | 除法计算 |
| t_sqrt | 6 ns | 12 ns | sqrt 计算 (或查表 2 ns) |
| t_scale | 2 ns | 4 ns | 64个缩放计算 |
| t_sram_write | 4 ns | 8 ns | SRAM 结果写入 |
| **t_rmsnorm_total** | **~36 ns** | **~72 ns** | RMSNorm 总延迟 |
| **t_rmsnorm_cycles** | **~10 cycles** | **~10 cycles** | 流水线周期 |

### 4.2 RoPE Timing

| Parameter | Value @ 500 MHz (查表) | Value @ 500 MHz (实时) | Description |
|-----------|------------------------|------------------------|-------------|
| t_angle_fetch | 2 ns | - | 查表获取 cos/sin |
| t_pow_cos_sin | - | 16 ns | pow + cos + sin 计算 |
| t_rotation | 4 ns | 4 ns | 32对旋转计算 |
| t_sram_write | 4 ns | 4 ns | SRAM 结果写入 |
| **t_rope_total** | **~10 ns** | **~24 ns** | RoPE 总延迟 |
| **t_rope_cycles** | **~5 cycles** | **~15 cycles** | 流水线周期 |

### 4.3 Combined Operation Timing

| Parameter | Value @ 500 MHz | Description |
|-----------|-----------------|-------------|
| t_fetch | 4 ns | 输入数据读取 |
| t_rmsnorm | 36 ns | RMSNorm 计算 |
| t_rope | 10 ns | RoPE 计算 (查表) |
| t_write | 4 ns | 结果写入 |
| **t_combined_total** | **~54 ns** | 组合操作总延迟 |
| **t_combined_cycles** | **~15 cycles** | 流水线周期 |

### 4.4 Throughput

| Configuration | Throughput @ 500 MHz | Throughput @ 250 MHz |
|---------------|----------------------|----------------------|
| RMSNorm only | 50M ops/s | 25M ops/s |
| RoPE only (查表) | 100M ops/s | 50M ops/s |
| Combined | 33M ops/s | 16M ops/s |

### 4.5 DVFS Impact

| OP | Frequency | RMSNorm Latency | RoPE Latency | Combined Latency |
|----|-----------|-----------------|--------------|------------------|
| OP0 | 500 MHz | 36 ns | 10 ns | 54 ns |
| OP1 | 250 MHz | 72 ns | 20 ns | 108 ns |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **并行计算**: RMSNorm 和 RoPE 均采用并行计算架构，64个乘法器并行处理向量元素。

2. **树形加法器**: RMSNorm 使用 7 级树形加法器完成平方和计算，比串行加法快 9 倍。

3. **预计算表**: RoPE 强烈建议使用预计算 cos/sin 表，消除实时 pow/cos/sin 计算，延迟降低 3 倍。

4. **SRAM 直连**: M11 通过直接接口访问 M02 SRAM，避免总线仲裁延迟。

5. **组合执行**: RMSNorm + RoPE 组合执行减少中间结果 SRAM 写入，降低 33% SRAM 访问。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol |
|-----------|---------------|----------|
| SRAM Direct | M02 SRAM | Custom handshake (Priority 1) |
| Operator Control | M08 Scheduler / M13 ISA Decoder | Custom handshake |
| System Bus | M04 System Bus | TileLink/AXI (Config registers) |
| Power Control | M05 Power Manager | Direct control |
| Clock | M06 Clock Manager | CLK_SYS |

### 5.3 Verification Requirements

| Test Category | Description | Coverage Target |
|---------------|-------------|-----------------|
| RMSNorm Computation | 验证归一化精度，epsilon 处理 | 100% vector patterns |
| RoPE Computation | 验证旋转精度，位置索引 | All head_dim patterns |
| Combined Operation | 验证 RMSNorm+RoPE 流水 | 100% combined flows |
| Precision Switch | FP16/FP32 精度切换 | All precision modes |
| SRAM Access | 读/写正确性，地址边界 | 100% address range |
| Pre-computed Table | cos/sin 表查表正确性 | All table entries |
| DVFS | OP0/OP1 频率下功能验证 | All DVFS transitions |

### 5.4 Power Budget Allocation

| Component | Budget @ OP0 | Budget @ OP1 | Allocation |
|-----------|-------------|-------------|------------|
| Square Array (64 mul) | 15 mW | 7.5 mW | RMSNorm Phase 1 |
| Tree Adder | 5 mW | 2.5 mW | RMSNorm sum |
| Sqrt/Div Unit | 5 mW | 2.5 mW | RMSNorm Phase 2 |
| Rotation Array | 15 mW | 7.5 mW | RoPE computation |
| Control FSM | 5 mW | 2.5 mW | FSM + Registers |
| SRAM Interface | 5 mW | 2.5 mW | Bus interface |
| **Total** | **50 mW** | **25 mW** | REQ-PWR-001 compliance |

### 5.5 Physical Design Requirements

| Requirement | Value | Description |
|-------------|-------|-------------|
| Multiplier Array | 64 x FP16 mul | 8x8 systolic-like array |
| Adder Tree | 7-level binary tree | Log2(64) = 6 + 1 output |
| Sqrt Unit | Newton-Raphson | 3 iterations for FP16 |
| Table Memory | 16 KB SRAM | RoPE cos/sin 表 |
| Area Budget | < 0.5 mm^2 | 算子计算面积 |

### 5.6 Testability (DFT)

| Feature | Description |
|---------|-------------|
| Multiplier BIST | 64个乘法器自测试 |
| Adder Tree Test | 树形加法器路径测试 |
| Sqrt Unit Test | Newton-Raphson 收敛测试 |
| Table Memory BIST | RoPE 表 SRAM 测试 |
| Precision Test Mode | FP16/FP32 精度验证模式 |

### 5.7 Quality Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| RMSNorm Accuracy | < 1e-4 error | 与参考实现误差 |
| RoPE Accuracy | < 1e-4 error | 与参考实现误差 |
| Throughput | >= 100M ops/s | RoPE @ 500 MHz |
| Latency | < 50 ns | Combined operation |

## 6. Dependencies

| Module | Dependency Type | Description |
|--------|-----------------|-------------|
| M02 SRAM | Data storage | 输入/输出/权重/表存储 |
| M04 System Bus | Config access | 寄存器配置访问 |
| M05 Power Manager | Power control | DVFS, Power Gate |
| M06 Clock Manager | Clock source | CLK_SYS 时钟 |
| M08 Scheduler | Operation dispatch | 算子调度和启动 |
| M09 Attention Unit | Data consumer | RoPE 输出供 Attention 使用 |
| M13 ISA Decoder | Instruction decode | 算子指令解码 |