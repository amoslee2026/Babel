---
module: M01
type: MAS
status: complete
chiplet_features: [SpatialDataflow, MultiThread, OperatorDispatch]
---

# M01: Dataflow Controller

## 1. Overview

M01 是 TinyStories NPU 的数据流调度控制器，负责 Spatial Dataflow 流水线调度、算子分发、多线程管理和内存一致性维护。作为计算子系统核心调度单元，协调 M00 Systolic Array 与 Transformer Operator Units (M09-M12) 的执行。

**核心指标**：

| Feature | Target | REQ Reference |
|---------|--------|---------------|
| Pipeline Utilization | >= 80% | REQ-COMPUTE-005 |
| Thread Count | >= 2 | REQ-COMPUTE-006 |
| Mixed Precision | FP32/FP16/INT8/FP8 | REQ-COMPUTE-007 |
| Operator Coverage | Attention/FFN/RMSNorm/RoPE/SoftMax | REQ-COMPUTE-008 |

**时钟域**：CLK_SYS (250-500 MHz)
**电源域**：PD_MAIN (DVFS 支持)
**模块类型**：control

## 2. Interface

### 2.1 Systolic Array Control Interface (M00)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `syst_mode` | 1 | Output | WS=0 / OS=1 模式选择 |
| `syst_precision` | 2 | Output | FP8=00 / FP16=01 / INT8=10 / FP32=11 |
| `syst_start` | 1 | Output | 启动计算脉冲 |
| `syst_done` | 1 | Input | 计算完成标志 |
| `syst_err` | 2 | Input | 错误码 |
| `syst_row_cnt` | 8 | Output | 活动行数 (0-127) |
| `syst_col_cnt` | 8 | Output | 活动列数 (0-127) |
| `syst_src_addr` | 32 | Output | 源操作数基地址 |
| `syst_dst_addr` | 32 | Output | 目标地址 |
| `syst_shape` | 64 | Output | 张量形状 (M/N/K 编码) |

### 2.2 Operator Unit Dispatch Interface (M09-M12)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `op_valid` | 1 | Output | 算子指令有效 |
| `op_ready` | 4 | Input | 各算子单元就绪标志 |
| `op_code` | 8 | Output | 算子操作码 |
| `op_unit_sel` | 4 | Output | 目标算子单元选择 |
| `op_tid` | 1 | Output | 线程 ID |
| `op_precision` | 2 | Output | 精度配置 |
| `op_src_addr` | 32 | Output | 源数据地址 |
| `op_dst_addr` | 32 | Output | 输出数据地址 |
| `op_params` | 128 | Output | 算子参数 (维度、stride等) |
| `op_done` | 4 | Input | 各算子完成标志 |
| `op_err` | 8 | Input | 各算子错误码 |

**Operator Unit Mapping**：

| op_unit_sel | Target Module | Operator |
|-------------|---------------|----------|
| 0x1 | M09 | Attention |
| 0x2 | M10 | FFN/MatMul |
| 0x3 | M11 | RMSNorm/RoPE |
| 0x4 | M12 | SoftMax |

### 2.3 Memory Request Interface (M02/M03 via M04)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `mem_req_valid` | 1 | Output | 内存请求有效 |
| `mem_req_ready` | 1 | Input | 内存子系统就绪 |
| `mem_req_type` | 2 | Output | 读=00 / 写=01 / 刷新=10 |
| `mem_req_addr` | 32 | Output | 目标地址 |
| `mem_req_size` | 16 | Output | 请求大小 (bytes) |
| `mem_req_tid` | 1 | Output | 线程 ID (用于优先级仲裁) |
| `mem_resp_valid` | 1 | Input | 响应有效 |
| `mem_resp_data` | 64 | Input | 读数据 (per beat) |
| `mem_resp_last` | 1 | Input | Burst 最后一拍 |
| `mem_resp_err` | 2 | Input | 响应错误码 |

### 2.4 Thread Scheduler Interface (M08)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `sched_thread_en` | 2 | Input | 线程使能 (bit0=T0, bit1=T1) |
| `sched_priority` | 2 | Input | 线程优先级配置 |
| `sched_yield` | 1 | Output | 线程让出请求 |
| `sched_current_tid` | 1 | Output | 当前运行线程 ID |
| `sched_status` | 4 | Output | 调度状态 (idle/run/wait) |

### 2.5 System Bus Interface (M04 AXI4)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `axi_awvalid` | 1 | Output | 写地址有效 |
| `axi_awready` | 1 | Input | 写地址就绪 |
| `axi_awaddr` | 32 | Output | 写地址 |
| `axi_awlen` | 8 | Output | Burst 长度 |
| `axi_wvalid` | 1 | Output | 写数据有效 |
| `axi_wready` | 1 | Input | 写数据就绪 |
| `axi_wdata` | 64 | Output | 写数据 |
| `axi_wlast` | 1 | Output | Burst 最后一拍 |
| `axi_bvalid` | 1 | Input | 写响应有效 |
| `axi_bresp` | 2 | Input | 写响应状态 |

### 2.6 Interrupt Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `irq_op_done` | 1 | Output | 算子完成中断 (电平触发) |
| `irq_err` | 1 | Output | 错误中断 |
| `irq_tid` | 1 | Output | 触发中断的线程 ID |

## 3. Functional Description

### 3.1 Spatial Pipeline Architecture

**数据流原理**：算子间流水线并行，数据在算子单元间直接传递，减少 SRAM 读写开销。

**Spatial Pipeline Stages**：

```
Stage 0: Memory Load
  - 从 M02/M03 加载输入数据到 SRAM scratchpad
  - 预取下一算子所需权重

Stage 1: Attention Compute (M09)
  - Q*K attention score 计算
  - SoftMax 归一化 (M12)
  - Score*V attention output

Stage 2: FFN Compute (M10)
  - MatMul W1: hidden_dim → intermediate_dim
  - GELU activation
  - MatMul W2: intermediate_dim → hidden_dim

Stage 3: Normalization (M11)
  - RMSNorm: 层归一化
  - RoPE: 位置编码

Stage 4: Memory Writeback
  - 输出写入 SRAM/DRAM
  - KV cache 更新
```

**Pipeline 利用率计算**：

```
Utilization = Active_Cycles / Total_Cycles * 100%

Target: >= 80% (REQ-COMPUTE-005)

影响因素：
- Pipeline bubble: 算子间数据依赖
- Memory stall: SRAM/DRAM 访问延迟
- Thread switch: 多线程上下文切换
```

### 3.2 Operator Dispatch Logic

**算子调度表**：

| Operator | op_code | Instruction Sequence | Precision Support |
|----------|---------|---------------------|-------------------|
| Attention | 0x01 | LOAD_Q → LOAD_K → LOAD_V → MATMUL_QK → SOFTMAX → MATMUL_AV → STORE | FP32/FP16 |
| FFN | 0x02 | LOAD_X → MATMUL_W1 → GELU → MATMUL_W2 → STORE | FP32/FP16/INT8 |
| RMSNorm | 0x03 | LOAD_X → LOAD_W → RMSN_COMPUTE → STORE | FP32/FP16 |
| RoPE | 0x04 | LOAD_X → LOAD_FREQ → ROPE_COMPUTE → STORE | FP32/FP16 |
| SoftMax | 0x05 | LOAD_SCORE → SOFTMAX_COMPUTE → STORE | FP32/FP16 |

**Dispatch FSM**：

```
State Machine:
  IDLE → FETCH_OP → DECODE → DISPATCH → WAIT_DONE → COMPLETE → IDLE

State Transitions:
  IDLE: 等待调度器启动
  FETCH_OP: 从指令队列获取下一算子
  DECODE: 解析算子参数，确定目标单元
  DISPATCH: 发送指令到目标算子单元
  WAIT_DONE: 等待算子完成
  COMPLETE: 更新状态，触发中断
```

### 3.3 Multi-thread Management

**线程架构**：

- 线程数：2 (TID=0, TID=1)
- 调度策略：Round-Robin，算子边界切换
- 上下文切换开销：<= 4 CLK_SYS 周期

**线程上下文内容**：

| Context Field | Width | Description |
|---------------|-------|-------------|
| `thread_pc` | 32 | 程序计数器 |
| `op_queue_ptr` | 16 | 指令队列读指针 |
| `op_state` | 8 | 当前算子状态 |
| `precision_cfg` | 2 | 精度配置 |
| `sram_alloc` | 32 | SRAM 分配表 |

**线程调度策略**：

```
Round-Robin with Priority Boost:
  1. 默认 Round-Robin: T0 → T1 → T0 → ...
  2. 优先级提升: 长时间等待线程优先级+1
  3. Yield 机制: 算子完成时可让出

调度开销优化：
  - 预加载上下文: 算子完成前预取下一线程上下文
  - Pipeline overlap: 上下文切换与数据流并行
```

### 3.4 Memory Coherence

**SRAM 分配策略**：

| Region | Size | Purpose |
|--------|------|---------|
| Region 0 | 128 KB | 输入数据 buffer |
| Region 1 | 128 KB | 权重 cache |
| Region 2 | 128 KB | 中间结果 buffer |
| Region 3 | 128 KB | 输出 buffer + KV cache |

**Coherence Mechanism**：

```
1. 地址分配: 算子启动前分配 SRAM 区域
2. 数据依赖检查: 确保写入完成后再读取
3. 读写仲裁: 多线程访问 SRAM 优先级仲裁
4. 刷新控制: Pipeline flush 时清除未完成操作
```

### 3.5 Mixed Precision Handling

**精度组合支持** (REQ-COMPUTE-007)：

| Scenario | Input | Weight | Accumulate | Output |
|----------|-------|--------|------------|--------|
| FP16 inference | FP16 | FP16 | FP32 | FP16 |
| INT8 quantized | INT8 | INT8 | FP32 | FP16/INT8 |
| FP8 KV cache | FP8 | FP8 | FP32 | FP8 |
| FP32 baseline | FP32 | FP32 | FP32 | FP32 |

**精度转换控制**：

```
Precision Control Signals:
  - op_precision[1:0]: 算子执行精度
  - mix_precision_en: 混合精度模式使能
  - fp8_format: E4M3=0 / E5M2=1

精度转换位置：
  - 输入: FP16_to_FP32 / FP8_to_FP16
  - 累加: FP32 accumulator
  - 输出: FP32_to_FP16 / FP16_to_FP8
```

## 4. Timing

### 4.1 Pipeline Performance

**Spatial Pipeline 时序**：

| Pipeline Stage | Latency (cycles) | Throughput |
|----------------|------------------|------------|
| Memory Load | 10-50 (DRAM) / 2 (SRAM) | 1 load/op |
| Attention | 256 (128x128) | 1 attention/block |
| FFN | 384 (2 MatMul) | 1 FFN/block |
| Normalization | 32 | 1 norm/block |
| Writeback | 2-50 | 1 write/op |

**利用率优化**：

| Technique | Improvement |
|-----------|-------------|
| Data prefetch | 减少 Memory stall 50% |
| Operator overlap | Pipeline 利用率 +20% |
| Thread interleaving | 隐藏 Memory latency |

### 4.2 Dispatch Latency

| Operation | Latency (cycles) |
|-----------|------------------|
| Op Fetch | 1-2 |
| Op Decode | 1 |
| Dispatch | 1 |
| Context Switch | <= 4 |

### 4.3 Memory Request Timing

| Request Type | Latency | Notes |
|--------------|---------|-------|
| SRAM Read | 2 cycles | Single cycle access + register |
| SRAM Write | 2 cycles | |
| DRAM Read (row hit) | <= 100 ns | REQ-MEM-003 |
| DRAM Write | <= 100 ns | |

### 4.4 DVFS Operating Points

| Point | Frequency | Voltage | Pipeline Utilization | Notes |
|-------|-----------|---------|---------------------|-------|
| High | 500 MHz | 0.9 V | >= 80% | Peak performance |
| Medium | 350 MHz | 0.8 V | >= 70% | Balanced |
| Low | 250 MHz | 0.7 V | >= 60% | Power saving |

REQ-PWR-003 要求支持 >= 2 DVFS 工作点。

## 5. Implementation

### 5.1 Register Map

**基地址**：由 M04 System Bus 分配 (APB 从接口)

| Offset | Name | Width | Access | Description |
|--------|------|-------|--------|-------------|
| 0x000 | CTRL | 32 | RW | [0]=全局使能, [1]=软复位, [3:2]=调度模式 |
| 0x004 | STATUS | 32 | RO | [0]=IDLE, [1]=BUSY, [3:2]=当前TID, [7:4]=Pipeline阶段 |
| 0x008 | THREAD_CFG0 | 32 | RW | 线程0: [1:0]=精度, [7:2]=算子掩码 |
| 0x00C | THREAD_CFG1 | 32 | RW | 线程1: 同上 |
| 0x010 | OP_QUEUE_BASE | 32 | RW | 指令队列基地址 |
| 0x014 | OP_QUEUE_DEPTH | 16 | RW | 指令队列深度 |
| 0x018 | PERF_CNT0 | 32 | RO | 线程0 完成算子计数 |
| 0x01C | PERF_CNT1 | 32 | RO | 线程1 完成算子计数 |
| 0x020 | PERF_UTIL | 32 | RO | [15:0]=Pipeline利用率 (Q16格式) |
| 0x024 | IRQ_MASK | 32 | RW | 中断使能掩码 |
| 0x028 | IRQ_STATUS | 32 | RW1C | 中断状态, 写1清 |
| 0x02C | SRAM_ALLOC | 32 | RW | SRAM 分配配置 |
| 0x030 | ERR_CODE | 32 | RO | 错误码寄存器 |

### 5.2 Design Considerations

1. **Pipeline Utilization Optimization**：
   - Data prefetch 减少 Memory stall
   - Operator overlap 提高流水线填充
   - Thread interleaving 隐藏延迟

2. **Multi-thread Trade-off**：
   - 2 线程平衡复杂度与利用率
   - 上下文切换开销 <= 4 cycles
   - 可扩展至 4 线程 (未来版本)

3. **SRAM Bandwidth Matching**：
   - Peak: 4 ops/cycle * 128 bit = 512 bit/cycle
   - SRAM bandwidth >= 512 bit/cycle @ 500 MHz

4. **Power Optimization**：
   - Clock gating: 空闲 Pipeline stage
   - Power gating: 空闲算子单元
   - DVFS: 动态调整频率/电压

### 5.3 Verification Strategy

| Test Category | Description |
|---------------|-------------|
| Functional | Operator dispatch correctness, all precision combinations |
| Pipeline | Spatial dataflow utilization >= 80% REQ-COMPUTE-005 |
| Thread | Multi-thread correctness, context switch latency <= 4 cycles |
| Memory | Coherence verification, SRAM allocation/deallocation |
| Timing | Dispatch latency, Pipeline throughput |
| Power | DVFS transition, clock/power gating |

### 5.4 Integration Notes

- **M00 Systolic Array**: MatMul/Attention 核心计算
- **M09-M12 Operator Units**: 算子执行单元
- **M02 SRAM**: 512 KB scratchpad, 数据缓存
- **M03 DRAM Controller**: 主存储器访问
- **M04 System Bus**: AXI4 互联
- **M08 Multi-thread Scheduler**: 线程调度协调

### 5.5 Physical Design Guidelines

| Parameter | Target | Notes |
|-----------|--------|-------|
| Controller Area | <= 5 mm² | Routing-intensive design |
| Timing Closure | <= 500 MHz | @ TT/0.9V |
| Power | <= 0.2 W | Control logic dominant |

### 5.6 References

- REQ-COMPUTE-005: Pipeline utilization >= 80%
- REQ-COMPUTE-006: Multi-thread >= 2
- REQ-COMPUTE-007: Mixed precision support
- REQ-COMPUTE-008: Transformer operator coverage
- REQ-PWR-003: DVFS >= 2 operating points
- Block Diagram: `/spec/ARCH/block_diagram.md`
- PRD: `/spec/PRD/PRD.md`