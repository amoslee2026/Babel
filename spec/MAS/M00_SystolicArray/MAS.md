---
module: M00
type: MAS
status: complete
parent: TOP
module_type: compute
generated: 2026-05-12T09:20:00Z
---

# M00_SystolicArray — Module Architecture Spec

## 1. 模块概述

M00_SystolicArray 是 TinyStories NPU 的核心计算单元，实现脉动阵列矩阵乘法加速。

| 属性 | 值 |
|------|----|
| 工艺 | 三星 SF4 4nm |
| 时钟域 | CLK_SYS 500 MHz |
| 电源域 | PD_MAIN |
| PE 阵列规模 | 32×32 = 1024 PE |
| 目标算力 | 0.5 TOPS FP32 / 1 TOPS FP16 / 2 TOPS INT8 |
| 支持数据流 | Weight Stationary (WS) / Output Stationary (OS) |
| 支持精度 | FP32 / FP16 / INT8 |

算力推导：
- FP32: 1024 PE × 1 MAC/cycle × 500 MHz × 2 ops/MAC = 1.024 TFLOPS ≈ 0.5 TOPS（保守估计含流水线气泡）
- FP16: 2× FP32 = 1 TOPS
- INT8: 4× FP32 = 2 TOPS（PE 内部 SIMD 精度切换）

## 2. 接口信号表

### 2.1 与 M01_DataflowController 控制接口

| 信号名 | 方向 | 宽度 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 系统时钟 500 MHz |
| rst_n | input | 1 | 异步低有效复位 |
| sa_start | input | 1 | 启动计算脉冲 |
| sa_done | output | 1 | 计算完成脉冲 |
| dataflow_mode | input | 1 | 0=WS, 1=OS |
| precision_mode | input | 2 | 00=FP32, 01=FP16, 10=INT8 |
| dim_m | input | 6 | 矩阵 M 维度（1~32） |
| dim_n | input | 6 | 矩阵 N 维度（1~32） |
| dim_k | input | 10 | 矩阵 K 维度（1~1024） |
| sa_busy | output | 1 | 阵列忙状态 |
| sa_stall | output | 1 | 背压信号 |

### 2.2 与 M02_SRAM 数据接口

| 信号名 | 方向 | 宽度 | 描述 |
|--------|------|------|------|
| weight_in | input | 32×32 | 权重输入总线（每 PE 1 word） |
| weight_valid | input | 1 | 权重数据有效 |
| weight_ready | output | 1 | 权重接收就绪 |
| act_in | input | 32×32 | 激活值输入总线 |
| act_valid | input | 1 | 激活数据有效 |
| act_ready | output | 1 | 激活接收就绪 |
| result_out | output | 32×32 | 结果输出总线 |
| result_valid | output | 1 | 结果有效 |
| result_ready | input | 1 | 下游接收就绪 |

> 注：weight_in/act_in/result_out 总线宽度随 precision_mode 变化：FP32=32bit/PE，FP16=16bit/PE，INT8=8bit/PE。

## 3. PE 阵列结构

```
         act_in[0]  act_in[1]  ...  act_in[31]
            |          |                |
weight_in[0]→ PE[0,0] → PE[0,1] → ... → PE[0,31] → result_out[0]
weight_in[1]→ PE[1,0] → PE[1,1] → ... → PE[1,31] → result_out[1]
    ...
weight_in[31]→PE[31,0]→ PE[31,1]→ ... → PE[31,31]→ result_out[31]
```

- 行方向：权重（weight）水平传播（WS 模式下固定）
- 列方向：激活值（activation）垂直传播
- 每个 PE 执行 1 次 MAC，并将部分和向右/向下传递

## 4. 精度切换机制

| precision_mode | 数据宽度 | PE MAC 类型 | 有效 PE 数 | 等效算力 |
|----------------|----------|-------------|------------|----------|
| 00 (FP32) | 32 bit | FP32 MAC | 1024 | 0.5 TOPS |
| 01 (FP16) | 16 bit | FP16 MAC | 1024 | 1 TOPS |
| 10 (INT8) | 8 bit | INT8 MAC×2 | 1024×2 | 2 TOPS |

INT8 模式下每个 PE 内部拆分为 2 个 INT8 MAC 单元并行执行。

## 5. 流水线结构

```
Stage 1: 输入缓冲 (Input Buffer)
  - weight_in / act_in 对齐缓冲，skew 补偿
  - 延迟：1 cycle

Stage 2: PE 阵列传播 (Systolic Propagation)
  - 数据沿阵列对角线传播
  - 延迟：32 cycles（32×32 阵列对角线长度）

Stage 3: 累加 (Accumulation)
  - 沿 K 维度累加部分和
  - 延迟：K cycles（可流水）

Stage 4: 输出缓冲 (Output Buffer)
  - 结果收集，格式转换
  - 延迟：1 cycle

总延迟（首次结果）：~34 + K cycles
吞吐量（稳态）：1 结果矩阵 / (M×K) cycles
```

## 6. 寄存器映射

| 寄存器 | 偏移 | 宽度 | 属性 | 描述 |
|--------|------|------|------|------|
| SA_CTRL | 0x00 | 32 | RW | [0]=start, [1]=soft_rst, [3:2]=precision, [4]=dataflow_mode |
| SA_STATUS | 0x04 | 32 | RO | [0]=busy, [1]=done, [2]=stall, [7:4]=fsm_state |
| SA_DIM_CFG | 0x08 | 32 | RW | [5:0]=dim_m, [11:6]=dim_n, [21:12]=dim_k |
| SA_PERF_CNT | 0x0C | 32 | RO | 计算周期计数器（每次 start 清零） |
