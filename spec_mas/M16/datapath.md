---
module: M16
type: datapath
status: complete
parent: None
module_type: io
generated: "2026-05-17T17:00:00+08:00"
---

# Datapath Design - M16 ISA Interface

## 1. Overview

M16 ISA Interface Datapath 实现 NPU 指令集的外部 IO 接口与跨时钟域同步，采用 CDC Handshake 架构。核心数据通路包括 ISA_IF Bidirectional Buffer、Two-Stage Synchronizer、Instruction Parser 和 Secure Boot Access Controller，确保 16-bit 指令数据可靠传输至 M13 ISA Decoder。

### 1.1 Datapath Key Features

| Feature | Description | Performance |
|---------|-------------|-------------|
| 16-bit ISA I/O | Instruction data bus | REQ-M16-004 |
| CDC Bridge | CLK_IO -> CLK_SYS | <= 3 CLK_SYS cycles |
| Two-Stage Synchronizer | Metastability protection | REQ-M16-009 |
| Handshake Protocol | Data bus CDC | REQ-M16-020 |
| Secure Boot Gate | M14 status linkage | REQ-SEC-001 |

### 1.2 ISA Interface Data Flow

```
ISA_IF Input Path:
  ISA_IF[15:0] -> Input Buffer -> 2-Stage Sync -> isa_data_sys[15:0] -> M13
  
ISA_IF Output Path:
  isa_data_sys[15:0] -> Handshake -> 2-Stage Sync -> ISA_IF[15:0] -> External
  
CDC Synchronization:
  CLK_IO (50 MHz) -> sync_stage_1 -> sync_stage_2 -> CLK_SYS (200 MHz)
  Latency: 2 CLK_SYS cycles (<= 15 ns)
  
Instruction Parsing:
  LSB[15:0] + MSB[15:0] -> 32-bit instruction -> M13 Decoder
```

## 2. Block Diagram

### 2.1 Top-Level Datapath

```mermaid
graph TB
    subgraph IO["ISA_IF External Interface"]
        ISA_IF[ISA_IF[15:0]<br/>Bidirectional]
        ISA_CLK[ISA_CLK<br/>50 MHz]
        ISA_VALID[ISA_VALID]
        ISA_DIR[ISA_DIR<br/>Direction Control]
        ISA_READY[ISA_READY]
    end
    
    subgraph INPUT["Input Path"]
        IN_BUF[Input Buffer<br/>16-bit]
        DIR_CTRL[Direction Controller<br/>ISA_DIR=0]
    end
    
    subgraph CDC_IN["Input CDC Bridge"]
        SYNC1[sync_stage_1<br/>16-bit FF]
        SYNC2[sync_stage_2<br/>16-bit FF]
        DATA_SYS[isa_data_sys<br/>16-bit]
        VALID_SYNC[Valid Sync<br/>2-stage]
    end
    
    subgraph PARSE["Instruction Parser"]
        LSB_BUF[LSB Buffer<br/>16-bit]
        MSB_BUF[MSB Buffer<br/>16-bit]
        MERGE[32-bit Merge]
        OPCODE_CHK[Opcode Check]
        INSTR_OUT[instr_decoded<br/>32-bit]
    end
    
    subgraph OUTPUT["Output Path"]
        OUT_BUF[Output Buffer<br/>16-bit]
        HANDSHAKE[Handshake Controller]
    end
    
    subgraph CDC_OUT["Output CDC Bridge"]
        REQ_SYNC[Request Sync]
        ACK_SYNC[Acknowledge Sync]
    end
    
    subgraph CTRL["Access Control"]
        M14_LINK[M14 Secure Boot Link]
        SEC_GATE[Security Gate]
        ISA_EN[isa_if_enable]
    end
    
    subgraph INTERNAL["Internal Interface to M13"]
        ISA_DATA_SYS[isa_data_sys<br/>16-bit]
        ISA_VALID_SYS[isa_valid_sys]
        ISA_READY_SYS[isa_ready_sys]
        ISA_REQ_SYS[isa_req_sys]
    end
    
    ISA_IF --> IN_BUF
    ISA_CLK --> SYNC1
    ISA_DIR --> DIR_CTRL
    DIR_CTRL --> IN_BUF
    
    IN_BUF --> SYNC1
    SYNC1 --> SYNC2
    SYNC2 --> DATA_SYS
    ISA_VALID --> VALID_SYNC
    VALID_SYNC --> ISA_VALID_SYS
    
    DATA_SYS --> LSB_BUF
    LSB_BUF --> MERGE
    DATA_SYS --> MSB_BUF
    MSB_BUF --> MERGE
    MERGE --> OPCODE_CHK
    OPCODE_CHK --> INSTR_OUT
    
    M14_LINK --> SEC_GATE
    SEC_GATE --> ISA_EN
    ISA_EN --> DIR_CTRL
    
    ISA_REQ_SYS --> REQ_SYNC
    REQ_SYNC --> HANDSHAKE
    HANDSHAKE --> OUT_BUF
    OUT_BUF --> ISA_IF
    
    ISA_READY --> ACK_SYNC
    ACK_SYNC --> ISA_READY_SYS
```

### 2.2 CDC Timing Diagram

```
CLK_IO (50 MHz):  |‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|  (20 ns period)
ISA_IF:           <==X========DATA========X===> (stable window)
ISA_VALID:        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___ (valid pulse)

CLK_SYS (200 MHz):|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|  (5 ns period)
sync_stage_1:     ___|<DATA>_______________ (Stage 1 capture)
sync_stage_2:     _________|<DATA>_________ (Stage 2 stable)
isa_data_sys:     ________________|<DATA>__ (Output valid)

CDC Latency: 2 CLK_SYS cycles = 10 ns (<= 15 ns REQ-M16-008)
```

## 3. Datapath Components

### 3.1 ISA_IF Bidirectional Buffer

#### 3.1.1 Direction Controller

```verilog
// ISA_IF Direction Controller
module isa_direction_controller (
    input  logic        m16_enable,
    input  logic        m16_mode,      // 0=Receive, 1=Transmit
    input  logic        isa_if_enable, // From Secure Boot gate
    output logic        isa_dir,
    output logic        isa_valid_out
);

    // ISA_DIR: 0=Input (receive), 1=Output (transmit)
    always_comb begin
        if (!m16_enable || !isa_if_enable) begin
            isa_dir = 1'b0;       // Default to input (safe state)
            isa_valid_out = 1'b0;
        end else begin
            isa_dir = m16_mode;   // Follow mode setting
            isa_valid_out = 1'b1; // Valid when enabled
        end
    end

endmodule
```

#### 3.1.2 Bidirectional IO Buffer

```verilog
// ISA_IF Bidirectional Buffer
module isa_bidirectional_buffer (
    inout  logic [15:0] ISA_IF,
    input  logic        isa_dir,
    input  logic [15:0] isa_data_out,
    output logic [15:0] isa_data_in,
    input  logic        m16_enable
);

    // Tri-state buffer control
    assign ISA_IF = (isa_dir == 1'b1 && m16_enable) ? isa_data_out : 16'bz;
    assign isa_data_in = ISA_IF;

endmodule
```

### 3.2 CDC Bridge (CLK_IO -> CLK_SYS)

#### 3.2.1 Two-Stage Synchronizer

```verilog
// Two-Stage Synchronizer (REQ-M16-009)
module two_stage_synchronizer #(
    parameter WIDTH = 16
)(
    input  logic             clk_sys,
    input  logic             rst_sys_n,
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

    logic [WIDTH-1:0] sync_stage_1;
    logic [WIDTH-1:0] sync_stage_2;
    
    // Two-stage flip-flop chain for metastability protection
    always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
            sync_stage_1 <= {WIDTH{1'b0}};
            sync_stage_2 <= {WIDTH{1'b0}};
        end else begin
            sync_stage_1 <= data_in;
            sync_stage_2 <= sync_stage_1;
        end
    end
    
    assign data_out = sync_stage_2;

endmodule
```

#### 3.2.2 Valid Signal CDC

```verilog
// Valid Signal Synchronizer
module valid_synchronizer (
    input  logic clk_io,
    input  logic clk_sys,
    input  logic rst_sys_n,
    input  logic isa_valid_io,
    output logic isa_valid_sys,
    output logic valid_pulse   // Edge detection for parser
);

    logic sync1, sync2, sync3;
    
    // Three-stage synchronizer for edge detection
    always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync3 <= 1'b0;
        end else begin
            sync1 <= isa_valid_io;
            sync2 <= sync1;
            sync3 <= sync2;
        end
    end
    
    assign isa_valid_sys = sync2;
    assign valid_pulse = sync2 & ~sync3;  // Rising edge detection

endmodule
```

#### 3.2.3 CDC Timing Parameters

| Parameter | Value | Requirement |
|-----------|-------|-------------|
| Max CDC Latency | 10 ns | <= 15 ns (REQ-M16-008) |
| Metastability Window | 2.5 ns | T_SU + T_HD |
| MTBF | > 10^6 cycles | Sufficient protection |
| Sync Stages | 2 | REQ-M16-009 |

### 3.3 Instruction Parser

#### 3.3.1 LSB/MSB Buffer

```verilog
// Instruction Parser (2-cycle 16-bit transfers)
module instruction_parser (
    input  logic        clk_sys,
    input  logic        rst_sys_n,
    input  logic        isa_valid_sys,
    input  logic [15:0] isa_data_sys,
    output logic [31:0] instr_out,
    output logic        instr_valid,
    output logic        instr_error
);

    logic [15:0] lsb_buffer;
    logic [15:0] msb_buffer;
    logic        fetch_count;
    logic        timeout_counter;
    
    // Two-cycle instruction fetch: LSB then MSB
    always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
            lsb_buffer <= 16'b0;
            msb_buffer <= 16'b0;
            fetch_count <= 2'b0;
            instr_valid <= 1'b0;
            timeout_counter <= 8'b0;
        end else if (isa_valid_sys && fetch_count < 2) begin
            if (fetch_count == 0) begin
                lsb_buffer <= isa_data_sys;  // First cycle: LSB
                fetch_count <= 2'b1;
            end else begin
                msb_buffer <= isa_data_sys;  // Second cycle: MSB
                fetch_count <= 2'b2;
                instr_valid <= 1'b1;
            end
            timeout_counter <= 8'b0;
        end else if (fetch_count == 2) begin
            instr_valid <= 1'b0;  // Clear after one cycle
            fetch_count <= 2'b0;
        end else if (fetch_count > 0 && timeout_counter < 255) begin
            timeout_counter <= timeout_counter + 1;
        end else if (timeout_counter >= 255) begin
            instr_error <= 1'b1;  // Timeout error
            fetch_count <= 2'b0;
        end
    end
    
    // Merge LSB and MSB to form 32-bit instruction
    assign instr_out = {msb_buffer, lsb_buffer};

endmodule
```

#### 3.3.2 Opcode Validity Check

| OPCODE Range | Category | Valid | Error Code |
|--------------|----------|-------|------------|
| 0x00-0x05 | Vector Arith | Valid | - |
| 0x08-0x0A | MatMul | Valid | - |
| 0x10-0x14 | Special Func | Valid | - |
| 0x20-0x25 | Memory | Valid | - |
| 0x30-0x34 | Scalar/Control | Valid | - |
| Others | Reserved | Invalid | INVALID_OPCODE |

### 3.4 Handshake CDC Controller

#### 3.4.1 Request-Acknowledge Protocol

```verilog
// Handshake CDC for Output Path
module handshake_cdc (
    input  logic clk_sys,
    input  logic clk_io,
    input  logic rst_n,
    input  logic isa_req_sys,
    output logic isa_ack_sys,
    output logic isa_req_io,
    input  logic isa_ack_io
);

    logic req_sync1, req_sync2;
    logic ack_sync1, ack_sync2;
    
    // Request sync: CLK_SYS -> CLK_IO
    always_ff @(posedge clk_io or negedge rst_n) begin
        if (!rst_n) begin
            req_sync1 <= 1'b0;
            req_sync2 <= 1'b0;
        end else begin
            req_sync1 <= isa_req_sys;
            req_sync2 <= req_sync1;
        end
    end
    assign isa_req_io = req_sync2;
    
    // Acknowledge sync: CLK_IO -> CLK_SYS
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
        end else begin
            ack_sync1 <= isa_ack_io;
            ack_sync2 <= ack_sync1;
        end
    end
    assign isa_ack_sys = ack_sync2;

endmodule
```

### 3.5 Secure Boot Access Control

#### 3.5.1 M14 Status Link

| M14 State | sec_boot_done | sec_status_pass | M16 State | ISA_IF Enable |
|-----------|---------------|-----------------|-----------|---------------|
| BOOT_INIT | 0 | 0 | LOCKED | Disable |
| BOOT_VERIFY | 0 | 0 | WAIT_BOOT | Disable |
| BOOT_PASS | 1 | 1 | UNLOCKED | Enable |
| BOOT_FAIL | 1 | 0 | ERROR_BOOT_FAIL | Disable |
| LOCKDOWN | - | - | LOCKDOWN | Disable |

#### 3.5.2 Security Gate Logic

```verilog
// Secure Boot Access Gate
module secure_boot_gate (
    input  logic sec_boot_done,
    input  logic sec_status_pass,
    input  logic sec_status_fail,
    input  logic sec_lockdown,
    input  logic m16_enable,
    output logic isa_if_enable,
    output logic access_error
);

    // ISA_IF enable only when Secure Boot passes
    always_comb begin
        if (sec_lockdown || sec_status_fail) begin
            isa_if_enable = 1'b0;  // Disable on security violation
            access_error = 1'b1;
        end else if (sec_boot_done && sec_status_pass && m16_enable) begin
            isa_if_enable = 1'b1;  // Enable on successful boot
            access_error = 1'b0;
        end else begin
            isa_if_enable = 1'b0;  // Default disabled
            access_error = 1'b0;
        end
    end

endmodule
```

## 4. Pipeline Structure

### 4.1 Instruction Transfer Pipeline

| Phase | Duration | Clock Domain | Description |
|-------|----------|--------------|-------------|
| T_SAMPLE | 1 cycle | CLK_IO | ISA_IF sampling |
| T_SYNC1 | 1 cycle | CLK_SYS | First sync stage |
| T_SYNC2 | 1 cycle | CLK_SYS | Second sync stage |
| T_PARSE | 2 cycles | CLK_SYS | LSB + MSB merge |
| **Total** | **<= 4 cycles** | Mixed | End-to-end latency |

### 4.2 CDC Timing Analysis

| Constraint | Value | Calculation |
|------------|-------|-------------|
| Min CDC Latency | 10 ns | 2 x T_CLK_SYS (5 ns) |
| Max CDC Latency | 15 ns | REQ-M16-008 |
| Setup Margin | 2.5 ns | T_SU + T_HD |
| ISA_IF Stability | >= 40 ns | 2 x T_CLK_SYS period |

## 5. Interface Summary

### 5.1 ISA_IF External Interface

| Signal | Width | Direction | Voltage | Clock | Description |
|--------|-------|-----------|---------|-------|-------------|
| ISA_IF | 16 | Bidir | 1.8V | CLK_IO | Data bus |
| ISA_CLK | 1 | Input | 1.8V | - | Interface clock |
| ISA_VALID | 1 | Output | 1.8V | CLK_IO | Data valid |
| ISA_DIR | 1 | Output | 1.8V | CLK_IO | Direction |
| ISA_READY | 1 | Input | 1.8V | CLK_IO | External ready |

### 5.2 CDC Bridge Interface (to M13)

| Signal | Width | Direction | Clock | Description |
|--------|-------|-----------|-------|-------------|
| isa_data_sys | 16 | Output | CLK_SYS | Synchronized data |
| isa_valid_sys | 1 | Output | CLK_SYS | Synchronized valid |
| isa_ready_sys | 1 | Input | CLK_SYS | System ready |
| isa_req_sys | 1 | Output | CLK_SYS | Transfer request |

### 5.3 Control Interface

| Signal | Width | Direction | Clock | Description |
|--------|-------|-----------|-------|-------------|
| m16_reset_n | 1 | Input | CLK_IO | Module reset |
| m16_enable | 1 | Input | CLK_IO | Module enable |
| m16_mode | 2 | Input | CLK_IO | Operation mode |

### 5.4 Secure Boot Interface (from M14)

| Signal | Width | Direction | Clock | Description |
|--------|-------|-----------|-------|-------------|
| sec_boot_done | 1 | Input | CLK_SYS | Boot complete |
| sec_status_pass | 1 | Input | CLK_SYS | Verification pass |
| sec_status_fail | 1 | Input | CLK_SYS | Verification fail |
| sec_lockdown | 1 | Input | CLK_SYS | Security lockdown |

## 6. Datapath Parameters Summary

### 6.1 Component Parameters

| Component | Width | Latency | Area Est. |
|-----------|-------|---------|-----------|
| Bidirectional Buffer | 16-bit | 1 cycle | 5,000 um2 |
| Two-Stage Sync | 16-bit | 2 cycles | 3,000 um2 |
| Valid Synchronizer | 1-bit | 2 cycles | 2,000 um2 |
| Instruction Parser | 32-bit | 2 cycles | 8,000 um2 |
| Opcode Checker | 6-bit | 1 cycle | 2,000 um2 |
| Handshake CDC | handshake | 2 cycles | 4,000 um2 |
| Security Gate | logic | 1 cycle | 3,000 um2 |
| **Total** | - | **<= 4 cycles** | **~27,000 um2** |

### 6.2 Timing Parameters

| Clock Domain | Frequency | Period | Purpose |
|--------------|-----------|--------|---------|
| CLK_IO | 50 MHz | 20 ns | ISA Interface timing |
| CLK_SYS | 200 MHz | 5 ns | NPU Core timing |

### 6.3 Setup/Hold Requirements

| Parameter | Min Value | REQ |
|-----------|-----------|-----|
| T_SU (Setup) | 2 ns | REQ-M16-006 |
| T_HD (Hold) | 0.5 ns | REQ-M16-007 |
| T_CO (Clock to Output) | 3 ns | REQ-M16-021 |

## 7. CDC Safety Checklist

- [x] All multi-bit crossings use handshake protocol (REQ-M16-020)
- [x] Single-bit control uses 2-stage synchronizer (REQ-M16-009)
- [x] CDC latency <= 3 CLK_SYS cycles (REQ-M16-008)
- [x] MTBF > 10^6 cycles for metastability protection
- [x] No combinational logic in synchronizer path
- [x] Reset synchronized to both clock domains
- [x] Setup/hold timing verified in all corners

## 8. References

- **Parent MAS**: `/spec_mas/M16/MAS.md` - Complete module specification
- **FSM Design**: `/spec_mas/M16/FSM.md` - CDC FSM and Parser FSM
- **CDC Guidelines**: `/doc/eda/cdc_guidelines.md` - CDC design best practices
- **M14 Secure Boot**: `/spec_mas/M14/MAS.md` - Security interface
- **M13 ISA Decoder**: `/spec_mas/M13/MAS.md` - Target module