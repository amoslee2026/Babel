---
module: M09
type: MAS
status: complete
parent: null
module_type: compute
chiplet_features: [Multi-Head Attention, Causal Masking, KV Cache, RoPE Integration]
generated: "2026-05-17T15:30:00+08:00"
---

# M09: Attention Unit

## 1. Overview

M09 Attention Unit 是 TinyStories NPU 的 Transformer Attention 算子专用计算模块，实现 Multi-Head Attention、Causal Masking、KV Cache 管理，并与 M11 RoPE Unit 集成进行位置编码。该模块位于 Main Power Domain (PD_MAIN)，运行于 CLK_SYS 时钟域 (250-500 MHz)，是 Transformer 推理的核心计算单元之一。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| Multi-Head Attention | 8 Heads，Head Size = 8，支持 MQA | REQ-COMPUTE-008 |
| Causal Masking | 自回归推理因果掩码，防止关注未来位置 | REQ-COMPUTE-008 |
| KV Cache Management | 支持 Key/Value Cache 存储与检索 | REQ-MEM-004 |
| RoPE Integration | 与 M11 协作，支持 Rotary Position Embedding | REQ-COMPUTE-008 |
| Precision Support | FP8/FP16/INT8 混合精度 | REQ-COMPUTE-001, REQ-COMPUTE-002, REQ-COMPUTE-003 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 可调 |
| Power Domain | PD_MAIN | 0.7-0.9 V，支持 Power Gate |
| Base Address | 0x800A_0000 | Memory Map 中的 Attention Unit 基地址 |

### 1.3 Attention Parameters (TinyStories 15M)

| Parameter | Value | Description |
|-----------|-------|-------------|
| n_heads | 8 | Query 头数量 |
| n_kv_heads | 4 | Key/Value 头数量 (MQA) |
| head_size | 8 | 每个头的维度 |
| kv_dim | 32 | KV 向量维度 (4 × 8) |
| seq_len | 512 | 最大序列长度 |
| kv_mul | 2 | Query/KV 共享比 (每2个Query共享1个KV) |

### 1.4 Use Cases

| Use Case | Phase | Description |
|----------|-------|-------------|
| Prefill Attention | Prefill | Prompt token 的 Attention 计算 (批量) |
| Decode Attention | Decode | 逐 token Attention (单次 Q·K^T) |
| KV Cache Update | Both | 每次推理更新 KV Cache |
| Multi-Query Attention | Both | MQA 优化，减少 KV Cache 50% |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| clk_sys_i | Input | 1 | CLK_SYS | 主系统时钟 (250-500 MHz) |
| rst_sys_n_i | Input | 1 | CLK_SYS | 系统复位，低有效 |
| pg_main_en_i | Input | 1 | CLK_SYS | Power Gate 使能 (from M05) |

#### 2.1.2 Activation Input Interface (from M02 SRAM)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| act_valid_i | Input | 1 | CLK_SYS | 激活值输入有效 |
| act_data_i | Input | 512 | CLK_SYS | 激活值数据 (64-dim × 8 heads) |
| act_pos_i | Input | 16 | CLK_SYS | 当前 token 位置 (0-511) |
| act_layer_i | Input | 8 | CLK_SYS | 当前层索引 (0-4) |
| act_ready_o | Output | 1 | CLK_SYS | 激活值接收就绪 |

#### 2.1.3 Q/K/V Vector Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| q_valid_i | Input | 1 | CLK_SYS | Query 向量有效 |
| q_data_i | Input | 64 | CLK_SYS | Query 向量 (8 heads × 8-dim/head) |
| k_valid_i | Input | 1 | CLK_SYS | Key 向量有效 |
| k_data_i | Input | 32 | CLK_SYS | Key 向量 (4 KV heads × 8-dim/head) |
| v_valid_i | Input | 1 | CLK_SYS | Value 向量有效 |
| v_data_i | Input | 32 | CLK_SYS | Value 向量 (4 KV heads × 8-dim/head) |
| qkv_ready_o | Output | 1 | CLK_SYS | Q/K/V 接收就绪 |

#### 2.1.4 KV Cache Interface (to M02 SRAM)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| kv_addr_o | Output | 20 | CLK_SYS | KV Cache SRAM 地址 |
| kv_wdata_o | Output | 64 | CLK_SYS | KV Cache 写数据 |
| kv_wen_o | Output | 1 | CLK_SYS | KV Cache 写使能 |
| kv_rdata_i | Input | 64 | CLK_SYS | KV Cache 读数据 |
| kv_valid_o | Output | 1 | CLK_SYS | KV Cache 操作有效 |
| kv_ready_i | Input | 1 | CLK_SYS | KV Cache 操作就绪 |

#### 2.1.5 Systolic Array Interface (to M00)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sa_cmd_valid_o | Output | 1 | CLK_SYS | Systolic Array 命令有效 |
| sa_cmd_ready_i | Input | 1 | CLK_SYS | Systolic Array 命令就绪 |
| sa_op_i | Output | 2 | CLK_SYS | 操作类型 (0=QK, 1=QV, 2=KV) |
| sa_head_i | Output | 8 | CLK_SYS | Head 索引 (0-7) |
| sa_pos_i | Output | 16 | CLK_SYS | Position 索引 (0-511) |
| sa_result_valid_i | Input | 1 | CLK_SYS | 计算结果有效 |
| sa_result_data_i | Input | 256 | CLK_SYS | 计算结果数据 |
| sa_result_ready_o | Output | 1 | CLK_SYS | 计算结果接收就绪 |

#### 2.1.6 SoftMax Interface (to M12)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sm_valid_o | Output | 1 | CLK_SYS | SoftMax 输入有效 |
| sm_data_o | Output | 512 | CLK_SYS | SoftMax 输入数据 (score vector) |
| sm_head_o | Output | 8 | CLK_SYS | Head 索引 |
| sm_ready_i | Input | 1 | CLK_SYS | SoftMax 就绪 |
| sm_result_valid_i | Input | 1 | CLK_SYS | SoftMax 结果有效 |
| sm_result_data_i | Input | 512 | CLK_SYS | SoftMax 结果 (attention weights) |

#### 2.1.7 Output Interface (to M02 SRAM)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| out_valid_o | Output | 1 | CLK_SYS | 输出有效 |
| out_data_o | Output | 64 | CLK_SYS | Attention 输出 (8 heads × 8-dim) |
| out_layer_o | Output | 8 | CLK_SYS | 输出层索引 |
| out_ready_i | Input | 1 | CLK_SYS | 输出接收就绪 |

#### 2.1.8 Control Interface (from M08 Scheduler)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| attn_start_i | Input | 1 | CLK_SYS | Attention 计算启动 |
| attn_phase_i | Input | 2 | CLK_SYS | 计算阶段 (0=Score, 1=SoftMax, 2=Output) |
| attn_head_sel_i | Input | 8 | CLK_SYS | Head 选择掩码 |
| attn_done_o | Output | 1 | CLK_SYS | Attention 计算完成 |
| attn_busy_o | Output | 1 | CLK_SYS | Attention 计算忙碌 |

#### 2.1.9 RoPE Interface (to M11)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| rope_en_i | Input | 1 | CLK_SYS | RoPE 使能标志 |
| rope_q_rotated_i | Input | 64 | CLK_SYS | RoPE 处理后的 Q |
| rope_k_rotated_i | Input | 32 | CLK_SYS | RoPE 处理后的 K |
| rope_valid_i | Input | 1 | CLK_SYS | RoPE 结果有效 |

### 2.2 Register Map (Base: 0x800A_0000)

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | ATTN_CTRL | RW | 32 | Attention 控制寄存器 |
| 0x0004 | ATTN_CONFIG | RW | 32 | Attention 配置寄存器 |
| 0x0008 | ATTN_STATUS | R | 32 | Attention 状态寄存器 |
| 0x000C | ATTN_HEAD_CFG | RW | 32 | Head 配置寄存器 |
| 0x0010 | ATTN_POS | RW | 32 | 当前位置寄存器 |
| 0x0014 | ATTN_LAYER | RW | 32 | 当前层寄存器 |
| 0x0018 | ATTN_KV_ADDR | RW | 32 | KV Cache 基地址 |
| 0x001C | ATTN_PRECISION | RW | 32 | 精度配置寄存器 |
| 0x0020 | ATTN_SCALE | RW | 32 | Attention Scale Factor |
| 0x0024 | ATTN_IRQ_EN | RW | 32 | 中断使能寄存器 |
| 0x0028 | ATTN_IRQ_CLR | RW | 32 | 中断清除寄存器 |

#### 2.2.1 Register Bit Definitions

**ATTN_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | attn_enable | Attention 单元使能 |
| [1] | kv_update_en | KV Cache 更新使能 |
| [2] | causal_mask_en | Causal Masking 使能 |
| [3] | rope_en | RoPE 位置编码使能 |
| [4:5] | phase_sel | 计算阶段选择 (0=Score, 1=SoftMax, 2=Output) |
| [6] | start | 计算启动触发 |
| [7] | abort | 计算终止触发 |
| [8:31] | reserved | 保留 |

**ATTN_CONFIG (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:3] | n_heads | Query 头数量 (default: 8) |
| [4:7] | n_kv_heads | KV 头数量 (default: 4) |
| [8:15] | head_size | 每头维度 (default: 8) |
| [16:23] | seq_len | 最大序列长度 (default: 512) |
| [24:31] | reserved | 保留 |

**ATTN_STATUS (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | busy | 计算忙碌标志 |
| [1] | done | 计算完成标志 |
| [2] | kv_cache_full | KV Cache 满标志 |
| [3] | error | 错误标志 |
| [4:7] | current_head | 当前处理 Head 索引 |
| [8:15] | current_pos | 当前处理位置索引 |
| [16:31] | reserved | 保留 |

**ATTN_PRECISION (0x001C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:1] | data_precision | 数据精度 (0=FP32, 1=FP16, 2=FP8, 3=INT8) |
| [2:3] | kv_precision | KV Cache 精度 |
| [4:5] | score_precision | Score 计算精度 |
| [6:31] | reserved | 保留 |

**ATTN_SCALE (0x0020)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:31] | scale_factor | Attention Scale Factor = 1/sqrt(head_size) |

## 3. Functional Description

### 3.1 Attention Computation Flow

Attention 计算遵循标准 Multi-Head Attention 公式：

$$\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}}\right) V$$

#### 3.1.1 Pipeline Stages

| Stage | Operation | Duration | Description |
|-------|-----------|----------|-------------|
| Stage 1 | Q/K/V Load | 1-4 cycles | 从 SRAM 加载 Q/K/V 向量 |
| Stage 2 | RoPE (optional) | 2 cycles | 与 M11 协作进行位置编码 |
| Stage 3 | QK Score | pos cycles | Q·K^T 点积计算 (via M00) |
| Stage 4 | Causal Mask | 1 cycle | 应用因果掩码 |
| Stage 5 | SoftMax | pos cycles | 与 M12 协作进行 softmax |
| Stage 6 | AV Output | pos cycles | Attention weights × V |
| Stage 7 | KV Update | 2 cycles | 更新 KV Cache |
| Stage 8 | Output Store | 1-4 cycles | 输出写入 SRAM |

#### 3.1.2 Score Computation

| Step | Operation | FLOPs (pos=256) |
|------|-----------|-----------------|
| Per Head Score | Q·K^T 点积 | pos × head_size × 2 = 4,096 |
| Total Heads | 8 heads × score | 32,768 |
| Scale | divide by sqrt(8) | 256 |

Score 计算通过 M00 Systolic Array 进行矩阵乘法。

#### 3.1.3 Multi-Query Attention (MQA) Optimization

| Configuration | Standard Attention | MQA Attention |
|---------------|--------------------|---------------|
| Query Heads | 8 | 8 |
| KV Heads | 8 | 4 |
| KV Cache per Layer | 512 × 64 × 2 = 64 KB | 512 × 32 × 2 = 32 KB |
| KV Cache Total (5 layers) | 320 KB | 160 KB |

MQA 实现机制：
```
KV Head Mapping:
  Head 0,1 → KV Head 0 (shared)
  Head 2,3 → KV Head 1 (shared)
  Head 4,5 → KV Head 2 (shared)
  Head 6,7 → KV Head 3 (shared)

Score Calculation:
  Each Query Head uses corresponding KV Head
  2 Query Heads share same K and V vectors
```

### 3.2 Causal Masking

#### 3.2.1 Masking Logic

自回归推理中，当前位置只能关注历史位置：

| Position | Valid Positions | Mask |
|----------|-----------------|------|
| pos = 0 | 0 only | mask[1-511] = -inf |
| pos = 1 | 0, 1 | mask[2-511] = -inf |
| pos = n | 0 to n | mask[n+1-511] = -inf |
| pos = 511 | 0 to 511 | no mask |

#### 3.2.2 Masking Implementation

```
Causal Mask Application:
    |
    v
Load score vector for head h at position p
    |
    v
For i > p:
    score[i] = -inf (or large negative value)
    |
    v
Pass masked scores to SoftMax (M12)
```

Mask 值选择：
- FP32: -1e20 (足够大负数)
- FP16: -65504 (最大负数)
- FP8: -240 (E4M3 最大负数)

### 3.3 KV Cache Management

#### 3.3.1 KV Cache Layout

| Layer | Key Cache | Value Cache | Total |
|-------|-----------|-------------|-------|
| Layer 0 | 512 × 32 × FP16 = 32 KB | 512 × 32 × FP16 = 32 KB | 64 KB |
| Layer 1 | 32 KB | 32 KB | 64 KB |
| Layer 2 | 32 KB | 32 KB | 64 KB |
| Layer 3 | 32 KB | 32 KB | 64 KB |
| Layer 4 | 32 KB | 32 KB | 64 KB |
| **Total** | **160 KB** | **160 KB** | **320 KB** |

地址分配 (SRAM):
```
Key Cache:
  Base: 0x8004_0000
  Layer 0: 0x8004_0000 - 0x8004_7FFF
  Layer 1: 0x8004_8000 - 0x8004_FFFF
  ...

Value Cache:
  Base: 0x8006_0000
  Layer 0: 0x8006_0000 - 0x8006_7FFF
  Layer 1: 0x8006_8000 - 0x8006_FFFF
  ...
```

#### 3.3.2 KV Cache Access Pattern

| Phase | Access Type | Description |
|-------|-------------|-------------|
| Prefill | Write | 批量写入 prompt 的 K/V |
| Decode | Read + Write | 读取历史 K/V，写入新 K/V |

Prefill Phase KV Update：
```
For pos in [0, prompt_len-1]:
    Compute K, V from input activation
    Apply RoPE to K (optional)
    Write K to key_cache[layer, pos]
    Write V to value_cache[layer, pos]
```

Decode Phase KV Access：
```
pos = current_position
    |
    v
Read key_cache[layer, 0:pos-1] → K_history
Read value_cache[layer, 0:pos-1] → V_history
    |
    v
Compute new K, V from current activation
    |
    v
Write K to key_cache[layer, pos]
Write V to value_cache[layer, pos]
    |
    v
Compute Attention using K_history + K_new
```

#### 3.3.3 KV Cache Boundary Handling (B29/B30 Fix)

**REQ-M09-010: KV Cache Overflow Protection**

| Boundary | Condition | Handling |
|----------|-----------|----------|
| pos > 512 | Truncate to 512, set flag | Drop new K/V |
| pos >= seq_len | Stop update | Use existing cache |

**Error Signal**: `kv_overflow_o` (1-bit output)

## 4. Verification

### 3.4 RoPE Integration

#### 3.4.1 RoPE Operation

RoPE (Rotary Position Embedding) 通过旋转向量编码位置信息：

| Parameter | Value | Description |
|-----------|-------|-------------|
| Head Size | 8 | 向量维度 |
| Theta Base | 10000 | 旋转频率基准 |
| Position Range | 0-511 | 位置范围 |

RoPE 公式：
$$Q_{rotated} = Q \cdot \cos(\theta_p) + rotate(Q) \cdot \sin(\theta_p)$$

#### 3.4.2 RoPE Flow

```
RoPE Integration:
    |
    v
M09 receives raw Q, K vectors
    |
    v
Check rope_en_i flag
    |
    +-- Disabled --> Use raw Q, K directly
    |
    +-- Enabled --> Forward to M11 (RoPE Unit)
        |
        v
    M11 applies rotation
        |
        v
    M09 receives rope_q_rotated_i, rope_k_rotated_i
        |
        v
    Use rotated Q, K for Score computation
```

### 3.5 Precision Handling

#### 3.5.1 Precision Modes

| Mode | Q/K/V | Score | SoftMax | Output |
|------|-------|-------|---------|--------|
| FP32 | FP32 | FP32 | FP32 | FP32 |
| FP16 | FP16 | FP16 | FP16 | FP16 |
| FP8 KV | FP8 | FP16 | FP16 | FP16 |
| INT8 | INT8 | INT32 | FP16 | FP16 |

#### 3.5.2 Precision Conversion

| Conversion | Location | Description |
|------------|----------|-------------|
| INT8 → FP16 | Input | 反量化，恢复精度 |
| FP16 → FP8 | KV Cache | KV 压缩存储 |
| FP8 → FP16 | KV Read | KV 解压缩 |
| FP16 → FP32 | Score | 精度保持 |
| FP32 → FP16 | Output | 输出量化 |

FP8 KV Cache 优势：
- KV Cache 容量减半: 160 KB → 80 KB
- 带宽需求减半
- 精度损失 < 0.5%

## 4. Timing

### 4.1 Prefill Phase Timing (pos = prompt_len)

| Stage | Duration @ 500 MHz | FLOPs | Description |
|-------|--------------------|-------|-------------|
| Q/K/V Compute | 4 cycles × heads × pos | 128K | 每个 token 计算 Q/K/V |
| KV Update | 2 cycles × heads × pos | - | 写入 KV Cache |
| QK Score | pos cycles × heads × pos | 32K × pos | 每个 token 与所有历史 score |
| SoftMax | pos cycles × heads × pos | 6K × pos | 每个 head softmax |
| AV Output | pos cycles × heads × pos | 32K × pos | Attention × V |

**Prefill Latency (256 tokens)**: ~260 ms @ 500 MHz

### 4.2 Decode Phase Timing (single token)

| Stage | Duration @ 500 MHz | FLOPs | Description |
|-------|--------------------|-------|-------------|
| Q Compute | 4 cycles | 128 | 计算 Query |
| KV Load | 2 cycles × pos | - | 读取历史 KV |
| KV Update | 2 cycles | - | 写入新 K/V |
| QK Score | pos cycles | 32K | Q 与历史 K 点积 |
| SoftMax | pos cycles | 6K | SoftMax 归一化 |
| AV Output | pos cycles | 32K | Attention × V |
| **Total** | **~pos + 10 cycles** | **~70K** | **Per token latency** |

**Decode Latency (pos=256)**: ~522 cycles ≈ 1.04 μs @ 500 MHz

### 4.3 Attention Pipeline Timing

| Parameter | Value @ 500 MHz | Value @ 250 MHz | Description |
|-----------|-----------------|-----------------|-------------|
| t_qkv_load | 4 cycles (8 ns) | 4 cycles (16 ns) | Q/K/V 加载时间 |
| t_rope | 2 cycles (4 ns) | 2 cycles (8 ns) | RoPE 处理时间 |
| t_score_per_pos | 1 cycle (2 ns) | 1 cycle (4 ns) | 单次点积 |
| t_softmax_per_pos | pos cycles | pos cycles | SoftMax 时间 |
| t_av_per_pos | 1 cycle (2 ns) | 1 cycle (4 ns) | 单次 AV 计算 |
| t_kv_update | 2 cycles (4 ns) | 2 cycles (8 ns) | KV Cache 更新 |

### 4.4 Memory Access Timing

| Access Type | Latency | Bandwidth | Description |
|-------------|---------|-----------|-------------|
| KV Cache Read | 2 ns | 8 GB/s | M02 SRAM 读 |
| KV Cache Write | 2 ns | 8 GB/s | M02 SRAM 写 |
| Activation Load | 2 ns | 8 GB/s | M02 SRAM 读 |
| Output Store | 2 ns | 8 GB/s | M02 SRAM 写 |

### 4.5 DVFS Impact

| OP | Frequency | Decode Latency (pos=256) | Bandwidth |
|----|-----------|--------------------------|-----------|
| OP0 | 500 MHz | 1.04 μs | 8 GB/s |
| OP1 | 250 MHz | 2.08 μs | 4 GB/s |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **MQA Optimization**: 4 KV Heads 共享给 8 Query Heads，减少 KV Cache 50%，降低带宽压力。

2. **Systolic Array Integration**: QK Score 和 AV Output 使用 M00 Systolic Array 进行矩阵乘法，最大化吞吐量。

3. **SoftMax Delegation**: SoftMax 计算委托给 M12 SoftMax Unit，专用硬件加速 exp 计算。

4. **RoPE Integration**: RoPE 由 M11 处理，M09 通过 handshake 接收旋转后的 Q/K。

5. **Causal Masking**: Score 计算后立即应用 mask，避免无效计算。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol | Description |
|-----------|---------------|----------|-------------|
| Systolic Array | M00 | Custom handshake | QK, AV 矩阵乘法 |
| SRAM (KV Cache) | M02 | Direct access | KV 存取，Priority 1 |
| SoftMax | M12 | Custom handshake | Score 归一化 |
| RoPE | M11 | Custom handshake | Q/K 旋转 |
| Scheduler | M08 | Control interface | 计算调度 |
| Power Manager | M05 | Power control | DVFS, Power Gate |

### 5.3 Verification Requirements

| Test Category | Description | Coverage Target |
|---------------|-------------|-----------------|
| MQA Score | 8 Heads × 4 KV Heads 共享验证 | 100% head combinations |
| Causal Mask | 所有位置掩码正确性 | pos 0-511 |
| KV Cache | Prefill/Decode 更新，边界条件 | 100% cache coverage |
| RoPE Integration | 与 M11 协作正确性 | All positions |
| Precision | FP8/FP16/INT8 混合精度 | All precision modes |
| Pipeline | Prefill/Decode 完整流程 | E2E inference |

### 5.4 Power Budget Allocation

| Domain | Budget @ OP0 | Budget @ OP1 | Allocation |
|--------|-------------|-------------|------------|
| Score Compute (via M00) | 50 mW | 25 mW | Systolic Array |
| SoftMax (via M12) | 20 mW | 10 mW | SoftMax Unit |
| KV Cache Logic | 30 mW | 15 mW | Cache 管理 |
| Control/Arb | 20 mW | 10 mW | 控制逻辑 |
| **Total** | **120 mW** | **60 mW** | REQ-PWR-001 contribution |

### 5.5 Physical Design Requirements

| Requirement | Value | Description |
|-------------|-------|-------------|
| Compute Density | N/A | 使用 M00 共享 |
| KV Cache Logic Area | < 0.5 mm² | 地址管理 + 控制 |
| Control Logic Area | < 0.3 mm² | Pipeline 控制 |

### 5.6 Testability (DFT)

| Feature | Description |
|---------|-------------|
| Head Isolation | 可独立测试每个 Head |
| KV Cache BIST | SRAM 自测试 (via M02) |
| Score Pipeline Test | 可注入测试 Score 值 |
| Mask Test Mode | 可验证所有 Mask 值 |

### 5.7 Quality Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| MQA Accuracy | < 0.5% loss vs Standard | MQA 精度损失 |
| FP8 KV Accuracy | < 0.5% loss vs FP16 | FP8 KV Cache 精度损失 |
| Latency (Decode) | < 2 μs @ 500 MHz | 单 token decode 延迟 |

## 6. Dependencies

| Module | Dependency Type | Description |
|--------|-----------------|-------------|
| M00 Systolic Array | Compute | QK Score, AV Output 矩阵乘法 |
| M02 SRAM Scratchpad | Storage | KV Cache, Activation, Output 存储 |
| M08 Scheduler | Control | 计算调度，phase 控制 |
| M11 RoPE Unit | Pre-process | Q/K 位置编码 |
| M12 SoftMax Unit | Compute | Score 归一化 |
| M05 Power Manager | Power | DVFS, Power Gate 控制 |
| M06 Clock Manager | Clock | CLK_SYS 时钟源 |