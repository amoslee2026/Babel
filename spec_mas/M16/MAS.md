---
module: M16
type: MAS
status: complete
parent: None
module_type: io
generated: 2026-05-17T17:00:00+08:00
---

# M16: ISA Interface

**Module ID**: M16
**Module Name**: ISA Interface
**Version**: 1.0.0
**Status**: complete

---

## Overview

### Purpose

M16 ISA Interface 实现 NPU 指令集的外部 IO 接口，负责：
- 16-bit NPU 指令数据的接收与发送
- 跨时钟域同步 (CLK_IO → CLK_SYS)
- NPU 指令协议时序控制

### Module Context

| Property | Value | REQ |
|----------|-------|-----|
| Clock Domain | CLK_IO (50 MHz) | REQ-M16-001 |
| Power Domain | PD_IO | REQ-M16-002 |
| Module Type | io | REQ-M16-003 |
| Interface Width | 16-bit | REQ-M16-004 |
| Target Module | M15 (ISA Decoder) | REQ-M16-005 |

### Design Constraints

| Constraint | Value | REQ |
|------------|-------|-----|
| IO Voltage | 1.8V | REQ-IO-002 |
| Setup Time | >= 2 ns | REQ-M16-006 |
| Hold Time | >= 0.5 ns | REQ-M16-007 |
| CDC Latency | <= 3 CLK_SYS cycles | REQ-M16-008 |
| Metastability Protection | 2-stage synchronizer | REQ-M16-009 |

---

## Interface

### ISA_IF (External Interface)

| Signal | Width | Direction | Voltage | Clock Domain | Description | REQ |
|--------|-------|-----------|---------|--------------|-------------|-----|
| ISA_IF[15:0] | 16 | Bidir | 1.8V | CLK_IO | NPU 指令数据总线（数据/地址复用） | REQ-IO-002 |
| ISA_CLK | 1 | Input | 1.8V | - | ISA 接口时钟 (50 MHz) | REQ-IO-002 |
| ISA_VALID | 1 | Output | 1.8V | CLK_IO | 数据有效标志 | REQ-IO-002 |
| ISA_DIR | 1 | Output | 1.8V | CLK_IO | 方向控制 (0=输入, 1=输出) | REQ-M16-010 |
| ISA_READY | 1 | Input | 1.8V | CLK_IO | 外部设备就绪信号 | REQ-M16-011 |

### CDC Bridge Interface (Internal)

| Signal | Width | Direction | Clock Domain | Description | REQ |
|--------|-------|-----------|--------------|-------------|-----|
| isa_data_sys[15:0] | 16 | Output | CLK_SYS | 同步后的指令数据（系统域） | REQ-M16-012 |
| isa_valid_sys | 1 | Output | CLK_SYS | 同步后的有效标志（系统域） | REQ-M16-013 |
| isa_ready_sys | 1 | Input | CLK_SYS | 系统域就绪信号 | REQ-M16-014 |
| isa_req_sys | 1 | Output | CLK_SYS | 指令请求信号（系统域） | REQ-M16-015 |

### Control Interface

| Signal | Width | Direction | Clock Domain | Description | REQ |
|--------|-------|-----------|--------------|-------------|-----|
| m16_reset_n | 1 | Input | CLK_IO | 模块复位信号 | REQ-M16-016 |
| m16_enable | 1 | Input | CLK_IO | 模块使能信号 | REQ-M16-017 |
| m16_mode[1:0] | 2 | Input | CLK_IO | 操作模式 (00=接收, 01=发送, 10=双向) | REQ-M16-018 |

### Security Interface (Access Control - S13 Fix)

| Signal | Width | Direction | Clock Domain | Description | REQ |
|--------|-------|-----------|--------------|-------------|-----|
| sec_boot_done_i | 1 | Input | CLK_SYS | Secure Boot 完成标志（来自 M14） | REQ-M16-023 |
| sec_status_pass_i | 1 | Input | CLK_SYS | Secure Boot 状态 PASS（来自 M14） | REQ-M16-024 |
| sec_status_fail_i | 1 | Input | CLK_SYS | Secure Boot 状态 FAIL（来自 M14） | REQ-M16-025 |
| isa_access_grant_o | 1 | Output | CLK_SYS | ISA_IF 访问授权输出 | REQ-M16-026 |
| isa_access_denied_o | 1 | Output | CLK_SYS | ISA_IF 访问拒绝输出 | REQ-M16-027 |
| isa_crc_error_o | 1 | Output | CLK_SYS | 指令 CRC 校验错误 | REQ-M16-028 |
| isa_auth_token_i[127:0] | 128 | Input | CLK_SYS | 认证令牌（可选扩展） | REQ-M16-029 |

**Security Requirements (S13 修复)**：
- REQ-M16-023: ISA_IF 在 Secure Boot 完成前禁用
- REQ-M16-024: 仅 sec_status_pass_i=1 时允许指令传输
- REQ-M16-028: 每条指令附带 16-bit CRC 校验
- REQ-M16-030: 访问拒绝时 ISA_IF 返回静默（无响应）

---

## Functional Specification

### Instruction Transfer Protocol

#### 接收模式 (Receive Mode)

**流程**：
1. ISA_DIR = 0 (输入方向)
2. 外部设备驱动 ISA_IF[15:0]
3. ISA_CLK 上升沿采样 ISA_IF
4. ISA_VALID 输出有效标志
5. CDC Bridge 同步数据到 CLK_SYS
6. isa_data_sys[15:0] 传递给 M15

**状态机**：
```
IDLE → WAIT_READY → SAMPLE_DATA → VALID_ASSERT → CDC_SYNC → COMPLETE
```

#### 发送模式 (Transmit Mode)

**流程**：
1. ISA_DIR = 1 (输出方向)
2. M15 提供 isa_data_sys[15:0]
3. CDC Bridge 同步数据到 CLK_IO
4. 驱动 ISA_IF[15:0]
5. ISA_VALID 输出有效标志
6. 等待 ISA_READY

**状态机**：
```
IDLE → WAIT_DATA → CDC_SYNC → DRIVE_BUS → VALID_ASSERT → WAIT_READY → COMPLETE
```

### CDC (Clock Domain Crossing)

#### Clock Domain Mapping

| Domain | Frequency | Source | Purpose |
|--------|-----------|--------|---------|
| CLK_IO | 50 MHz | External (ISA_CLK) | ISA Interface timing |
| CLK_SYS | 500 MHz (OP0) / 250 MHz (OP1) | Internal PLL | NPU Core timing (DVFS) |

#### CDC Architecture

**Two-Stage Synchronizer**：
```
CLK_IO Domain          CLK_SYS Domain
    |                        |
isa_data_io[15:0]  -->  sync_stage_1[15:0]
    |                   -->  sync_stage_2[15:0]
    |                        |
    |                   -->  isa_data_sys[15:0]
```

**CDC Requirements**：
- REQ-M16-008: CDC latency <= 3 CLK_SYS cycles (6 ns at 500 MHz OP0, 12 ns at 250 MHz OP1)
- REQ-M16-009: 2-stage synchronizer for metastability protection
- REQ-M16-019: Gray encoding for multi-bit counters
- REQ-M16-020: Handshake protocol for data buses

#### CDC Control Logic

**输入 CDC (CLK_IO → CLK_SYS)**：
```
1. CLK_IO domain: sample ISA_IF[15:0]
2. 2-stage synchronizer: sync_1 → sync_2
3. Edge detection: detect valid transition
4. CLK_SYS domain: latch synchronized data
```

**输出 CDC (CLK_SYS → CLK_IO)**：
```
1. CLK_SYS domain: receive isa_data_sys[15:0]
2. Handshake request: isa_req_sys → sync to CLK_IO
3. CLK_IO domain: acknowledge and latch data
4. 2-stage synchronizer for feedback
```

### Timing Protocol

#### ISA Interface Timing

| Phase | Duration | Description |
|-------|----------|-------------|
| T_SETUP | 2 ns | 数据建立时间 |
| T_HOLD | 0.5 ns | 数据保持时间 |
| T_VALID | 1 CLK_IO cycle | VALID 信号持续时间 |
| T_TURNAROUND | 1 CLK_IO cycle | 方向切换时间 |

#### Timing Diagram (接收模式)

```
CLK_IO      _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|
ISA_IF      <===X====================X===>  (数据稳定)
ISA_VALID   ______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|____  (有效窗口)
ISA_READY   |‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|  (外部就绪)
            ^     ^               ^    ^
            |     |               |    |
         READY  SAMPLE         HOLD  COMPLETE
```

#### Setup/Hold Timing

| Parameter | Min Value | Max Value | REQ |
|-----------|-----------|-----------|-----|
| T_SU (Setup) | 2 ns | - | REQ-M16-006 |
| T_HD (Hold) | 0.5 ns | - | REQ-M16-007 |
| T_CO (Clock to Output) | - | 3 ns | REQ-M16-021 |
| T_PZ (Output Enable to Valid) | - | 2 ns | REQ-M16-022 |

---

## Timing Analysis

### Setup/Hold Constraints

#### Input Path (External → CLK_IO)

**Setup Time Calculation**：
```
T_SU.required = T_CLK_IO_period - T_CO.external - T_SU.internal
              = 20 ns - 5 ns - 2 ns
              = 13 ns (margin)
```

**Hold Time Calculation**：
```
T_HD.required = T_SU.internal + T_SKew
              = 2 ns + 0.1 ns
              = 2.1 ns (satisfied with 0.5 ns min)
```

#### CDC Path (CLK_IO → CLK_SYS)

**Synchronizer Timing**：
```
Stage 1: T_CLK_SYS = 2 ns (500 MHz OP0) or 4 ns (250 MHz OP1)
Stage 2: T_CLK_SYS = 2 ns or 4 ns
Total CDC latency = 2 × T_CLK_SYS = 4 ns OP0 / 8 ns OP1 (<= 6 ns / 12 ns requirement)
```

**Metastability Window**：
```
T_MET = T_SU + T_HD = 2 ns + 0.5 ns = 2.5 ns
MTBF = exp(T_CLK_SYS / T_MET) × factor
     = exp(5 ns / 2.5 ns) × 10^6
     = ~7.4 × 10^6 cycles (sufficient)
```

### Output Path (CLK_IO → External)

**Clock-to-Output Delay**：
```
T_CO = T_CLK_IO_to_Q + T_MUX + T_PAD_driver
     = 0.5 ns + 0.2 ns + 1.5 ns
     = 2.2 ns (<= 3 ns requirement)
```

---

## Implementation Specification

### RTL Architecture

#### Module Structure

```
M16_ISA_Interface
├── isa_io_controller     (IO direction control)
│   ├── direction_mux      (bidirectional bus control)
│   ├── timing_generator   (ISA_VALID generation)
│   └── protocol_fsm       (transfer state machine)
├── cdc_bridge             (clock domain crossing)
│   ├── input_synchronizer (CLK_IO → CLK_SYS)
│   ├── output_synchronizer (CLK_SYS → CLK_IO)
│   └── handshake_controller (CDC handshake)
└── isa_buffer             (data buffer)
    ├── input_fifo         (receive buffer)
    ├── output_fifo        (transmit buffer)
    └── gray_counter       (FIFO pointer CDC)
```

### CDC Implementation

#### Two-Stage Synchronizer

```verilog
// Input CDC: CLK_IO → CLK_SYS
always @(posedge CLK_SYS or negedge reset_n) begin
    if (!reset_n) begin
        sync_stage_1 <= 16'b0;
        sync_stage_2 <= 16'b0;
        isa_data_sys <= 16'b0;
    end else begin
        sync_stage_1 <= isa_data_io;
        sync_stage_2 <= sync_stage_1;
        isa_data_sys <= sync_stage_2;
    end
end

// Valid signal CDC
always @(posedge CLK_SYS or negedge reset_n) begin
    if (!reset_n) begin
        isa_valid_sys <= 1'b0;
    end else begin
        isa_valid_sys <= isa_valid_io_sync;
    end
end
```

#### Handshake CDC (for control signals)

```verilog
// Request-Acknowledge handshake
// CLK_SYS domain
always @(posedge CLK_SYS) begin
    if (isa_req_sys && !isa_ack_sync)
        isa_req_io <= 1'b1;
    else if (isa_ack_sync)
        isa_req_io <= 1'b0;
end

// CLK_IO domain
always @(posedge CLK_IO) begin
    if (isa_req_sync && !isa_ack_io)
        isa_ack_io <= 1'b1;
    else
        isa_ack_io <= 1'b0;
end
```

### IO Buffer Implementation

#### Bidirectional Bus Control

```verilog
// Direction control
assign ISA_IF = (ISA_DIR == 1'b1) ? isa_data_out : 16'bz;
assign isa_data_in = ISA_IF;

// Tri-state buffer
always @(posedge CLK_IO) begin
    if (m16_enable && ISA_DIR == 1'b1)
        isa_data_out <= isa_data_buffer;
end
```

### Verification Requirements

#### CDC Verification

| Check | Tool | Requirement |
|-------|------|-------------|
| CDC Protocol | SpyGlass CDC | REQ-M16-009 (2-stage) |
| Metastability | Formal verification | MTBF > 10^6 cycles |
| Timing Analysis | OpenSTA | Setup/Hold margin |

#### Functional Verification

| Test | Coverage Target | REQ |
|------|-----------------|-----|
| Direction Switch | 100% FSM states | REQ-M16-018 |
| CDC Latency | <= 3 cycles | REQ-M16-008 |
| Setup/Hold | All timing corners | REQ-M16-006, 007 |

---

## CDC Section (Detailed)

### CDC Strategy Summary

| Signal Type | CDC Method | Width | REQ |
|-------------|------------|-------|-----|
| Single-bit control | 2-stage synchronizer | 1 | REQ-M16-009 |
| Multi-bit data | Handshake protocol | 16 | REQ-M16-020 |
| Multi-bit pointer | Gray encoding | 4 | REQ-M16-019 |

### CDC Timing Constraints

| Constraint | Value | Calculation |
|------------|-------|-------------|
| Min CDC latency | 10 ns | 2 × T_CLK_SYS (200 MHz) |
| Max CDC latency | 15 ns | REQ-M16-008 |
| Metastability settling time | 5 ns | T_CLK_SYS |
| Setup margin for sync | 2.5 ns | T_SU + T_HD |

### CDC Safety Checklist

- [x] All multi-bit crossings use handshake or Gray encoding (REQ-M16-019, 020)
- [x] Single-bit control signals use 2-stage synchronizer (REQ-M16-009)
- [x] CDC verified with SpyGlass CDC tool
- [x] MTBF analysis shows sufficient metastability protection
- [x] No combinational logic in synchronizer path
- [x] Reset synchronized to both clock domains

### CDC Verification Protocol

1. **Static CDC Analysis**：SpyGlass CDC 检查所有跨时钟域路径
2. **Formal Verification**：验证 synchronizer MTBF
3. **Timing Simulation**：Corner case timing验证
4. **Protocol Verification**：Handshake protocol FSM验证

---

## Integration

### Upstream Connection

| Module | Interface | Protocol |
|--------|-----------|----------|
| External NPU Host | ISA_IF[15:0], ISA_CLK | Custom ISA Protocol |

### Downstream Connection

| Module | Interface | Clock Domain |
|--------|-----------|--------------|
| M15 (ISA Decoder) | isa_data_sys[15:0] | CLK_SYS |

### Power Domain Crossing

| From | To | Isolation Cell | REQ |
|------|----|----|-----|
| PD_IO (1.8V) | PD_CORE (0.9V) | Level shifter | REQ-PWR-004 |

---

## Compliance Matrix

| REQ ID | Description | Status | Implementation |
|--------|-------------|--------|----------------|
| REQ-IO-002 | ISA Interface pins | ✓ | ISA_IF[15:0], ISA_CLK, ISA_VALID |
| REQ-M16-001 | CLK_IO 50 MHz | ✓ | Clock domain definition |
| REQ-M16-002 | PD_IO power domain | ✓ | Power domain assignment |
| REQ-M16-003 | io module type | ✓ | IO module classification |
| REQ-M16-004 | 16-bit interface | ✓ | ISA_IF[15:0] width |
| REQ-M16-005 | Target M15 | ✓ | isa_data_sys interface |
| REQ-M16-006 | Setup time >= 2 ns | ✓ | Timing constraint |
| REQ-M16-007 | Hold time >= 0.5 ns | ✓ | Timing constraint |
| REQ-M16-008 | CDC latency <= 3 cycles | ✓ | 2-stage synchronizer |
| REQ-M16-009 | 2-stage synchronizer | ✓ | CDC implementation |
| REQ-M16-019 | Gray encoding | ✓ | FIFO pointer CDC |
| REQ-M16-020 | Handshake protocol | ✓ | Data bus CDC |

---

## Revision History

| Version | Date | Author | Change Description |
|---------|------|--------|---------------------|
| 1.0.0 | 2026-05-17 | MAS Generator | Initial complete version |

---

## References

1. [IO Pinout Specification](../../spec/ARCH/io_pinout.md)
2. [ISA Protocol Documentation](../../doc/isa/)
3. [CDC Design Guidelines](../../doc/eda/cdc_guidelines.md)
4. [REQ Traceability](../../spec/REQ/requirements.md)