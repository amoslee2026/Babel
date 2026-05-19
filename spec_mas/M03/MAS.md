---
module: M03
type: MAS
status: complete
parent: null
module_type: storage
chiplet_features: [D2D, CDC, 3DStacked]
generated: "2026-05-17T15:00:00+08:00"
---

# M03: DRAM Controller

## 1. Overview

M03 DRAM Controller 是 TinyStories NPU 的主存储控制器，负责管理 2 GB 3D Stacked DRAM (Wafer-on-Wafer)，通过 Die-to-Die (D2D) 接口连接外部 DRAM die。该模块实现 LPDDR4X 协议、SECDED ECC 保护、带宽调度和低延迟访问优化，满足 REQ-MEM-001 至 REQ-MEM-005 规定的存储性能要求。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| 3D Stacked DRAM | Wafer-on-Wafer 2 GB DRAM die | REQ-MEM-001 |
| D2D Interface | >= 10 GB/s 双向带宽，<= 100 ns round-trip | REQ-D2D-001, REQ-D2D-004 |
| ECC SECDED | 72,64 编码，单错纠正双错检测 | REQ-MEM-005 |
| Low Latency | <= 100 ns row hit latency | REQ-MEM-003 |
| High Bandwidth | >= 10 GB/s 读+写总带宽 | REQ-MEM-002 |
| Power Efficiency | <= 5 pJ/bit D2D energy | REQ-D2D-003 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 可调 |
| Power Domain | PD_MAIN | 0.7-0.9 V，可 Power Gate |
| Target Power | 80 mW @ OP0 | DRAM Controller + D2D PHY |

### 1.3 Memory Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Total Capacity | 2 GB | 模型权重、KV cache、中间结果 |
| Access Width | 64 bit (data) + 8 bit (ECC) = 72 bit | SECDED protected |
| Address Range | 0x0000_0000 - 0x7FFF_FFFF | 2 GB 连续地址空间 |
| Protocol | LPDDR4X | Die-to-Die 互连协议 |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| clk_sys_i | Input | 1 | CLK_SYS | 主系统时钟，250-500 MHz |
| rst_sys_n_i | Input | 1 | CLK_SYS | 系统异步复位，低有效 |
| clk_d2d_i | Input | 1 | CLK_D2D | D2D PHY 时钟，来源于 DRAM die |

#### 2.1.2 System Bus Interface (TileLink/AXI)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| bus_cmd_valid_i | Input | 1 | CLK_SYS | 总线命令有效 |
| bus_cmd_ready_o | Output | 1 | CLK_SYS | 总线命令就绪 |
| bus_cmd_addr_i | Input | 32 | CLK_SYS | DRAM 地址 (0x0000_0000 - 0x7FFF_FFFF) |
| bus_cmd_rw_i | Input | 1 | CLK_SYS | 读/写命令 (0=Read, 1=Write) |
| bus_cmd_data_i | Input | 72 | CLK_SYS | 写数据 (64-bit data + 8-bit ECC) |
| bus_cmd_mask_i | Input | 8 | CLK_SYS | 写掩码 (byte enable) |
| bus_rsp_valid_o | Output | 1 | CLK_SYS | 读响应有效 |
| bus_rsp_data_o | Output | 72 | CLK_SYS | 读数据 (64-bit data + 8-bit ECC) |
| bus_rsp_error_o | Output | 1 | CLK_SYS | 响应错误标志 |
| bus_rsp_latency_o | Output | 8 | CLK_SYS | 访问延迟 (ns) |

#### 2.1.3 D2D Interface Signals (to DRAM Die)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| d2d_clk_tx_o | Output | 1 | CLK_SYS | D2D 发送时钟 |
| d2d_clk_rx_i | Input | 1 | CLK_D2D | D2D 接收时钟 |
| d2d_cmd_valid_o | Output | 1 | CLK_D2D | D2D 命令有效 |
| d2d_cmd_ready_i | Input | 1 | CLK_D2D | D2D 命令就绪 |
| d2d_cmd_addr_o | Output | 32 | CLK_D2D | DRAM die 地址 |
| d2d_cmd_rw_o | Output | 1 | CLK_D2D | 读/写命令 |
| d2d_cmd_burst_o | Output | 8 | CLK_D2D | Burst 长度 (1-256) |
| d2d_wdata_valid_o | Output | 1 | CLK_D2D | 写数据有效 |
| d2d_wdata_o | Output | 72 | CLK_D2D | 写数据 (64+8 ECC) |
| d2d_wdata_last_o | Output | 1 | CLK_D2D | 写数据最后一个 beat |
| d2d_rdata_valid_i | Input | 1 | CLK_D2D | 读数据有效 |
| d2d_rdata_i | Input | 72 | CLK_D2D | 读数据 (64+8 ECC) |
| d2d_rdata_last_i | Input | 1 | CLK_D2D | 读数据最后一个 beat |
| d2d_rdata_error_i | Input | 1 | CLK_D2D | 读数据 ECC 错误标志 |

#### 2.1.4 D2D PHY Interface (Physical Layer)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| d2d_tx_data_o | Output | 16 | D2D TX 数据 (16 lanes) |
| d2d_tx_clk_o | Output | 1 | D2D TX 时钟 |
| d2d_rx_data_i | Input | 16 | D2D RX 数据 (16 lanes) |
| d2d_rx_clk_i | Input | 1 | D2D RX 时钟 |
| d2d_pll_lock_i | Input | 1 | D2D PLL 锁定状态 |

#### 2.1.5 ECC Status Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| ecc_err_addr_o | Output | 32 | CLK_SYS | ECC 错误地址 |
| ecc_err_type_o | Output | 2 | CLK_SYS | 错误类型 (0=单错纠正, 1=双错检测, 2=多错) |
| ecc_err_valid_o | Output | 1 | CLK_SYS | ECC 错误有效 |
| ecc_err_clear_i | Input | 1 | CLK_SYS | ECC 错误清除 |
| ecc_corrected_o | Output | 1 | CLK_SYS | 单错已纠正标志 |

#### 2.1.6 Bandwidth Arbitration Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| bw_request_i | Input | 16 | CLK_SYS | 各 Master 带宽请求 (M00, M09-M12, M13) |
| bw_grant_o | Output | 16 | CLK_SYS | 各 Master 带宽授权 |
| bw_priority_i | Input | 4 | CLK_SYS | 当前优先级配置 |
| bw_status_o | Output | 8 | CLK_SYS | 带宽使用状态 |

#### 2.1.7 Power Management Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| dram_active_o | Output | 1 | CLK_SYS | DRAM 活动状态 |
| dram_idle_o | Output | 1 | CLK_SYS | DRAM 空闲状态 |
| dram_power_mode_i | Input | 2 | CLK_SYS | DRAM 功耗模式 (Active/Self-Refresh/Deep Power Down) |
| dram_self_refresh_req_i | Input | 1 | CLK_SYS | Self-Refresh 进入请求 |
| dram_self_refresh_ack_o | Output | 1 | CLK_SYS | Self-Refresh 进入确认 |

#### 2.1.8 Status & Interrupt

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| dram_status_o | Output | 8 | CLK_SYS | DRAM Controller 状态 |
| dram_irq_o | Output | 1 | CLK_SYS | DRAM Controller 中断请求 |
| dram_irq_type_o | Output | 4 | CLK_SYS | 中断类型编码 |

### 2.2 Register Map (at 0x800B_0000)

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | DRAM_CTRL | RW | 32 | DRAM Controller 控制寄存器 |
| 0x0004 | DRAM_STATUS | R | 32 | DRAM Controller 状态寄存器 |
| 0x0008 | DRAM_CONFIG | RW | 32 | DRAM 配置寄存器 |
| 0x000C | DRAM_TIMING | RW | 32 | DRAM 时序参数寄存器 |
| 0x0010 | DRAM_BW_CTRL | RW | 32 | 带宽控制寄存器 |
| 0x0014 | DRAM_BW_STATUS | R | 32 | 带宽状态寄存器 |
| 0x0018 | ECC_CTRL | RW | 32 | ECC 控制寄存器 |
| 0x001C | ECC_STATUS | R | 32 | ECC 状态寄存器 |
| 0x0020 | ECC_ERR_ADDR | R | 32 | ECC 错误地址寄存器 |
| 0x0024 | ECC_ERR_TYPE | R | 32 | ECC 错误类型寄存器 |
| 0x0028 | ECC_ERR_COUNT | R | 32 | ECC 错误计数寄存器 |
| 0x002C | DRAM_PWR_CTRL | RW | 32 | DRAM Power 控制寄存器 |
| 0x0030 | DRAM_PWR_STATUS | R | 32 | DRAM Power 状态寄存器 |
| 0x0034 | D2D_CTRL | RW | 32 | D2D 控制寄存器 |
| 0x0038 | D2D_STATUS | R | 32 | D2D 状态寄存器 |
| 0x003C | IRQ_ENABLE | RW | 32 | 中断使能寄存器 |
| 0x0040 | IRQ_STATUS | R | 32 | 中断状态寄存器 |

#### 2.2.1 Register Bit Definitions

**DRAM_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enable | DRAM Controller 使能 |
| [1] | ecc_en | ECC 功能使能 |
| [2] | bw_arb_en | 带宽仲裁使能 |
| [3] | prefetch_en | 预取功能使能 |
| [4] | burst_mode_en | Burst 模式使能 |
| [5:7] | burst_len | Burst 长度配置 (1/2/4/8/16/32) |
| [8] | refresh_en | 自动刷新使能 |
| [9] | power_mode_en | 功耗模式管理使能 |
| [10:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**DRAM_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | DRAM Controller 就绪 |
| [1] | busy | 访问进行中 |
| [2] | error | 错误标志 |
| [3] | d2d_error | D2D 接口错误 |
| [4] | ecc_error | ECC 错误检测 |
| [5] | self_refresh | Self-Refresh 模式 |
| [6] | power_down | Power Down 模式 |
| [7] | initialized | DRAM 初始化完成 |
| [8:15] | current_latency | 当前访问延迟 (ns) |
| [16:23] | current_bw | 当前带宽利用率 (%) |
| [24:31] | reserved | 保留 |

**ECC_CTRL (0x0018)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ecc_en | SECDED ECC 使能 |
| [1] | ecc_correct_en | 单错自动纠正使能 |
| [2] | ecc_report_en | ECC 错误报告使能 |
| [3] | ecc_irq_en | ECC 错误中断使能 |
| [4:7] | reserved | 保留 |
| [8:15] | ecc_threshold | ECC 错误阈值 (触发中断) |
| [16:31] | reserved | 保留 |

**ECC_STATUS (0x001C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ecc_error_valid | ECC 错误有效 |
| [1] | ecc_single_error | 单错检测 |
| [2] | ecc_double_error | 双错检测 |
| [3] | ecc_multi_error | 多错检测 |
| [4] | ecc_corrected | 单错已纠正 |
| [5:7] | reserved | 保留 |
| [8:15] | ecc_error_count | ECC 错误计数 |
| [16:31] | reserved | 保留 |

**D2D_CTRL (0x0034)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | d2d_en | D2D 接口使能 |
| [1] | d2d_training_en | D2D Training 使能 |
| [2] | d2d_pll_bypass | PLL 旁路模式 |
| [3:7] | d2d_lane_mask | Lane 使能掩码 |
| [8:15] | d2d_tx_delay | TX 延迟配置 |
| [16:23] | d2d_rx_delay | RX 延迟配置 |
| [24:31] | reserved | 保留 |

**D2D_STATUS (0x0038)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | d2d_ready | D2D 接口就绪 |
| [1] | d2d_pll_lock | PLL 锁定 |
| [2] | d2d_training_done | Training 完成 |
| [3] | d2d_error | D2D 错误标志 |
| [4:7] | d2d_lane_status | Lane 状态 (bit per lane) |
| [8:15] | d2d_latency | D2D Round-trip Latency (ns) |
| [16:23] | d2d_bandwidth | D2D 当前带宽 (GB/s) |
| [24:31] | reserved | 保留 |

## 3. Functional Description

### 3.1 Memory Protocol (LPDDR4X)

LPDDR4X 协议实现 Die-to-Die DRAM 接口，优化带宽和功耗。

#### 3.1.1 Protocol Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Interface Width | 16 bit (x16) | 双通道 x8/x8 或单通道 x16 |
| Data Rate | LPDDR4X-4267 | 最大数据速率 4267 Mbps |
| Burst Length | BL16/BL32 | 可配置 Burst 长度 |
| Bank Architecture | 8 Banks | Bank 并行访问 |
| Refresh Mode | Auto Refresh / Self-Refresh | 自动或自刷新模式 |

#### 3.1.2 Command Types

| Command | Code | Description |
|---------|------|-------------|
| ACT | Activate | 激活指定 Bank 的 Row |
| READ | Read | 从激活的 Row 读取数据 |
| WRITE | Write | 向激活的 Row 写入数据 |
| PRE | Precharge | 关闭激活的 Bank/Row |
| REF | Refresh | 刷新指定 Bank |
| SREF | Self-Refresh Entry | 进入自刷新模式 |
| PDE | Power Down Entry | 进入 Power Down 模式 |
| MRR | Mode Register Read | 读模式寄存器 |
| MRW | Mode Register Write | 写模式寄存器 |

#### 3.1.3 Access Sequence

```
Read Access Sequence:
  ACT (Activate Row) -> READ (Burst Read) -> PRE (Precharge) or Keep Open
  
Write Access Sequence:
  ACT (Activate Row) -> WRITE (Burst Write) -> PRE (Precharge) or Keep Open
  
Optimization:
  - Row Hit: Row 已激活，直接 READ/WRITE (latency <= 100 ns)
  - Row Miss: 需要 ACT -> READ/WRITE (latency <= 50 ns + ACT latency)
  - Page Open Policy: 保持 Row 激活以减少后续访问延迟
```

### 3.2 ECC Implementation (SECDED 72,64)

SECDED (Single Error Correction, Double Error Detection) ECC 保护 DRAM 数据完整性。

#### 3.2.1 ECC Encoding

| Parameter | Value | Description |
|-----------|-------|-------------|
| Data Width | 64 bit | 原始数据宽度 |
| ECC Width | 8 bit | 校验位宽度 |
| Total Width | 72 bit | 编码后总宽度 |
| Code | Hamming (72,64) | 扩展 Hamming 码 |

#### 3.2.2 ECC Generation

```
ECC Generation (Write Path):
  Input: 64-bit data
  Output: 8-bit ECC + 64-bit data = 72-bit
  
  Algorithm: Extended Hamming Code
    - 8 parity bits covering all 64 data bits
    - Single parity bit for overall error detection
    - Syndrome-based error location
```

#### 3.2.3 ECC Check & Correction (Read Path)

```
ECC Check (Read Path):
  Input: 72-bit (64-bit data + 8-bit ECC)
  Output: 64-bit corrected data + error status
  
  Error Detection:
    - Syndrome = 0: No error
    - Syndrome non-zero, single bit error location: Correctable
    - Syndrome indicates double error: Detectable, not correctable
    - Syndrome indicates multi-bit error: Detectable, not correctable
  
  Correction:
    - Single bit error: XOR correction at syndrome-determined location
    - Double/Multi bit error: Report error, no correction
```

#### 3.2.4 Error Handling

| Error Type | Syndrome | Action | IRQ |
|------------|----------|---------|-----|
| No Error | 0 | 正常返回数据 | None |
| Single Bit Error (Data) | Non-zero, valid location | 自动纠正，返回正确数据 | Optional |
| Single Bit Error (ECC) | Non-zero, ECC location | 无需纠正数据，ECC 重计算 | Optional |
| Double Bit Error | Syndrome pattern | 检测但不可纠正，返回原始数据 | Required |
| Multi Bit Error | Syndrome pattern | 检测但不可纠正，返回原始数据 | Required |

#### 3.2.5 ECC Error Logging

```
ECC Error Logging:
  - ecc_err_addr: 错误发生的 DRAM 地址
  - ecc_err_type: 错误类型 (0=单错纠正, 1=双错检测, 2=多错)
  - ecc_err_count: 累计错误计数
  - ecc_corrected: 单错纠正标志
  
  Interrupt Trigger:
    - ecc_irq_en=1 AND ecc_error_valid=1
    - Threshold trigger: ecc_error_count >= ecc_threshold
```

### 3.3 Bandwidth Management

带宽调度确保满足 >= 10 GB/s 目标带宽，同时公平分配给各 Master。

#### 3.3.1 Bandwidth Allocation

| Master | Priority | Bandwidth Allocation | Use Case |
|--------|----------|---------------------|----------|
| M00 Systolic Array | 0 (Highest) | 8 GB/s | Compute operations |
| M09-M12 Operators | 1 | 4 GB/s | Transformer operators |
| M13 ISA Decoder | 2 | 1 GB/s | Instruction fetch |
| M15 JTAG (Debug) | 3 | 0.5 GB/s | 调试访问 |

#### 3.3.2 Bandwidth Arbitration

```
Bandwidth Arbitration Logic:
  1. Check pending requests from all Masters
  2. Select highest priority request with pending transaction
  3. Grant bandwidth slice based on allocation
  4. Update bandwidth utilization counters
  
  Time Slice Arbitration:
    - Each Master gets configurable time slice
    - High priority Masters get more slices
    - Low priority Masters can use idle bandwidth
```

#### 3.3.3 Bandwidth Monitoring

| Metric | Description | Register |
|--------|-------------|----------|
| Current Bandwidth | 实时带宽利用率 (GB/s) | d2d_status[16:23] |
| Bandwidth Efficiency | 带宽利用率百分比 (%) | dram_status[16:23] |
| Per-Master Usage | 各 Master 带宽使用计数 | Internal counter |
| Peak Bandwidth | 峰值带宽记录 | Internal register |

### 3.4 D2D Interface Controller

D2D Interface Controller 管理 Wafer-on-Wafer Die-to-Die 互连。

#### 3.4.1 D2D Architecture

```
D2D Stack Architecture (Wafer-on-Wafer):
  Top Die:   NPU Logic Die (M03 DRAM Controller)
  Bottom Die: DRAM Die (2 GB LPDDR4X)
  
  Interconnect:
    - 16 data lanes (bidirectional)
    - Separate TX/RX clocks
    - PLL-based clock generation
    - Training sequence for alignment
```

#### 3.4.2 D2D Protocol Stack

| Layer | Function | Description |
|-------|----------|-------------|
| PHY Layer | Physical signaling | 16-lane differential signaling |
| Link Layer | Clock alignment, training | PLL, deskew, lane calibration |
| Transport Layer | Command/data framing | LPDDR4X command encoding |
| Protocol Layer | LPDDR4X protocol | ACT, READ, WRITE, REF commands |

#### 3.4.3 D2D Training Sequence

```
D2D Training Sequence (Initialization):
  1. PLL Lock Wait: d2d_pll_lock_i = 1
  2. Lane Calibration: Deskew each lane
  3. TX/RX Alignment: Match clock and data phases
  4. Link Test: Read/write test pattern
  5. Training Done: d2d_training_done = 1
```

#### 3.4.4 D2D Power Management

| Mode | Description | Power | Latency |
|------|-------------|-------|---------|
| Active | 全速运行 | 80 mW | - |
| Standby | 待机，时钟保持 | 20 mW | < 10 us wake |
| Sleep | 低功耗，时钟关闭 | 5 mW | < 100 us wake |

### 3.5 Power Management

DRAM Controller 支持 DRAM die 的功耗模式管理。

#### 3.5.1 DRAM Power Modes

| Mode | Description | Power | Entry Latency | Exit Latency |
|------|-------------|-------|---------------|--------------|
| Active | 正常运行 | 200 mW | - | - |
| Self-Refresh | 自刷新保持数据 | 50 mW | < 1 us | < 100 us |
| Deep Power Down | 深度功耗模式 | 5 mW | < 10 us | < 10 ms |

#### 3.5.2 Self-Refresh Control

```
Self-Refresh Entry Sequence:
  1. dram_self_refresh_req_i = 1
  2. Wait for all pending transactions complete
  3. Send SREF command to DRAM die
  4. Set dram_self_refresh_ack_o = 1
  5. D2D interface enters Standby mode

Self-Refresh Exit Sequence:
  1. dram_self_refresh_req_i = 0 (or wakeup)
  2. Send exit command to DRAM die
  3. Wait for DRAM die ready
  4. D2D interface returns to Active mode
  5. Set dram_self_refresh_ack_o = 0
```

### 3.6 Low Latency Optimization

优化策略确保 row hit latency <= 100 ns。

#### 3.6.1 Row Buffer Management

| Strategy | Description | Benefit |
|----------|-------------|---------|
| Open Page Policy | 保持 Row 激活以减少 ACT latency | Row hit latency <= 100 ns |
| Row Buffer Tracking | 记录各 Bank 当前激活 Row | 快速判断 row hit/miss |
| Predictive Activation | 预取可能访问的 Row | 减少 row miss 概率 |

#### 3.6.2 Access Scheduling

```
Access Scheduling Optimization:
  1. Group consecutive accesses to same Row/Bank
  2. Reorder requests to maximize row hits
  3. Prioritize urgent requests (high priority Masters)
  4. Batch burst operations to reduce command overhead
  
  Scheduler Parameters:
    - Row hit threshold: 80% hit rate target
    - Miss penalty: 50 ns + ACT latency
    - Reorder window: 8 pending requests
```

## 4. D2D Interface Spec

### 4.1 Physical Interface

| Parameter | Value | Description |
|-----------|-------|-------------|
| Number of Lanes | 16 | 双向数据通道 |
| Lane Width | 1 bit | 单 bit per lane |
| Signaling | Differential | 低功耗差分信号 |
| Data Rate | 4267 Mbps/lane | LPDDR4X 数据速率 |
| Total Bandwidth | >= 10 GB/s | 双向总带宽 |

### 4.2 D2D Timing Parameters

| Parameter | Symbol | Value | Description |
|-----------|--------|-------|-------------|
| Round-trip Latency | t_D2D_RTT | <= 100 ns | 命令发送到数据返回 |
| TX Clock Period | t_D2D_TX_CLK | 0.47 ns (2.13 GHz) | 发送时钟周期 |
| RX Clock Period | t_D2D_RX_CLK | 0.47 ns | 接收时钟周期 |
| Lane Deskew | t_D2D_DESK | < 1 ns | Lane 对齐精度 |
| Training Time | t_D2D_TRAIN | < 100 us | Training 序列时间 |

### 4.3 D2D Energy Efficiency

| Metric | Target | Description |
|--------|--------|-------------|
| Energy per Bit | <= 5 pJ/bit | REQ-D2D-003 |
| Active Power | 80 mW | D2D PHY active |
| Standby Power | 20 mW | Clock maintained |
| Sleep Power | 5 mW | Clock off |

### 4.4 D2D Signal Integrity

| Parameter | Target | Description |
|-----------|--------|-------------|
| Eye Width | >= 0.3 UI | 数据眼图宽度 |
| Eye Height | >= 200 mV | 数据眼图高度 |
| Jitter | < 0.1 UI | 时钟抖动 |
| Skew | < 0.2 UI | Lane skew |

### 4.5 CDC Strategy

M03 处理 CLK_SYS 与 CLK_D2D 的跨时钟域。

#### 4.5.1 CDC Path: CLK_SYS -> CLK_D2D

| Path | Method | Implementation |
|------|--------|----------------|
| Command signals | Async FIFO | FIFO depth = 16 entries |
| Write data | Async FIFO | FIFO depth = 32 entries |

#### 4.5.2 CDC Path: CLK_D2D -> CLK_SYS

| Path | Method | Implementation |
|------|--------|----------------|
| Read data | Async FIFO | FIFO depth = 32 entries |
| Status signals | 2-stage synchronizer | Control signals |

#### 4.5.3 CDC Verification

| Check | Method | Coverage |
|-------|--------|----------|
| FIFO depth | STA + Formal | 无溢出/无空读 |
| Metastability | STA CDC check | 100% cross-domain paths |
| Handshake correctness | Formal verification | Protocol correctness |

## 5. Timing

### 5.1 DRAM Access Timing

| Parameter | Symbol | Value | Description |
|-----------|--------|-------|-------------|
| Row Hit Latency | t_RH | <= 100 ns | REQ-MEM-003 |
| Row Miss Latency | t_RM | <= 150 ns | ACT + READ/WRITE |
| Activate Latency | t_ACT | 50 ns | Row 激活时间 |
| Read Latency | t_RD | 50 ns | 数据读取时间 |
| Write Latency | t_WR | 50 ns | 数据写入时间 |
| Precharge Latency | t_PRE | 20 ns | Bank 关闭时间 |
| Refresh Interval | t_REFI | 7.8 us | 自动刷新间隔 |
| Refresh Time | t_RFC | 350 ns | 刷新执行时间 |

### 5.2 Burst Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Burst Length | 16/32 | 可配置 |
| Burst Interval | 4 clocks | Burst beat 间隔 |
| Burst Efficiency | >= 90% | Burst 带宽利用率 |

### 5.3 D2D Round-trip Timing

| Phase | Duration | Description |
|-------|----------|-------------|
| Command TX | 5 ns | 命令发送时间 |
| DRAM Processing | 50-100 ns | DRAM die 内部处理 |
| Data RX | 5 ns | 数据接收时间 |
| **Total RTT** | **60-110 ns** | **<= 100 ns row hit** |

### 5.4 ECC Timing

| Operation | Latency | Description |
|-----------|---------|-------------|
| ECC Generation (Write) | 2 cycles | ECC 编码延迟 |
| ECC Check (Read) | 2 cycles | Syndrome 计算 |
| ECC Correction | 1 cycle | 单错纠正 |
| Total Write Path | 2 cycles | ECC overhead |
| Total Read Path | 3 cycles | Check + Correction |

### 5.5 Power Mode Timing

| Transition | Duration | Description |
|------------|----------|-------------|
| Active -> Self-Refresh | < 1 us | 进入自刷新 |
| Self-Refresh -> Active | < 100 us | 退出自刷新 |
| Active -> Deep Power Down | < 10 us | 进入深度功耗模式 |
| Deep Power Down -> Active | < 10 ms | 退出深度功耗模式 |

## 6. Verification Requirements

| Check | Method | Coverage Target |
|-------|--------|-----------------|
| LPDDR4X Protocol | Simulation | 100% command sequences |
| ECC SECDED | Simulation | Single/double/multi error cases |
| D2D Bandwidth | Simulation | >= 10 GB/s achieved |
| D2D Latency | Simulation | <= 100 ns row hit |
| CDC Paths | STA + Formal | 100% cross-domain |
| Power Modes | Simulation | All mode transitions |