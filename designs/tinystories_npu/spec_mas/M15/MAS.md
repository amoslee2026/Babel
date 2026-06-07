---
module: M15
type: MAS
status: complete
parent: null
module_type: io
generated: "2026-05-17T15:10:00+08:00"
---

# M15: JTAG Interface

## 1. Overview

M15 JTAG Interface 是 TinyStories NPU 的调试与测试访问接口模块，位于 IO Power Domain (PD_IO)，负责实现 IEEE 1149.1 标准 JTAG TAP Controller、Scan Chain 访问控制、TEST_MODE 安全门控等功能。该模块提供外部调试器与内部模块的标准化访问通道，支持边界扫描、内建自测试访问、调试模式切换等功能。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| IEEE 1149.1 TAP | 标准 JTAG Test Access Port 控制器 | REQ-IO-001 |
| TEST_MODE Security Gate | TEST_MODE 信号门控，防止非授权测试访问 | REQ-SEC-001 |
| Scan Chain Access | 4 条 Scan Chain 的访问与选择 | REQ-DFT-001 |
| Debug Access | 32-bit Debug Data Register 用于调试访问 | REQ-DFT-002 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_IO | 50 MHz，IO 时钟 |
| Power Domain | PD_IO | 1.8 V，IO 电源域 |
| Target Power | 15 mW | JTAG TAP + IO Buffers 功耗 |

### 1.3 JTAG Pin Assignment

| Pin # | Name | Type | Direction | Voltage | Function |
|-------|------|------|-----------|---------|----------|
| 5 | TCK | JTAG | Input | 1.8V | Test Clock，同步 JTAG 操作 |
| 6 | TMS | JTAG | Input | 1.8V | Test Mode Select，状态机控制 |
| 7 | TDI | JTAG | Input | 1.8V | Test Data In，数据输入 |
| 8 | TDO | JTAG | Output | 1.8V | Test Data Out，数据输出 |
| 9 | TRST | JTAG | Input | 1.8V | Test Reset (optional)，JTAG 复位 |

## 2. Interface

### 2.1 JTAG Port Interface

#### 2.1.1 JTAG Standard Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tck | Input | 1 | JTAG Test Clock，最高 50 MHz |
| tms | Input | 1 | JTAG Test Mode Select |
| tdi | Input | 1 | JTAG Test Data In |
| tdo | Output | 1 | JTAG Test Data Out |
| trst_n | Input | 1 | JTAG Test Reset (optional)，低有效 |

#### 2.1.2 TDO Output Control

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tdo_en | Output | 1 | TDO 输出使能（用于多芯片串联） |
| tdo_data | Internal | 1 | TDO 数据输出选择（从 DR/IR 选择） |

### 2.2 TEST_MODE Security Interface

#### 2.2.1 TEST_MODE Control

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| test_mode_en | Input | 1 | TEST_MODE 使能，来自 M14 Security Manager |
| test_mode_valid | Input | 1 | TEST_MODE 验证通过标志 |
| test_access_grant | Output | 1 | 测试访问授权标志 |
| test_access_denied | Output | 1 | 测试访问拒绝标志（触发安全告警） |

#### 2.2.2 TEST_MODE Gating Logic

| Condition | Result |
|-----------|--------|
| test_mode_en=1 AND test_mode_valid=1 | 允许 Scan Chain / Debug 访问 |
| test_mode_en=0 | 仅允许 BYPASS / IDCODE 指令 |
| test_mode_valid=0 | 所有敏感指令被拒绝，返回 BYPASS |

### 2.3 Scan Chain Interface

#### 2.3.1 Scan Chain Control

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_select | Output | 4 | Scan Chain 选择 (SC0-SC3) |
| scan_enable | Output | 1 | Scan Chain 使能 |
| scan_in | Output | 1 | Scan Chain 数据输入 |
| scan_out | Input | 1 | Scan Chain 数据输出 |
| scan_capture | Output | 1 | Scan Chain Capture 控制 |
| scan_update | Output | 1 | Scan Chain Update 控制 |

#### 2.3.2 Scan Chain Definition

| Chain ID | Name | Length | Target Modules |
|----------|------|--------|----------------|
| SC0 | Logic Chain 0 | ~10k cells | M00, M01, M08, M09 |
| SC1 | Logic Chain 1 | ~10k cells | M02, M10, M11 |
| SC2 | Logic Chain 2 | ~10k cells | M03, M04, M12 |
| SC3 | Logic Chain 3 | ~10k cells | M05, M06, M07, M13 |

### 2.4 Debug Interface

#### 2.4.1 Debug Register Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| debug_addr | Output | 16 | Debug 访问地址 |
| debug_data_in | Output | 32 | Debug 写数据 |
| debug_data_out | Input | 32 | Debug 读数据 |
| debug_rw | Output | 1 | Debug 读/写控制 |
| debug_valid | Output | 1 | Debug 访问有效 |
| debug_ack | Input | 1 | Debug 访问确认 |

#### 2.4.2 Debug Target Modules

| Module | Debug Access | Description |
|--------|--------------|-------------|
| M00 (Systolic Array) | Yes | 状态寄存器、输出缓冲 |
| M01 (Dataflow Controller) | Yes | FSM 状态、指令计数 |
| M02 (SRAM Controller) | Yes | 存储器状态、错误计数 |
| M03 (DRAM Controller) | Yes | DRAM 状态、地址计数 |
| M04 (System Bus) | Yes | 总线状态、传输计数 |
| M05-M07 (Power/Clock/Reset) | Yes | 状态寄存器 |
| M08-M12 (Operators) | Yes | 运算状态、中间结果 |
| M13 (ISA Interface) | Yes | ISA 状态、接口计数 |
| M14 (Security Manager) | Limited | 仅安全状态（非敏感数据） |

### 2.5 Boundary Scan Interface

#### 2.5.1 Boundary Scan Register

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| bsr_select | Output | 1 | Boundary Scan Register 选择 |
| bsr_capture | Output | 1 | BSR Capture 控制 |
| bsr_update | Output | 1 | BSR Update 控制 |
| bsr_data | Bidir | 24 | Boundary Scan 数据（对应 24 pins） |

#### 2.5.2 Boundary Scan Cell Assignment

| Cell # | Pin | Type | Description |
|--------|-----|------|-------------|
| 0-3 | VDD/VSS | Power | 不包含边界扫描 |
| 4 | POR_N | Input | Input cell only |
| 5-9 | JTAG pins | JTAG | 不包含边界扫描 |
| 10-19 | ISA pins | Bidir | Bidirectional cells |
| 20-21 | SEC pins | Input/Output | Input + Output cells |
| 22 | EXT_CLK | Input | Input cell |
| 23 | WAKEUP | Input | Input cell |

## 3. Functional Description

### 3.1 TAP Controller FSM

TAP Controller 是 IEEE 1149.1 标准的核心，管理 JTAG 状态机。

#### 3.1.1 State Diagram

```
                    +-------------+
                    | Test-Logic- |
                    |   Reset     |
                    +------+------+
                           |
       (TMS=0)             | (TMS=1)
           v               v
    +-------------+   +-------------+
    | Run-Test/   |   | Capture-DR  |
    |   Idle      |   +------+------+
    +------+------+          |
           |                 | (TMS=0)
    (TMS=1)|                 v
           v          +-------------+
    +-------------+   | Shift-DR    |
    | Select-DR   |   +------+------+
    +------+------          |
           |                 | (TMS=1)
    (TMS=0)|                 v
           v          +-------------+
    +-------------+   | Exit1-DR    |
    | Capture-DR  |   +------+------+
    +------+------          |
           |                 | (TMS=0)
    (TMS=1)|                 v
           v          +-------------+
    +-------------+   | Pause-DR    |
    | Shift-DR    |   +------+------+
    +------+------          |
           |                 | (TMS=1)
    (TMS=0)|                 v
           v          +-------------+
    +-------------+   | Exit2-DR    |
    | Exit1-DR    |   +------+------+
    +------+------          |
           |                 | (TMS=1)
    (TMS=0)|                 v
           v          +-------------+
    +-------------+   | Update-DR   |
    | Pause-DR    |   +------+------+
    +------+------          |
           |                 | (TMS=0/1)
    (TMS=1)|                 v
           v          +-------------+
    +-------------+   | Run-Test/   |
    | Exit2-DR    |   |   Idle      |
    +------+------   +-------------+
           |
    (TMS=1)|
           v
    +-------------+
    | Update-DR   |
    +------+------+
           |
           | (to Run-Test/Idle)
           +---------> ...
    
    (Similar path for IR states via Select-IR)
```

#### 3.1.2 State Definitions

| State | Code | Description | Action |
|-------|------|-------------|--------|
| Test-Logic-Reset | 0x0 | 复位状态，TAP 禁用 | IR=BYPASS，所有 DR 无效 |
| Run-Test/Idle | 0x1 | 运行测试或空闲 | 等待下一个操作 |
| Select-DR | 0x2 | 选择 DR 路径 | 准备 DR 操作 |
| Capture-DR | 0x3 | 捕获 DR 数据 | 加载 DR 当前值 |
| Shift-DR | 0x4 | 移位 DR 数据 | TDI->DR->TDO |
| Exit1-DR | 0x5 | DR 退出 1 | 结束移位 |
| Pause-DR | 0x6 | DR 暂停 | 暂停移位 |
| Exit2-DR | 0x7 | DR 退出 2 | 继续或结束 |
| Update-DR | 0x8 | 更新 DR | DR 内容生效 |
| Select-IR | 0x9 | 选择 IR 路径 | 准备 IR 操作 |
| Capture-IR | 0xA | 捕获 IR 数据 | 加载 IR 当前值 |
| Shift-IR | 0xB | 移位 IR 数据 | TDI->IR->TDO |
| Exit1-IR | 0xC | IR 退出 1 | 结束移位 |
| Pause-IR | 0xD | IR 暂停 | 暂停移位 |
| Exit2-IR | 0xE | IR 退出 2 | 继续或结束 |
| Update-IR | 0xF | 更新 IR | IR 内容生效 |

#### 3.1.3 State Transition Table

| Current State | TMS=0 | TMS=1 |
|---------------|-------|-------|
| Test-Logic-Reset | Run-Test/Idle | Test-Logic-Reset |
| Run-Test/Idle | Run-Test/Idle | Select-DR |
| Select-DR | Capture-DR | Select-IR |
| Capture-DR | Shift-DR | Exit1-DR |
| Shift-DR | Shift-DR | Exit1-DR |
| Exit1-DR | Pause-DR | Update-DR |
| Pause-DR | Pause-DR | Exit2-DR |
| Exit2-DR | Shift-DR | Update-DR |
| Update-DR | Run-Test/Idle | Select-DR |
| Select-IR | Capture-IR | Test-Logic-Reset |
| Capture-IR | Shift-IR | Exit1-IR |
| Shift-IR | Shift-IR | Exit1-IR |
| Exit1-IR | Pause-IR | Update-IR |
| Pause-IR | Pause-IR | Exit2-IR |
| Exit2-IR | Shift-IR | Update-IR |
| Update-IR | Run-Test/Idle | Test-Logic-Reset |

### 3.2 Instruction Register

Instruction Register (IR) 控制 DR 的选择和行为。

#### 3.2.1 IR Structure

| Bit | Name | Description |
|-----|------|-------------|
| [0:3] | opcode | 指令操作码 |
| [4] | parity | 奇偶校验位 |

#### 3.2.2 Instruction Set

| Instruction | Opcode | DR Selected | Description | Security |
|-------------|--------|-------------|-------------|----------|
| BYPASS | 0x0 | DR_BYPASS (1-bit) | Bypass 模式，无测试操作 | Always allowed |
| IDCODE | 0x1 | DR_IDCODE (32-bit) | 返回设备 ID | Always allowed |
| EXTEST | 0x2 | DR_BSR (24-bit) | 边界扫描外部测试 | TEST_MODE required |
| INTEST | 0x3 | DR_BSR (24-bit) | 边界扫描内部测试 | TEST_MODE required |
| SCAN_IN | 0x4 | DR_SCAN | Scan Chain 输入 | TEST_MODE required |
| SCAN_OUT | 0x5 | DR_SCAN | Scan Chain 输出 | TEST_MODE required |
| SCAN_CAPTURE | 0x6 | DR_SCAN | Scan Chain 捕获 | TEST_MODE required |
| DEBUG | 0x7 | DR_DEBUG (32-bit) | Debug 访问 | TEST_MODE required |
| MBIST_CTRL | 0x8 | DR_MBIST (32-bit) | MBIST 控制 | TEST_MODE required |
| MBIST_STATUS | 0x9 | DR_MBIST (32-bit) | MBIST 状态读取 | TEST_MODE required |
| USERCODE | 0xA | DR_USERCODE (32-bit) | 用户自定义代码 | TEST_MODE required |
| HIGHZ | 0xB | DR_BYPASS | 高阻态输出 | TEST_MODE required |
| CLAMP | 0xC | DR_BYPASS | Clamp 输出 | TEST_MODE required |
| Reserved | 0xD-0xF | DR_BYPASS | 保留，行为同 BYPASS | - |

#### 3.2.3 Instruction Security Gating

| Instruction | TEST_MODE=0 | TEST_MODE=1 (valid) | TEST_MODE=1 (invalid) |
|-------------|-------------|---------------------|-----------------------|
| BYPASS | Allowed | Allowed | Allowed |
| IDCODE | Allowed | Allowed | Allowed |
| EXTEST | Blocked -> BYPASS | Allowed | Blocked -> BYPASS |
| INTEST | Blocked -> BYPASS | Allowed | Blocked -> BYPASS |
| SCAN_* | Blocked -> BYPASS | Allowed | Blocked -> BYPASS |
| DEBUG | Blocked -> BYPASS | Allowed | Blocked -> BYPASS |
| MBIST_* | Blocked -> BYPASS | Allowed | Blocked -> BYPASS |

### 3.3 Data Registers

#### 3.3.1 DR_BYPASS

| Parameter | Value | Description |
|-----------|-------|-------------|
| Width | 1 bit | 最小延时寄存器 |
| Function | TDI -> TDO (1 cycle delay) | Bypass 模式 |

#### 3.3.2 DR_IDCODE

| Bit | Value | Description |
|-----|-------|-------------|
| [0:11] | 0xABC | Manufacturer ID (IEEE assigned) |
| [12:27] | 0x12345 | Part Number (TinyStories NPU) |
| [28:31] | 0x1 | Version (v1.0) |

**IDCODE = 0x1_12345_ABC (32-bit)**

#### 3.3.3 DR_BSR (Boundary Scan Register)

| Bit | Pin | Cell Type | Description |
|-----|-----|-----------|-------------|
| [0] | POR_N | Input | Input capture |
| [1:10] | ISA_IF[7:0], ISA_CLK, ISA_VALID | Bidir | Input + Output + Enable |
| [11] | SEC_BOOT_EN | Input | Input capture |
| [12] | SEC_STATUS | Output | Output update |
| [13] | EXT_CLK | Input | Input capture |
| [14] | WAKEUP | Input | Input capture |
| [15:23] | Reserved | - | 保留位 |

#### 3.3.4 DR_SCAN

| Bit | Name | Description |
|-----|------|-------------|
| [0:15] | chain_select | Scan Chain 选择 (SC0-SC3) |
| [16] | chain_enable | Scan Chain 使能 |
| [17:N] | scan_data | Scan 数据流（长度可变） |

#### 3.3.5 DR_DEBUG

| Bit | Name | Description |
|-----|------|-------------|
| [0:15] | debug_addr | Debug 访问地址 |
| [16:47] | debug_data | Debug 数据（读/写） |

#### 3.3.6 DR_MBIST

| Bit | Name | Description |
|-----|------|-------------|
| [0] | mbist_start | MBIST 启动 |
| [1] | mbist_stop | MBIST 停止 |
| [2:3] | mbist_target | MBIST 目标 (SRAM/DRAM) |
| [4:7] | mbist_algorithm | MBIST 算法选择 |
| [8:31] | mbist_status | MBIST 状态/结果 |

### 3.4 TEST_MODE Security Control

TEST_MODE Security Control 确保 JTAG 访问的安全性，防止未授权测试操作。

#### 3.4.1 TEST_MODE Validation Sequence

```
TEST_MODE Enable Request (test_mode_en=1)
    |
    v
M14 Security Manager Validation
    |
    v
Check Secure Boot Status (SEC_BOOT_EN, SEC_STATUS)
    |
    +-- Secure Boot Failed --> test_mode_valid=0
    |
    +-- Secure Boot Passed --> test_mode_valid=1
    |
    v
test_access_grant=1 (if valid=1)
    |
    v
Allow sensitive instructions (SCAN, DEBUG, etc.)
    |
    v
Monitor instruction execution
    |
    v
test_mode_en=0 --> Immediately revoke access
```

#### 3.4.2 TEST_MODE Gating Implementation

| Component | Function |
|-----------|----------|
| TEST_MODE Decoder | 解码 TEST_MODE 输入并验证 |
| Instruction Filter | 过滤敏感指令（基于 TEST_MODE 状态） |
| Security Monitor | 监控 JTAG 活动，报告异常访问 |
| Access Timer | TEST_MODE 超时控制（防止长时间暴露） |

#### 3.4.3 TEST_MODE Timeout

| Parameter | Value | Description |
|-----------|-------|-------------|
| Timeout | 10 minutes | TEST_MODE 最大持续时间 |
| Auto-Disable | Yes | 超时自动禁用 TEST_MODE |
| Warning | Yes | 超时前 1 分钟发出告警 |

### 3.5 Scan Chain Management

Scan Chain Management 控制 4 条 Scan Chain 的访问和切换。

#### 3.5.1 Scan Chain Selection Logic

```
IR=SCAN_IN/SCAN_OUT/SCAN_CAPTURE
    |
    v
Decode DR_SCAN[0:15] -> chain_select
    |
    v
Validate TEST_MODE
    |
    +-- TEST_MODE=0 --> Return error, switch to BYPASS
    |
    v
Enable selected chain (scan_enable=1)
    |
    v
Apply control signals:
    - Capture: Capture current values
    - Shift: Shift data through chain
    - Update: Update chain outputs
```

#### 3.5.2 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Capture Time | 1 TCK cycle | Capture DR 状态 |
| Shift Rate | 1 bit/TCK cycle | Shift 数据速率 |
| Update Time | 1 TCK cycle | Update DR 状态 |
| Chain Switch | 2 TCK cycles | Scan Chain 切换时间 |

### 3.6 Debug Access

Debug Access 提供 JTAG 对内部模块的访问能力。

#### 3.6.1 Debug Access Sequence

```
IR=DEBUG
    |
    v
Validate TEST_MODE
    |
    +-- TEST_MODE=0 --> Blocked, return BYPASS
    |
    v
DR_SHIFT: debug_addr[0:15], debug_data[16:47]
    |
    v
DR_UPDATE: Apply debug access
    |
    v
Debug Controller:
    - debug_addr -> Select target register
    - debug_rw -> Read or Write
    - debug_data_in -> Write data
    - debug_data_out -> Read data
    |
    v
debug_ack -> Confirm access
    |
    v
Next DR_SHIFT cycle (for continued access)
```

#### 3.6.2 Debug Address Map

| Address Range | Target | Description |
|---------------|--------|-------------|
| 0x0000-0x00FF | M00 | Systolic Array 状态 |
| 0x0100-0x01FF | M01 | Dataflow Controller 状态 |
| 0x0200-0x02FF | M02 | SRAM Controller 状态 |
| 0x0300-0x03FF | M03 | DRAM Controller 状态 |
| 0x0400-0x04FF | M04 | System Bus 状态 |
| 0x0500-0x05FF | M05 | Power Manager 状态 |
| 0x0600-0x06FF | M06 | Clock Manager 状态 |
| 0x0700-0x07FF | M07 | Reset Controller 状态 |
| 0x0800-0x08FF | M08 | Vector Operator 状态 |
| 0x0900-0x09FF | M09 | RMSNorm Operator 状态 |
| 0x0A00-0x0AFF | M10 | RoPE Operator 状态 |
| 0x0B00-0x0BFF | M11 | MatMul Operator 状态 |
| 0x0C00-0x0CFF | M12 | Softmax Operator 状态 |
| 0x0D00-0x0DFF | M13 | ISA Interface 状态 |
| 0x0E00-0x0EFF | M14 | Security Manager 状态（受限） |
| 0x0F00-0x0FFF | Global | 全局状态寄存器 |

## 4. Timing

### 4.1 JTAG Timing Parameters

| Parameter | Symbol | Min | Max | Unit | Description |
|-----------|--------|-----|-----|------|-------------|
| TCK Frequency | f_TCK | - | 50 | MHz | JTAG 时钟频率 |
| TCK Period | t_TCK | 20 | - | ns | JTAG 时钟周期 |
| TCK High | t_TCKH | 8 | - | ns | TCK 高电平时间 |
| TCK Low | t_TCKL | 8 | - | ns | TCK 低电平时间 |
| TMS Setup | t_TMS_SU | 2 | - | ns | TMS 到 TCK 上升沿建立时间 |
| TMS Hold | t_TMS_H | 2 | - | ns | TMS 到 TCK 上升沿保持时间 |
| TDI Setup | t_TDI_SU | 2 | - | ns | TDI 到 TCK 上升沿建立时间 |
| TDI Hold | t_TDI_H | 2 | - | ns | TDI 到 TCK 上升沿保持时间 |
| TDO Valid | t_TDO_V | - | 5 | ns | TDO 数据有效延迟 |
| TRST Setup | t_TRST | 10 | - | ns | TRST 最小脉冲宽度 |

### 4.2 State Machine Timing

| Transition | Cycles | Description |
|------------|--------|-------------|
| Reset -> Idle | 1 | TMS=0，进入 Run-Test/Idle |
| Idle -> Capture-DR | 2 | Select-DR -> Capture-DR |
| Capture-DR -> Shift-DR | 1 | TMS=0 |
| Shift-DR (per bit) | 1 | 每位移位 1 TCK cycle |
| Shift-DR -> Update-DR | 2 | Exit1-DR -> Update-DR |
| IR Change | 3+ | Capture-IR -> Shift-IR -> Update-IR |

### 4.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Chain Length | ~10k cells | Per chain |
| Full Scan Shift | ~200 us | @ 50 MHz TCK |
| Capture Cycle | 1 cycle | Capture DR |
| Update Cycle | 1 cycle | Update DR |

### 4.4 Debug Access Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Debug Address Setup | 1 cycle | Address生效 |
| Debug Data Valid | 2 cycles | 读数据返回 |
| Debug Write | 1 cycle | 写操作完成 |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **IEEE 1149.1 Compliance**: M15 必须完全符合 IEEE 1149.1-2013 标准，支持边界扫描、内建自测试访问。

2. **TEST_MODE Security**: TEST_MODE 门控是关键安全机制，必须：
   - 验证 Secure Boot 状态后才允许敏感操作
   - 超时自动禁用 TEST_MODE
   - 记录所有测试访问日志

3. **Scan Chain Balance**: 4 条 Scan Chain 长度平衡，确保 ATPG 效率。

4. **TDO Drive**: TDO 输出需支持多芯片串联配置，提供 tdo_en 控制信号。

5. **Clock Domain**: JTAG TCK 与 CLK_IO 异步，需要同步处理。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol |
|-----------|---------------|----------|
| TEST_MODE | M14 Security Manager | Custom validation |
| Scan Chain | All Modules (M00-M14) | Custom scan protocol |
| Debug | All Modules (M00-M14) | Custom debug bus |
| MBIST | M02 (SRAM), M03 (DRAM) | MBIST control |

### 5.3 Verification Requirements

| Test Category | Description |
|---------------|-------------|
| TAP FSM | 验证所有状态转换符合 IEEE 1149.1 |
| Instructions | 验证所有指令行为正确 |
| TEST_MODE Gating | 验证安全门控逻辑 |
| Scan Chain | 验证 Scan Chain 选择和数据流 |
| Debug Access | 验证 Debug 读写功能 |
| Boundary Scan | 验证 BSR 功能 |
| MBIST | 验证 MBIST 控制和状态 |

### 5.4 Power Budget Allocation

| Component | Budget | Allocation |
|-----------|--------|------------|
| TAP Controller | 5 mW | FSM + Registers + Decoder |
| IO Buffers | 10 mW | JTAG pin buffers |
| **Total** | **15 mW** | PD_IO 功耗预算 |

### 5.5 Reset Strategy

| Reset | Source | Effect |
|-------|--------|--------|
| trst_n | External (Pin 9) | TAP FSM -> Test-Logic-Reset，IR=BYPASS |
| rst_io_n | System Reset | 全部寄存器复位 |
| Soft Reset | TMS=1 for 5+ TCK cycles | FSM -> Test-Logic-Reset |

### 5.6 Clock Domain Crossing

| Crossing | From | To | Method |
|----------|------|----|----|
| TAP Control | TCK | CLK_IO | Synchronizer (2-stage) |
| Debug Access | TCK | CLK_SYS | Handshake bridge |
| Scan Control | TCK | CLK_SYS | Pulse synchronizer |

### 5.7 JTAG Daisy Chain Support

| Feature | Description |
|---------|-------------|
| tdo_en Output | 用于多芯片串联 TDO 控制 |
| BYPASS Default | 未选中芯片自动进入 BYPASS |
| Chain Position | 支持 Upstream/Downstream 配置 |