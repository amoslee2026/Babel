---
title: "时钟与复位设计知识库"
type: reference
purpose: api
audience: llm
direction: input
status: approved
version: "1.0.0"
---

# 时钟与复位设计知识库

芯片时钟复位架构设计的关键决策点和最佳实践。

---

## 时钟源选择

### 时钟源类型

| 类型 | 适用场景 | 特点 | 典型频率 |
|------|----------|------|----------|
| 外部晶振 | 精确频率需求 | 高精度、低抖动 | 1-50 MHz |
| PLL | 内部高频生成 | 可编程、倍频 | 100-1000 MHz |
| RC振荡器 | 低成本应用 | 低精度 | 1-10 MHz |
| 系统时钟分频 | 外设低频 | 简单 | 分频可配 |

### PLL 配置决策

| 参数 | 冺策依据 | 典型值 |
|------|----------|--------|
| 输入频率 | 外部晶振 | 10-50 MHz |
| VCO范围 | 工艺能力 | 500-1500 MHz |
| 输出频率 | 系统需求 | 100-500 MHz |
| 带宽 | 抖动要求 | 窄/中/宽 |
| 锁定时间 | 启动时间 | µs-ms |

---

## 时钟域划分

### 常见时钟域结构

```
典型 SoC 时钟域划分：
├── CLK_SYS (100-500 MHz)   → CPU, Memory, Main Bus
├── CLK_PERI (25-50 MHz)    → UART, SPI, I2C, GPIO
├── CLK_AON (1-10 kHz)      → Power Mgr, AON Timer
├── CLK_USB (48 MHz)        → USB Device
├── CLK_CRYPTO (50-200 MHz) → AES, SHA, RNG
├── CLK_DDR (200-400 MHz)   → DDR Controller (如有)
```

### 时钟域划分原则

| 原则 | 说明 |
|------|------|
| 功能聚合 | 相关模块放同一域，减少 CDC |
| 频率匹配 | 模块频率需求相近的放同一域 |
| 功耗优化 | 可独立关闭的模块分域 |
| 复杂度控制 | 域数不宜过多，通常 ≤10 |

---

## CDC (Clock Domain Crossing)

### CDC 方法选择

| 方法 | 适用场景 | 代价 | 验证方法 |
|------|----------|------|----------|
| 2级同步器 | 单 bit 信号 | 2 cycles latency | Formal |
| Handshake | 多 bit 数据 | 协议开销 | Simulation |
| FIFO | 高吞吐数据流 | 存储开销 | Simulation |
| Mux/Demux | 低频跨域 | 设计复杂 | Formal |

### CDC 设计要点

1. **单 bit 信号**：使用 2 级同步器，确保目标域采样稳定
2. **多 bit 数据**：必须使用握手或 FIFO，禁止直接同步
3. **时钟关系**：异步时钟必须 CDC；同步分频可省 CDC
4. **验证要求**：所有 CDC 必须通过 Formal 验证（工具如 SpyGlass CDC）

### CDC 安全检查清单

| 检查项 | 要求 |
|--------|------|
| CDC 单 bit | 同步器级数 ≥ 2 |
| CDC 多 bit | 必有握手或 FIFO |
| CDC 控制信号 | 必须稳定后再采样 |
| CDC 复位 | 复位释放顺序正确 |

---

## 时钟门控 (Clock Gating)

### 门控策略

| 类型 | 适用场景 | 实现方式 |
|------|----------|----------|
| 软件控制 | 模块级 | 寄存器 + CG cell |
| 自动门控 | 空闲检测 | Idle signal + CG cell |
| 细粒度 | 寄存器级 | 自门控 |

### Clock Gating Cell 选择

| Cell | 用途 | 特点 |
|------|------|------|
| Integrated Clock Gate (ICG) | 标准 | 工艺库提供 |
| Latch-based CG | 低功耗 | 无毛刺 |
| Simple AND gate | 禁用 | 有毛刺风险 |

### 门控覆盖率目标

| 级别 | Coverage Target |
|------|-----------------|
| Module level | ≥ 90% |
| Sub-module level | ≥ 70% |
| Register level | 按功耗预算定 |

---

## 复位策略

### 复位类型

| 类型 | 特点 | 适用场景 |
|------|------|----------|
| 异步复位 | 立即生效，与时钟无关 | POR, External reset |
| 同步复位 | 时钟边沿生效 | WDT, Software reset |
| 异步置位同步释放 | 推荐 | 大多数应用 |

### 复位树结构

```
推荐复位树结构：
                 POR (Async)
                     │
                     ├── RST_GLOBAL
                     │       ├── RST_AON (Always-on)
                     │       └── RST_MAIN
                     │               ├── RST_CPU
                     │               ├── RST_MEM
                     │               └── RST_CRYPTO
                     │               └── RST_PERI
                     │                       ├── RST_UART
                     │                       ├── RST_SPI
                     │                       └── ...
                     │
           WDT_RESET ─────────── RST_MAIN (Sync)
                     │
          SW_RESET ──────────── RST_PERI (Sync)
```

### 复位顺序原则

| 原则 | 说明 |
|------|------|
| Always-on 先释放 | 维持基本功能 |
| PLL 等稳定后再释放 Main | 防止时钟不稳定 |
| 外设晚于核心释放 | 保证系统稳定 |
| 有序释放避免总线冲突 | 避免同时启动 |

### 复位源优先级

| 复位源 | 优先级 | 范围 |
|--------|--------|------|
| POR | 最高 | 全局 |
| External Reset | 高 | 全局 |
| WDT Reset | 中 | Main domain |
| SW Reset | 低 | 指定模块 |

---

## 低功耗时钟策略

### 低功耗模式时钟配置

| 模式 | 时钟状态 | 功耗节省 |
|------|----------|----------|
| Active | 全开 | 0% |
| Sleep | 主域关闭，外设可选 | 50-80% |
| Deep Sleep | 仅 AON 时钟 | 90-95% |
| Hibernate | 仅极低频 AON | 95-99% |

### PLL 低功耗策略

| 策略 | 实现 | 代价 |
|------|------|------|
| PLL Bypass | 使用外部低频 | 频率受限 |
| PLL Shutdown | Deep Sleep 时关闭 | 重锁时间 |
| PLL Low Power Mode | 降低带宽 | 抖动增加 |

---

## 参考设计案例

### OpenTitan Earl Grey

| 域 | 频率 | 模块 |
|----|------|------|
| sys | 100 MHz | CPU, Memory, Crypto |
| io | 24 MHz | Peripherals |
| usb | 48 MHz | USB |
| aon | 200 kHz | Power Mgr, Timer |

### Chipyard Rocket Chip

| 埧 | 频率 | 模块 |
|----|------|------|
| core | 可变 | Rocket Core |
| bus | 可变 | TileLink |
| periph | 低频 | Peripherals |

---

## 常见错误与陷阱

| 陷阱 | 说明 | 正确做法 |
|------|------|----------|
| 直接同步多 bit | 数据 skew 导致错误 | 使用握手或 FIFO |
| 复位与时钟竞争 | 复位释放与时钟不稳定 | PLL 稳定后释放 |
| CG cell 毛刺 | AND gate 导致时钟 glitch | 使用 ICG |
| CDC 缺验证 | 未做 formal 验证 | 必须做 CDC check |
| 时钟门控不足 | 功耗超标 | 增加门控覆盖率 |

---

## 设计验证要点

| 验证项 | 方法 | Tool |
|--------|------|------|
| CDC 正确性 | Formal | SpyGlass CDC, Jasper |
| 时钟树平衡 | Static timing | PrimeTime |
| 复位覆盖 | RTL review | Checklist |
| 门控功能 | Simulation | Waveform |
| PLL 稳定性 | Mixed-signal | Verilog-AMS |