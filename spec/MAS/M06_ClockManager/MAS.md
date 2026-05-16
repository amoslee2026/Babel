---
module: M06
type: MAS
status: complete
parent: TOP
module_type: io
generated: 2026-05-12T09:20:00Z
---

# M06_ClockManager MAS

## 模块概述

时钟管理器负责为 TinyStories NPU 生成和分配系统时钟。工作在 CLK_AON 32KHz 时钟域和 PD_AON 电源域，生成 CLK_SYS 500MHz 主频和 CLK_AON 32KHz Always-On 时钟。采用三星 SF4 4nm 工艺。

## 接口信号

| 信号名 | 位宽 | 方向 | 协议 | 描述 |
|--------|------|------|------|------|
| clk_ref | 1 | input | - | 参考时钟 32KHz |
| rst_n | 1 | input | - | 异步复位，低有效 |
| clk_sys | 1 | output | - | 系统主时钟 500MHz |
| clk_aon | 1 | output | - | Always-On 时钟 32KHz |
| pll_lock | 1 | output | - | PLL 锁定指示 |
| cfg_addr | 8 | input | APB | 配置地址 |
| cfg_wdata | 32 | input | APB | 配置写数据 |
| cfg_rdata | 32 | output | APB | 配置读数据 |
| cfg_wr | 1 | input | APB | 写使能 |
| cfg_rd | 1 | input | APB | 读使能 |
| clk_gate_en | 1 | input | - | 时钟门控使能 |

## 时序规格

| 参数 | 值 | 单位 | 说明 |
|------|-----|------|------|
| CLK_SYS 频率 | 500 | MHz | 系统主频 |
| CLK_AON 频率 | 32 | KHz | Always-On 时钟 |
| PLL 锁定时间 | 100 | μs | 从复位到锁定 |
| 时钟切换延迟 | 10 | ns | 门控响应时间 |
| 抖动 | <50 | ps | CLK_SYS 抖动 |
| 占空比 | 50±2 | % | 时钟占空比 |

## 功能描述

### PLL 配置
- 输入：32KHz 参考时钟
- 倍频系数：15625 (500MHz / 32KHz)
- 锁相环带宽：1MHz
- 输出：500MHz 系统时钟

### 时钟分频
- CLK_SYS：直接输出 PLL 500MHz
- CLK_AON：直通参考时钟 32KHz

### 时钟门控
- 支持动态门控降低功耗
- 门控延迟：<10ns
- 门控粒度：模块级

## 寄存器列表

### CLK_CTRL (0x00)
| 位域 | 名称 | 访问 | 复位值 | 描述 |
|------|------|------|--------|------|
| [0] | PLL_EN | RW | 0 | PLL 使能 |
| [1] | CLK_GATE_EN | RW | 0 | 时钟门控使能 |
| [7:2] | RESERVED | - | 0 | 保留 |

### PLL_CFG (0x04)
| 位域 | 名称 | 访问 | 复位值 | 描述 |
|------|------|------|--------|------|
| [15:0] | DIV_RATIO | RW | 15625 | PLL 倍频系数 |
| [23:16] | BW_CFG | RW | 0x10 | 环路带宽配置 |
| [31:24] | RESERVED | - | 0 | 保留 |

### CLK_STATUS (0x08)
| 位域 | 名称 | 访问 | 复位值 | 描述 |
|------|------|------|--------|------|
| [0] | PLL_LOCK | RO | 0 | PLL 锁定状态 |
| [1] | CLK_STABLE | RO | 0 | 时钟稳定指示 |
| [7:2] | RESERVED | - | 0 | 保留 |
