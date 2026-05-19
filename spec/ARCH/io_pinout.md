# IO & Pinout

## Pin Categories

| Category | Pins | Voltage | REQ |
|----------|------|---------|-----|
| Power | VDD, VSS | 0.9V, 1.8V | - |
| Reset | POR_N | 1.8V | - |
| JTAG | 5 pins | 1.8V | REQ-IO-001 |
| ISA Interface | 8+ pins | 1.8V | REQ-IO-002 |
| Security | 2 pins | 1.8V | REQ-SEC-001 |

## Pin List

| Pin # | Name | Type | Direction | Voltage | Function | REQ |
|-------|------|------|-----------|---------|----------|-----|
| 0 | VDD_MAIN | Power | - | 0.7-0.9V | 主电源（DVFS） | REQ-PWR-003 |
| 1 | VDD_AON | Power | - | 0.6-0.9V | Always-on 电源 | - |
| 2 | VDD_IO | Power | - | 1.8V | IO 电源 | - |
| 3 | VSS | Ground | - | 0V | 地 | - |
| 4 | POR_N | Reset | Input | 1.8V | 全局复位（异步） | - |
| 5-9 | JTAG_TCK/TMS/TDI/TDO/TRST | JTAG | I/O | 1.8V | IEEE 1149.1 调试接口 | REQ-IO-001 |
| 10-17 | ISA_IF[7:0] | ISA | Bidir | 1.8V | NPU 指令接口（数据/地址） | REQ-IO-002 |
| 18 | ISA_CLK | ISA | Input | 1.8V | ISA 接口时钟 | REQ-IO-002 |
| 19 | ISA_VALID | ISA | Output | 1.8V | ISA 数据有效 | REQ-IO-002 |
| 20 | SEC_BOOT_EN | Security | Input | 1.8V | Secure Boot 启用 | REQ-SEC-001 |
| 21 | SEC_STATUS | Security | Output | 1.8V | 安全状态指示 | REQ-SEC-001 |
| 22 | EXT_CLK | Clock | Input | 1.8V | 外部晶振 50 MHz | - |
| 23 | WAKEUP | Control | Input | 1.8V | 低功耗唤醒信号 | REQ-PWR-002 |

## JTAG Interface (IEEE 1149.1)

| Pin | Name | Description | JTAG Function |
|-----|------|-------------|---------------|
| 5 | TCK | Test Clock | 同步 JTAG 操作 |
| 6 | TMS | Test Mode Select | 状态机控制 |
| 7 | TDI | Test Data In | 数据输入 |
| 8 | TDO | Test Data Out | 数据输出 |
| 9 | TRST | Test Reset (optional) | JTAG 复位 |

**JTAG TAP Controller**：
- 支持标准 IR/DR 寄存器
- Debug mode 支持
- Scan chain 访问

## ISA Interface (Custom NPU Instruction Set)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| ISA_IF[7:0] | 8 | Bidir | 指令数据/地址复用 |
| ISA_CLK | 1 | Input | 接口时钟（50 MHz） |
| ISA_VALID | 1 | Output | 数据有效标志 |

**ISA Protocol**：
- 见 doc/isa/ 详细定义 REQ-SW-001
- 支持自定义 NPU 指令集
- 参考 llama2.c 接口风格 REQ-SW-002

## Security Pins

| Pin | Name | Function | Secure Boot Role |
|-----|------|----------|------------------|
| 20 | SEC_BOOT_EN | Secure Boot 启用 | 固件签名验证启用 |
| 21 | SEC_STATUS | 安全状态输出 | 0=验证通过，1=失败 |

**Secure Boot Flow**：
1. SEC_BOOT_EN=1 → 启动签名验证
2. M14 验证固件哈希
3. SEC_STATUS 输出验证结果
4. 验证失败 → 进入安全锁定状态

## Package Constraints

| Parameter | Value | REQ |
|-----------|-------|-----|
| Total Pins | 24 | - |
| Package Area | <= 150 mm² | REQ-PKG-002 |
| Package Type | BGA 或 PoP | REQ-PKG-001 |
| Max Warpage | <= 50 um | REQ-PKG-003 |
