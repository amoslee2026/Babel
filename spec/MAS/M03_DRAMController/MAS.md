---
module: M03
type: MAS
status: complete
parent: TOP
module_type: storage
chiplet_features: [D2D]
generated: 2026-05-12T09:20:00Z
---

# M03_DRAMController — Module Architecture Specification

## 1. 模块概述

M03_DRAMController 是 TinyStories NPU 的 3D Stacked DRAM 控制器，负责管理 2 GB LPDDR4X 存储器的访问调度、刷新控制、ECC 保护及 D2D（TSV）接口桥接。

| 属性 | 值 |
|------|----|
| 容量 | 2 GB |
| 工艺 | 三星 SF4 4nm |
| 时钟域 | CLK_SYS 500 MHz |
| 电源域 | PD_MAIN |
| 接口 | 内部 AXI4 + D2D DRAM 接口 |
| 读带宽 | >= 10 GB/s（读+写合计） |
| 读延迟 | <= 100 ns（row hit） |
| ECC | SECDED（单比特纠错，双比特检错） |
| D2D 能效 | <= 5 pJ/bit |
| D2D 延迟 | <= 100 ns round-trip |

---

## 2. 接口信号表

### 2.1 内部 AXI4 从接口（来自 M04_SystemBus）

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| axi_aclk | in | 1 | AXI 时钟，同 CLK_SYS |
| axi_aresetn | in | 1 | AXI 复位，低有效 |
| axi_awid | in | 4 | 写地址 ID |
| axi_awaddr | in | 32 | 写地址 |
| axi_awlen | in | 8 | 突发长度 |
| axi_awsize | in | 3 | 突发大小 |
| axi_awburst | in | 2 | 突发类型（INCR） |
| axi_awvalid | in | 1 | 写地址有效 |
| axi_awready | out | 1 | 写地址就绪 |
| axi_wdata | in | 128 | 写数据 |
| axi_wstrb | in | 16 | 写字节使能 |
| axi_wlast | in | 1 | 突发最后一拍 |
| axi_wvalid | in | 1 | 写数据有效 |
| axi_wready | out | 1 | 写数据就绪 |
| axi_bid | out | 4 | 写响应 ID |
| axi_bresp | out | 2 | 写响应码 |
| axi_bvalid | out | 1 | 写响应有效 |
| axi_bready | in | 1 | 写响应就绪 |
| axi_arid | in | 4 | 读地址 ID |
| axi_araddr | in | 32 | 读地址 |
| axi_arlen | in | 8 | 突发长度 |
| axi_arsize | in | 3 | 突发大小 |
| axi_arburst | in | 2 | 突发类型（INCR） |
| axi_arvalid | in | 1 | 读地址有效 |
| axi_arready | out | 1 | 读地址就绪 |
| axi_rid | out | 4 | 读数据 ID |
| axi_rdata | out | 128 | 读数据 |
| axi_rresp | out | 2 | 读响应码 |
| axi_rlast | out | 1 | 突发最后一拍 |
| axi_rvalid | out | 1 | 读数据有效 |
| axi_rready | in | 1 | 读数据就绪 |

### 2.2 D2D DRAM 物理接口（至 3D Stacked DRAM Die）

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| d2d_clk_p/n | out | 1 | D2D 差分时钟 |
| d2d_cmd | out | 6 | 命令总线（CS/RAS/CAS/WE/CKE/ODT） |
| d2d_addr | out | 17 | 行/列地址复用 |
| d2d_ba | out | 2 | Bank 地址 |
| d2d_bg | out | 2 | Bank Group 地址 |
| d2d_dq | inout | 32 | 数据总线（含 ECC 8b） |
| d2d_dqs_p/n | inout | 4 | 数据选通差分对 |
| d2d_dm_dbi | out | 4 | 数据掩码/DBI |
| d2d_ca_parity | out | 1 | 命令/地址奇偶校验 |
| d2d_alert_n | in | 1 | DRAM 告警（低有效） |

---

## 3. D2D 接口规范

### 3.1 协议

采用 LPDDR4X 兼容片上接口，双倍数据速率，数据速率 4266 Mbps/pin。

| 参数 | 值 |
|------|----|
| 数据速率 | 4266 Mbps/pin |
| 数据总线宽度 | 32 bit（含 8 bit ECC） |
| 有效数据宽度 | 24 bit（去除 ECC overhead 后等效） |
| 峰值带宽 | 32b × 4266M / 8 = 17.06 GB/s |
| 能效目标 | <= 5 pJ/bit |
| Round-trip 延迟 | <= 100 ns |

### 3.2 时序参数

| 参数 | 符号 | 值 |
|------|------|----|
| tRCD | 行到列延迟 | 18 ns |
| tCL | CAS 延迟 | 18 ns |
| tRP | 预充电时间 | 18 ns |
| tRAS | 行激活时间 | 42 ns |
| tRC | 行周期 | 60 ns |
| tREFI | 刷新间隔 | 3.9 us |
| tRFC | 刷新恢复时间 | 280 ns |

---

## 4. 带宽计算

```
数据总线宽度（有效）= 32 bit
数据速率            = 4266 Mbps/pin × 32 pin = 136.5 Gb/s
有效带宽（去ECC）   = 136.5 × (32/40) ≈ 10.9 GB/s  ✓ >= 10 GB/s
Row-hit 读延迟      = tCL + BL/2 × tCK = 18 + 4 × 0.47 ≈ 20 ns  ✓ <= 100 ns
```

---

## 5. ECC 方案

采用 SECDED（Single Error Correct, Double Error Detect）Hamming 码：

| 参数 | 值 |
|------|----|
| 数据位宽 | 32 bit |
| 校验位宽 | 7 bit（+ 1 overall parity = 8 bit） |
| 编码延迟 | 1 CLK_SYS cycle |
| 解码延迟 | 2 CLK_SYS cycles |
| 单比特错误 | 自动纠正，记录至 ECC_STATUS |
| 双比特错误 | 检测并上报中断，不纠正 |

---

## 6. 寄存器映射

基地址：`0xC000_0000`（APB 配置接口）

| 偏移 | 名称 | 宽度 | 复位值 | 描述 |
|------|------|------|--------|------|
| 0x00 | DRAM_CTRL | 32 | 0x0000_0001 | 控制寄存器 |
| 0x04 | TIMING_CFG | 32 | 0x2412_1218 | 时序参数配置 |
| 0x08 | ECC_STATUS | 32 | 0x0000_0000 | ECC 状态（RO） |
| 0x0C | PERF_CNT | 32 | 0x0000_0000 | 性能计数器 |

### DRAM_CTRL [0x00]

| 位 | 名称 | 描述 |
|----|------|------|
| [0] | EN | 控制器使能 |
| [1] | SELF_REFRESH | 进入自刷新模式 |
| [2] | ECC_EN | ECC 使能 |
| [3] | ECC_IRQ_EN | ECC 双比特错误中断使能 |
| [7:4] | BURST_LEN | 突发长度配置（默认 BL8） |
| [31:8] | RSVD | 保留 |

### TIMING_CFG [0x04]

| 位 | 名称 | 描述 |
|----|------|------|
| [7:0] | tRCD | 行到列延迟（单位 CLK_SYS） |
| [15:8] | tCL | CAS 延迟 |
| [23:16] | tRP | 预充电时间 |
| [31:24] | tRAS | 行激活时间 |

### ECC_STATUS [0x08]

| 位 | 名称 | 描述 |
|----|------|------|
| [0] | SBE | 单比特错误标志（W1C） |
| [1] | DBE | 双比特错误标志（W1C） |
| [15:2] | RSVD | 保留 |
| [31:16] | ERR_ADDR | 最近错误地址高 16 位 |

### PERF_CNT [0x0C]

| 位 | 名称 | 描述 |
|----|------|------|
| [15:0] | RD_CNT | 读事务计数（饱和） |
| [31:16] | WR_CNT | 写事务计数（饱和） |
