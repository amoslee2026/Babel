---
title: "工作流示例"
type: reference
purpose: api
audience: llm
direction: input
status: approved
version: "1.0.0"
---

# 工作流示例

典型芯片架构设计场景的工作流程参考。

---

## 示例 1：RISC-V 微控制器架构设计

### 输入

```
idea/
├── design_goal.md     # "设计一个低功耗 RISC-V 微控制器，用于 IoT 应用"
├── features.md        # 功能需求列表
└── block_diagram.drawio # 初步框图草图
```

### 执行流程

**Phase 1 澄清**：
- 目标应用：IoT 传感器节点
- 性能要求：CoreMark ≥ 2.0/MHz，功耗 < 10mW Active
- 技术节点：40nm CMOS 或 FPGA 验证
- 外设需求：UART, SPI, I2C, GPIO
- 安全需求：Basic（可选 Secure Boot）

**Phase 2 调研**：
- 参考：OpenTitan Earl Grey, Chipyard Rocket Chip
- Clock strategy：3 domains (sys, peri, aon)
- Power strategy：2 domains (main, aon)

**Phase 4 时钟设计**：
- CLK_SYS: 50 MHz (CPU, Memory)
- CLK_PERI: 25 MHz (UART, SPI, I2C)
- CLK_AON: 200 kHz (Power Mgr)

**Phase 5 电源设计**：
- PD_AON: Power/Clock/Reset Manager
- PD_MAIN: CPU, SRAM, Peripherals
- Low power: Sleep/Deep Sleep

**输出结构**：
```
spec_arch/
├── chip_overview.md
├── block_diagram.md
├── clock_reset_spec.md
├── memory_map.md
├── power_spec.md
├── io_pinout.md
├── dft_spec.md
├── verification_plan.md
├── ip_blocks/
│   ├── cpu_core.md        # Ibex/RV32IMC
│   ├── sram_ctrl.md
│   ├── uart.md
│   ├── spi_host.md
│   ├── i2c.md
│   └── gpio.md
└── design_notes.md
```

---

## 示例 2：AES 加密模块设计 (scope=block)

### 输入

```
idea/
├── aes_spec.md  # "设计 AES-128/256 加密模块，支持 ECB/CBC/CTR"
```

### 执行流程

**Phase 1 澄清**：
- Key size：128/256 bit
- Modes：ECB, CBC, CTR
- Performance：12-14 cycles/block
- Security：1st-order masking optional

**Phase 2 调研**：
- 参考：OpenTitan AES IP
- Architecture：Iterative cipher core
- S-Box：DOM masking or Canright

**Phase 4 接口设计**：
- Bus：TL-UL 32-bit
- Data：128-bit input/output
- Control：Shadow registers for security

**输出结构**：
```
spec_arch/
├── block_overview.md
├── theory_of_operation.md
├── block_diagram.md
├── interface_spec.md
├── register_map.md
├── design_details.md
│   ├── datapath architecture
│   ├── S-Box selection
│   ├── key expansion
│   ├── state machine
├── programmer_guide.md
└── verification_checklist.md
```

---

## 示例 3：低功耗 BLE SoC 架构

### 输入

```
idea/
├── ble_soc_requirements.md
├── power_budget.xlsx
└── preliminary_blocks.drawio
```

### 关键设计点

**时钟架构**：
- CLK_RF: 2.4 GHz (BLE Radio)
- CLK_SYS: 32 MHz (CPU)
- CLK_PERI: 16 MHz (Peripheral)
- CLK_AON: 32 kHz (RTC, Power Mgr)

**电源架构**：
- PD_RF: Radio + RF Logic
- PD_SYS: CPU + Memory
- PD_AON: Always-on logic
- Ultra-low power: < 5µA standby

**低功耗策略**：
- Clock gating: All domains
- Power gating: PD_SYS, PD_RF
- Retention: SRAM retention mode
- Wakeup: GPIO, Timer, Radio event

---

## 示例 4：安全 Root of Trust 芯片

### 特殊设计点

**安全架构**：
- Secure Boot: ROM + Signature verification
- Crypto: AES, SHA-256, HMAC, RNG
- Key Manager: DICE-compliant key derivation
- Lifecycle: Test → Dev → Prod states
- Physical: Glitch detection, Tamper response

**DFT 策略**：
- Test mode isolation
- Secure test access only in Test state
- Production DFT disabled

---

## Finetune 模式使用

当 `--finetune=true` 时启用详细输出：

### 输出位置

```
spec_arch/.finetune/
├── phase1_clarification_log.md
├── phase2_agent_transcripts/
│   ├── agent_1_chip_search.md
│   └── agent_2_docs_lookup.md
├── phase4_clock_analysis.md
├── phase5_power_estimate.md
└── decision_trace/
    ├── clock_domain_decision.md
    ├── power_domain_decision.md
    └── sbox_selection_decision.md
```

### 用途

- 分析各 Phase 执行时间
- 收集 Agent transcripts 作为训练数据
- 调试设计流程问题
- 优化决策逻辑