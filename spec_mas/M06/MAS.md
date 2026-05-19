---
module: M06
type: MAS
status: complete
parent: null
module_type: control
chiplet_features: [CDC]
generated: "2026-05-17T10:00:00+08:00"
---

# M06: Clock Manager

## 1. Overview

Clock Manager (M06) 负责 NPU 全系统时钟生成与分发，位于 Always-On Power Domain (PD_AON)，运行于 1 MHz 低频时钟域 (CLK_AON)。

核心功能：
- PLL 配置与锁定检测
- DVFS 频率切换 (250-500 MHz)
- 时钟门控控制信号生成
- 跨时钟域 (CDC) 接口处理

## 2. Interface

### 2.1 Signal List

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| `ext_clk_i` | Input | 1 | - | 外部晶振 50 MHz 输入 |
| `pll_lock_i` | Input | 1 | CLK_AON | PLL 锁定状态指示 |
| `dvfs_op_i` | Input | 2 | CLK_AON | DVFS 操作点选择 (OP0/OP1/OP2) |
| `dvfs_req_i` | Input | 1 | CLK_AON | DVFS 频率切换请求 |
| `clk_gating_en_i` | Input | 14 | CLK_AON | 各模块时钟门控使能 (M00-M04, M08-M14) |
| `clk_sys_o` | Output | 1 | CLK_SYS | 主系统时钟 (250-500 MHz) |
| `clk_aon_o` | Output | 1 | CLK_AON | Always-on 时钟 (1 MHz) |
| `clk_io_o` | Output | 1 | CLK_IO | IO 时钟 (50 MHz) |
| `clk_gating_o` | Output | 14 | CLK_SYS | 时钟门控控制信号 |
| `dvfs_ack_o` | Output | 1 | CLK_AON | DVFS 切换完成应答 |
| `clk_status_o` | Output | 3 | CLK_AON | 时钟状态 (稳定/切换/错误) |

### 2.2 Power Domain Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `pd_aon_vdd_i` | Input | 1 | PD_AON 供电指示 (0.6-0.9V) |
| `pll_pwr_en_o` | Output | 1 | PLL 电源使能 |

## 3. Functional Description

### 3.1 PLL Configuration

| PLL | Output Frequency | Lock Time | Configuration |
|-----|------------------|-----------|---------------|
| PLL_MAIN | 250-500 MHz | 50 us | 可配置倍频系数 N=5-10 |
| PLL_AON | 1 MHz | 50 us | 固定倍频 N=0.02 |

PLL 参数：
- 输入参考时钟: EXT_CLK 50 MHz
- VCO 范围: 500-1000 MHz
- 分频器: M=1, N=5-10 (DVFS 可调)
- 锁定检测阈值: 相位误差 < 1 ns

### 3.2 DVFS Clock Switching

DVFS 操作点映射：

| OP Code | Frequency | Voltage | Target Clock | Switching Latency |
|---------|-----------|---------|--------------|-------------------|
| OP0 (High) | 500 MHz | 0.9 V | PLL_MAIN | < 100 us |
| OP1 (Low) | 250 MHz | 0.7 V | PLL_MAIN/2 | < 100 us |
| OP2 (Sleep) | 1 MHz | 0.6 V | PLL_AON | < 10 us |

DVFS 切换序列：
1. `dvfs_req_i` 上升沿触发切换
2. 检测当前频率状态
3. 配置 PLL 分频系数
4. 等待 PLL 重新锁定 (50 us)
5. 切换时钟输出源
6. 生成 `dvfs_ack_o` 应答

切换时序约束：
- 频率切换期间保持时钟连续性
- 无毛刺切换 (glitch-free)
- 最大切换延迟: 100 us

### 3.3 Clock Gating

时钟门控控制：

| Module | Gating Signal | Trigger Source | Latency |
|--------|---------------|----------------|---------|
| M00-M04 | `clk_gating_o[0:4]` | Power Manager M05 | < 10 cycles |
| M08-M14 | `clk_gating_o[5:13]` | Power Manager M05 | < 5 cycles |

门控策略：
- Software-controlled gating via `clk_gating_en_i`
- Clock gating cells with integrated latch
- Enable/disable aligned to clock edge
- Status reported via `clk_status_o`

## 4. CDC Strategy

M06 作为跨时钟域核心节点，处理以下 CDC 路径：

### 4.1 CLK_SYS -> CLK_AON

| Path | Method | Implementation |
|------|--------|----------------|
| Status signals | 2-stage synchronizer | `dvfs_ack_o` 经过两级触发器同步 |
| Counter values | 2-stage synchronizer | 频率计数器值传递 |

### 4.2 CLK_AON -> CLK_SYS

| Path | Method | Implementation |
|------|--------|----------------|
| Control signals | Handshake protocol | 请求-应握协议保证数据完整性 |
| DVFS commands | Handshake protocol | 4-phase握手 (req-ack-data-ack) |

### 4.3 CLK_SYS -> CLK_IO

| Path | Method | Implementation |
|------|--------|----------------|
| Data transfer | Async FIFO | FIFO depth = 16 entries |

CDC 验证要求：
- STA CDC check: 100% cross-domain paths
- Formal verification: Handshake protocol correctness
- FIFO depth check: 无溢出/无空读

## 5. Timing

### 5.1 Clock Timing Parameters

| Parameter | Value | Unit |
|-----------|-------|------|
| EXT_CLK period | 20 | ns |
| CLK_SYS period (OP0) | 2 | ns |
| CLK_SYS period (OP1) | 4 | ns |
| CLK_AON period | 1000 | ns |
| CLK_IO period | 20 | ns |
| Clock jitter | < 1% | - |
| Duty cycle | 50% | - |

### 5.2 DVFS Switching Timing

| Phase | Duration | Description |
|-------|----------|-------------|
| PLL reconfigure | 100 us | 倍频系数调整 |
| PLL lock | 50 us | 等待锁定检测 |
| Clock switch | 1 cycle | 无毛刺切换 |
| Ack generation | 1 cycle | 应答信号生成 |

### 5.3 Reset Sequence Integration

M06 在复位序列中的角色：

| Step | Action | M06 Role |
|------|--------|----------|
| 1 | POR asserted | 所有输出复位 |
| 2 | PLL configuration | 接收配置参数 |
| 3 | PLL lock wait | 监测锁定状态 |
| 4 | CLK_AON stable | 输出 1 MHz 时钟 |
| 5 | PD_MAIN power-on | 保持时钟稳定 |
| 6 | CLK_SYS stable | 切换至 PLL_MAIN |
| 7 | SW_RESET de-assert | 正常工作模式 |

## 6. Verification Requirements

| Check | Method | Coverage Target |
|-------|--------|-----------------|
| PLL lock detection | Simulation | 100% lock/unlock cases |
| DVFS switching | Simulation | All OP transitions |
| Clock gating | Simulation | All module combinations |
| CDC paths | STA + Formal | 100% cross-domain |
| Glitch-free switching | Simulation | All frequency transitions |