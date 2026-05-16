---
module: M04
type: MAS
status: complete
parent: TOP
module_type: interconnect
generated: 2026-05-12T09:20:00Z
---

# M04_SystemBus - Micro-Architecture Specification

## 模块概述

M04_SystemBus 是 TinyStories NPU 的核心互连模块，运行在 CLK_SYS 500MHz，PD_MAIN 电源域。采用 AXI4-Lite 简化协议，通过 crossbar 架构连接4个 master 和2个 slave，支持 Round-Robin 仲裁，带宽 >= 10 GB/s。

## 接口信号

### Master 端口

| Port | Signal | Width | Direction | Description |
|------|--------|-------|-----------|-------------|
| M00 | m00_awaddr | 32 | IN | Systolic Array 写地址 |
| M00 | m00_awvalid | 1 | IN | 写地址有效 |
| M00 | m00_awready | 1 | OUT | 写地址就绪 |
| M00 | m00_wdata | 256 | IN | 写数据 |
| M00 | m00_wvalid | 1 | IN | 写数据有效 |
| M00 | m00_wready | 1 | OUT | 写数据就绪 |
| M00 | m00_araddr | 32 | IN | 读地址 |
| M00 | m00_arvalid | 1 | IN | 读地址有效 |
| M00 | m00_arready | 1 | OUT | 读地址就绪 |
| M00 | m00_rdata | 256 | OUT | 读数据 |
| M00 | m00_rvalid | 1 | OUT | 读数据有效 |
| M00 | m00_rready | 1 | IN | 读数据就绪 |
| M01 | m01_* | - | - | Dataflow Controller (同上) |
| M02 | m02_* | - | - | SRAM (同上) |
| M03 | m03_* | - | - | DRAM Controller (同上) |

### Slave 端口

| Port | Signal | Width | Direction | Description |
|------|--------|-------|-----------|-------------|
| S0 | s0_awaddr | 32 | OUT | SRAM 写地址 |
| S0 | s0_awvalid | 1 | OUT | 写地址有效 |
| S0 | s0_awready | 1 | IN | 写地址就绪 |
| S0 | s0_wdata | 256 | OUT | 写数据 |
| S0 | s0_wvalid | 1 | OUT | 写数据有效 |
| S0 | s0_wready | 1 | IN | 写数据就绪 |
| S0 | s0_araddr | 32 | OUT | 读地址 |
| S0 | s0_arvalid | 1 | OUT | 读地址有效 |
| S0 | s0_arready | 1 | IN | 读地址就绪 |
| S0 | s0_rdata | 256 | IN | 读数据 |
| S0 | s0_rvalid | 1 | IN | 读数据有效 |
| S0 | s0_rready | 1 | OUT | 读数据就绪 |
| S1 | s1_* | - | - | DRAM (同上) |

## 仲裁策略

### Round-Robin 仲裁器

- 4个 master 轮询优先级：M00 → M01 → M02 → M03 → M00
- 每个 master 最大占用时间：16 cycles
- 空闲时立即响应最高优先级请求
- 支持优先级覆盖（通过 ARB_CFG 寄存器）

### 带宽分配

| Master | 带宽占比 | 峰值带宽 |
|--------|---------|---------|
| M00 (Systolic) | 40% | 4 GB/s |
| M01 (Dataflow) | 20% | 2 GB/s |
| M02 (SRAM) | 30% | 3 GB/s |
| M03 (DRAM) | 10% | 1 GB/s |

总带宽：256-bit @ 500MHz = 16 GB/s (理论)，实际有效带宽 >= 10 GB/s。

## 寄存器映射

| Offset | Name | Access | Reset | Description |
|--------|------|--------|-------|-------------|
| 0x00 | BUS_CTRL | RW | 0x0001 | [0] bus_enable, [1] arb_mode (0=RR, 1=priority) |
| 0x04 | ARB_CFG | RW | 0x3210 | [3:0] M00_pri, [7:4] M01_pri, [11:8] M02_pri, [15:12] M03_pri |
| 0x08 | BUS_STATUS | RO | 0x0000 | [3:0] current_master, [4] bus_busy, [5] deadlock_detect |
| 0x0C | BW_COUNTER_M00 | RO | 0x0000 | M00 带宽计数器 (bytes/ms) |
| 0x10 | BW_COUNTER_M01 | RO | 0x0000 | M01 带宽计数器 |
| 0x14 | BW_COUNTER_M02 | RO | 0x0000 | M02 带宽计数器 |
| 0x18 | BW_COUNTER_M03 | RO | 0x0000 | M03 带宽计数器 |

## 关键参数

| Parameter | Value | Unit |
|-----------|-------|------|
| CLK_FREQ | 500 | MHz |
| DATA_WIDTH | 256 | bit |
| ADDR_WIDTH | 32 | bit |
| NUM_MASTERS | 4 | - |
| NUM_SLAVES | 2 | - |
| MAX_BURST_LEN | 16 | cycles |
| FIFO_DEPTH | 8 | entries |

## 工艺约束

- 工艺：Samsung SF4 4nm
- 电源域：PD_MAIN (0.75V)
- 时钟域：CLK_SYS (500MHz)
- 面积预算：< 0.5 mm²
- 功耗预算：< 50 mW @ 典型负载
