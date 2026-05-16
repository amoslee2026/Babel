---
module: M01
type: MAS
status: complete
parent: TOP
module_type: compute
generated: 2026-05-12T09:20:00Z
---

# M01_DataflowController — Module Architecture Specification

## 1. 模块概述

M01_DataflowController 是 TinyStories NPU 的 Dataflow 调度控制器，运行于 CLK_SYS 500 MHz，归属 PD_MAIN 电源域。

职责：
- 向 M00_SystolicArray 发送计算指令，管理 Spatial Dataflow 流水线
- 支持 Transformer 算子原语：Attention、FFN、RMSNorm、RoPE
- 多线程执行（2 线程），pipeline 利用率 >= 80%
- 混合精度调度：FP32 / FP16 / INT8
- 通过 M04_SystemBus（AXI4）访问 M02_SRAM 和 M03_DRAMController

---

## 2. 接口信号表

### 2.1 与 M00_SystolicArray 控制接口

| 信号名              | 方向 | 宽度 | 描述                          |
|---------------------|------|------|-------------------------------|
| m00_op_valid        | OUT  | 1    | 算子指令有效                  |
| m00_op_ready        | IN   | 1    | M00 接受指令握手              |
| m00_op_code[7:0]    | OUT  | 8    | 算子操作码                    |
| m00_op_prec[1:0]    | OUT  | 2    | 精度：00=FP32,01=FP16,10=INT8 |
| m00_op_tid[0]       | OUT  | 1    | 线程 ID                       |
| m00_src_addr[31:0]  | OUT  | 32   | 源操作数基地址                |
| m00_dst_addr[31:0]  | OUT  | 32   | 目标地址                      |
| m00_shape[63:0]     | OUT  | 64   | 张量形状（M/N/K 编码）        |
| m00_done            | IN   | 1    | 计算完成脉冲                  |
| m00_err[1:0]        | IN   | 2    | 错误码                        |

### 2.2 与 M04_SystemBus AXI4 主接口（指令 fetch）

| 信号名              | 方向 | 宽度 | 描述                  |
|---------------------|------|------|-----------------------|
| axi_arvalid         | OUT  | 1    | 读地址有效            |
| axi_arready         | IN   | 1    | 总线就绪              |
| axi_araddr[31:0]    | OUT  | 32   | 指令队列基地址        |
| axi_arlen[7:0]      | OUT  | 8    | Burst 长度            |
| axi_rvalid          | IN   | 1    | 读数据有效            |
| axi_rready          | OUT  | 1    | 接收就绪              |
| axi_rdata[63:0]     | IN   | 64   | 指令数据              |
| axi_rlast           | IN   | 1    | Burst 最后一拍        |
| axi_rresp[1:0]      | IN   | 2    | 响应状态              |

### 2.3 中断信号

| 信号名              | 方向 | 宽度 | 描述                        |
|---------------------|------|------|-----------------------------|
| irq_op_done         | OUT  | 1    | 算子完成中断（电平，软件清） |
| irq_err             | OUT  | 1    | 错误中断                    |
| irq_tid[0]          | OUT  | 1    | 触发中断的线程 ID            |

---

## 3. 算子调度表

| 算子     | op_code | 指令序列                                      | 精度支持          |
|----------|---------|-----------------------------------------------|-------------------|
| Attention| 0x01    | LOAD_Q → LOAD_K → LOAD_V → MATMUL_QK → SOFTMAX → MATMUL_AV → STORE | FP32/FP16 |
| FFN      | 0x02    | LOAD_X → MATMUL_W1 → GELU → MATMUL_W2 → STORE | FP32/FP16/INT8   |
| RMSNorm  | 0x03    | LOAD_X → LOAD_W → RMSN_COMPUTE → STORE       | FP32/FP16         |
| RoPE     | 0x04    | LOAD_X → LOAD_FREQ → ROPE_COMPUTE → STORE    | FP32/FP16         |

---

## 4. 线程管理

- 线程数：2（TID=0, TID=1）
- 调度策略：Round-Robin，每算子边界切换
- 上下文切换开销：<= 4 个 CLK_SYS 周期
- 上下文内容：PC、OP_QUEUE 读指针、当前算子状态、精度配置
- 线程独立寄存器：THREAD_CFG[0/1]、各自 PC 寄存器

---

## 5. 寄存器映射

基地址：由 M04_SystemBus 分配（APB 从接口，偏移相对基地址）

| 偏移   | 名称        | 宽度 | 访问 | 描述                                  |
|--------|-------------|------|------|---------------------------------------|
| 0x000  | CTRL        | 32   | RW   | [0]=全局使能, [1]=软复位, [3:2]=调度模式 |
| 0x004  | STATUS      | 32   | RO   | [0]=IDLE, [1]=BUSY, [3:2]=当前TID, [7:4]=流水线阶段 |
| 0x008  | THREAD_CFG0 | 32   | RW   | 线程0：[1:0]=精度, [7:2]=算子掩码     |
| 0x00C  | THREAD_CFG1 | 32   | RW   | 线程1：同上                           |
| 0x010  | OP_QUEUE    | 32   | RW   | [15:0]=队列基地址高16位, [31:16]=深度 |
| 0x014  | PERF_CNT0   | 32   | RO   | 线程0 完成算子计数                    |
| 0x018  | PERF_CNT1   | 32   | RO   | 线程1 完成算子计数                    |
| 0x01C  | PERF_UTIL   | 32   | RO   | [15:0]=流水线利用率（Q16格式）        |
| 0x020  | IRQ_MASK    | 32   | RW   | 中断使能掩码                          |
| 0x024  | IRQ_STATUS  | 32   | RW1C | 中断状态，写1清                       |
