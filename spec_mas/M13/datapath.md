---
module: M13
type: datapath
status: complete
parent: None
module_type: control
generated: "2026-05-17T17:00:00+08:00"
---

# Datapath Design - M13 ISA Decoder

## 1. Overview

M13 ISA Decoder Datapath 实现自定义 NPU ISA 的指令解码与分发，采用 4-Stage Pipeline 架构，支持 32 条专用推理指令。核心数据通路包括 Instruction Fetch Buffer、Opcode Decode Logic、Operand Extractor 和 Dispatch Router，将解码后的指令分发至 M00-M12 算子单元。

### 1.1 Datapath Key Features

| Feature | Description | Performance |
|---------|-------------|-------------|
| Custom NPU ISA | 32条专用推理指令，固定32-bit编码 | REQ-SW-001 |
| 4-Format Support | V/VI/M/S 四种指令格式 | REQ-SW-001 |
| Decode Pipeline | 4级流水线解码 | 4 cycles fixed latency |
| Dispatch Router | 分发至7个目标算子单元 | 1 cycle routing |
| Branch Handling | BNZ 分支处理 | 2 cycle pipeline flush |

### 1.2 Instruction Decode Mathematical Flow

```
Decode Pipeline:
  Stage 0: Instruction Fetch    -- 从 M16 获取 32-bit 指令
  Stage 1: Opcode Decode        -- 提取 OPCODE[31:26]，识别格式
  Stage 2: Operand Extract      -- 提取寄存器索引、立即数
  Stage 3: Dispatch             -- 分发至目标算子单元

Instruction Format:
  V-Type:  OPCODE(6) | VD(5) | VS1(5) | VS2(5) | VS3(5) | FUNC(6)
  VI-Type: OPCODE(6) | VD(5) | VS1(5) | IMM16(16)
  M-Type:  OPCODE(6) | VD(5) | BASE(5) | SD(5) | OFFSET11(11)
  S-Type:  OPCODE(6) | SD(5) | IMM21(21)
```

## 2. Block Diagram

### 2.1 Top-Level Datapath

```mermaid
graph TB
    subgraph INPUT["Instruction Input"]
        M16[M16 ISA Interface]
        INST_VALID[isa_inst_valid_i]
        INST_DATA[isa_inst_data_i<br/>32-bit]
        PC[isa_pc_i<br/>32-bit]
    end
    
    subgraph STAGE0["Stage 0: Instruction Fetch"]
        IB[Instruction Buffer<br/>32-bit Register]
        PC_REG[PC Register<br/>32-bit]
        PC_INC[PC Incrementer<br/>+1]
    end
    
    subgraph STAGE1["Stage 1: Opcode Decode"]
        OP_EX[Opcode Extractor<br/>inst[31:26]]
        OP_DEC[Opcode Decoder<br/>6-bit LUT]
        FORMAT[Format Detector<br/>V/VI/M/S]
        OP_VALID[Opcode Validator]
    end
    
    subgraph STAGE2["Stage 2: Operand Extract"]
        V_EX[V-Type Extractor]
        VI_EX[VI-Type Extractor]
        M_EX[M-Type Extractor]
        S_EX[S-Type Extractor]
        REG_VALID[Register Validator]
        BNZ_CHECK[BNZ Branch Check]
    end
    
    subgraph STAGE3["Stage 3: Dispatch"]
        TARGET[Target Selector<br/>7 destinations]
        DISPATCH[Dispatch Router]
        HANDSHAKE[Handshake Controller]
    end
    
    subgraph OUTPUT["Decoded Output"]
        DEC_OUT[Decoded Signals<br/>opcode, format, fields]
        OP_DISP[Operator Dispatch<br/>op_valid_o, op_target_o]
    end
    
    subgraph BRANCH["Branch Path"]
        TARGET_CALC[Branch Target Calc<br/>PC + IMM21]
        PIPE_FLUSH[Pipeline Flush<br/>2 cycles]
    end
    
    M16 --> INST_VALID
    INST_VALID --> IB
    INST_DATA --> IB
    PC --> PC_REG
    PC_REG --> PC_INC
    
    IB --> OP_EX
    OP_EX --> OP_DEC
    OP_DEC --> FORMAT
    FORMAT --> OP_VALID
    
    OP_VALID --> V_EX
    OP_VALID --> VI_EX
    OP_VALID --> M_EX
    OP_VALID --> S_EX
    
    V_EX --> REG_VALID
    VI_EX --> REG_VALID
    M_EX --> REG_VALID
    S_EX --> REG_VALID
    
    REG_VALID --> BNZ_CHECK
    BNZ_CHECK --> TARGET_CALC
    TARGET_CALC --> PIPE_FLUSH
    PIPE_FLUSH --> IB
    
    REG_VALID --> TARGET
    TARGET --> DISPATCH
    DISPATCH --> HANDSHAKE
    HANDSHAKE --> DEC_OUT
    HANDSHAKE --> OP_DISP
```

### 2.2 Pipeline Timing Diagram

```
Cycle:  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |...
--------|---|---|---|---|---|---|---|---|---|---|
Stage0: |--[IF]--|--|
        | Fetch instruction from M16
Stage1: |        |--[OD]--|--|
        |         Opcode decode + format detect
Stage2: |                |--[OE]--|--|
        |                 Operand extraction + validation
Stage3: |                        |--[DP]--|--|
        |                         Dispatch to target module
Execute:|                                |--[EW]--...--|
        |                                 Wait for op_done_i
Next:   |                                        |--[IF]--|--|
        |                                         Fetch next instruction

Total Decode Latency: 4 cycles (fixed)
Execute Latency: Variable (1-512 cycles per instruction)
```

## 3. Datapath Components

### 3.1 Stage 0: Instruction Fetch

#### 3.1.1 Instruction Buffer

```verilog
// Instruction Buffer Datapath
module instruction_buffer (
    input  logic        clk_sys,
    input  logic        rst_sys_n,
    input  logic        isa_inst_valid_i,
    input  logic [31:0] isa_inst_data_i,
    input  logic [31:0] isa_pc_i,
    output logic [31:0] inst_out,
    output logic [31:0] pc_out,
    output logic        inst_valid_out
);

    logic [31:0] inst_reg;
    logic [31:0] pc_reg;
    logic        valid_reg;
    
    always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
            inst_reg <= 32'b0;
            pc_reg <= 32'b0;
            valid_reg <= 1'b0;
        end else if (isa_inst_valid_i) begin
            inst_reg <= isa_inst_data_i;
            pc_reg <= isa_pc_i;
            valid_reg <= 1'b1;
        end else begin
            valid_reg <= 1'b0;
        end
    end
    
    assign inst_out = inst_reg;
    assign pc_out = pc_reg;
    assign inst_valid_out = valid_reg;

endmodule
```

#### 3.1.2 PC Incrementer

| Parameter | Value | Description |
|-----------|-------|-------------|
| PC Width | 32 bits | Program Counter |
| Increment | +1 | Sequential execution |
| Branch Offset | IMM21 signed | BNZ relative jump |

### 3.2 Stage 1: Opcode Decode

#### 3.2.1 Opcode Extractor

```verilog
// Opcode Extractor (Bit Field Extraction)
module opcode_extractor (
    input  logic [31:0] inst_in,
    output logic [5:0]  opcode_out,
    output logic        valid_in
);

    // Extract OPCODE from inst[31:26]
    assign opcode_out = inst_in[31:26];
    assign valid_in = (inst_in != 32'b0);

endmodule
```

#### 3.2.2 Opcode Decoder LUT

| OPCODE | Mnemonic | Format | Category | Target |
|--------|----------|--------|----------|--------|
| 0x00 | VADD | V | Vector Arith | M10 |
| 0x01 | VMUL | V | Vector Arith | M10 |
| 0x02 | VSMUL | VI | Vector Arith | M10 |
| 0x03 | VMAC | V | Vector Arith | M10 |
| 0x08 | MLOAD | M | MatMul | M00 |
| 0x09 | MMUL | V | MatMul | M00 |
| 0x10 | VEXP | V | Special | M12 |
| 0x11 | VSQRT_INV | V | Special | M11 |
| 0x18 | VSUM | V | Reduction | M12 |
| 0x20 | VLD | M | Memory | M02 |
| 0x28 | KV_WRITE | V | KV Cache | M09 |
| 0x30 | SADD | S | Scalar | M13 |
| 0x33 | BNZ | S | Control | M13 |
| 0x34 | HALT | S | Control | M13 |

#### 3.2.3 Format Detector Logic

```verilog
// Format Detector
module format_detector (
    input  logic [5:0] opcode,
    output logic [1:0] format,
    output logic       format_valid
);

    // Format encoding: V=00, VI=01, M=10, S=11
    always_comb begin
        case (opcode)
            0x00, 0x01, 0x03, 0x04, 0x05: format = 2'b00; // V-Type
            0x02:                          format = 2'b01; // VI-Type
            0x08, 0x20, 0x21, 0x25, 0x29:  format = 2'b10; // M-Type
            0x0A, 0x24, 0x2A, 0x30-0x34:   format = 2'b11; // S-Type
            default:                       format = 2'b00; // Default V-Type
        endcase
        
        // Format validity check
        format_valid = (opcode <= 6'h34);
    end

endmodule
```

### 3.3 Stage 2: Operand Extract

#### 3.3.1 V-Type Operand Extractor

```verilog
// V-Type Operand Extractor
module v_type_extractor (
    input  logic [31:0] inst,
    output logic [4:0]  vd,      // Destination vector register
    output logic [4:0]  vs1,     // Source vector register 1
    output logic [4:0]  vs2,     // Source vector register 2
    output logic [4:0]  vs3,     // Source vector register 3
    output logic [5:0]  func     // Function code
);

    // V-Type format: OPCODE(6) | VD(5) | VS1(5) | VS2(5) | VS3(5) | FUNC(6)
    assign vd   = inst[25:21];
    assign vs1  = inst[20:16];
    assign vs2  = inst[15:11];
    assign vs3  = inst[10:6];
    assign func = inst[5:0];

endmodule
```

#### 3.3.2 VI-Type Operand Extractor

```verilog
// VI-Type Operand Extractor
module vi_type_extractor (
    input  logic [31:0] inst,
    output logic [4:0]  vd,      // Destination vector register
    output logic [4:0]  vs1,     // Source vector register
    output logic [15:0] imm16    // 16-bit immediate
);

    // VI-Type format: OPCODE(6) | VD(5) | VS1(5) | IMM16(16)
    assign vd    = inst[25:21];
    assign vs1   = inst[20:16];
    assign imm16 = inst[15:0];

endmodule
```

#### 3.3.3 M-Type Operand Extractor

```verilog
// M-Type Operand Extractor
module m_type_extractor (
    input  logic [31:0] inst,
    output logic [4:0]  vd,      // Destination vector register
    output logic [4:0]  base,    // Base address register
    output logic [4:0]  sd,      // Scalar register
    output logic [10:0] offset   // 11-bit offset
);

    // M-Type format: OPCODE(6) | VD(5) | BASE(5) | SD(5) | OFFSET11(11)
    assign vd     = inst[25:21];
    assign base   = inst[20:16];
    assign sd     = inst[15:11];
    assign offset = inst[10:0];

endmodule
```

#### 3.3.4 S-Type Operand Extractor

```verilog
// S-Type Operand Extractor
module s_type_extractor (
    input  logic [31:0] inst,
    output logic [4:0]  sd,      // Destination scalar register
    output logic [20:0] imm21    // 21-bit immediate
);

    // S-Type format: OPCODE(6) | SD(5) | IMM21(21)
    assign sd    = inst[25:21];
    assign imm21 = inst[20:0];

endmodule
```

#### 3.3.5 BNZ Branch Check

| Parameter | Value | Description |
|-----------|-------|-------------|
| BNZ Opcode | 0x33 | Branch if Not Zero |
| Condition | ss != 0 | Scalar register check |
| Branch Offset | IMM21 signed | PC-relative offset |
| Penalty | 2 cycles | Pipeline flush |

### 3.4 Stage 3: Dispatch Router

#### 3.4.1 Target Selector

```verilog
// Target Selector
module target_selector (
    input  logic [5:0]  opcode,
    output logic [3:0]  target_id,
    output logic        is_memory_op,
    output logic        is_control_op
);

    // Target encoding: M00=0, M09=1, M10=2, M11=3, M12=4, M02=5, M13=6
    always_comb begin
        case (opcode)
            0x00-0x05:    target_id = 4'd2;  // M10 (FFN/MatMul)
            0x08-0x0A:    target_id = 4'd0;  // M00 (Systolic Array)
            0x10-0x14:    target_id = 4'd3;  // M11/M12 (Special func)
            0x18-0x1B:    target_id = 4'd4;  // M09/M12 (Reduction)
            0x20-0x25:    target_id = 4'd5;  // M02 (Memory)
            0x28-0x2A:    target_id = 4'd1;  // M09 (KV Cache)
            0x30-0x34:    target_id = 4'd6;  // M13 (Scalar/Control)
            default:      target_id = 4'd0;  // Default
        endcase
        
        is_memory_op = (opcode >= 6'h20 && opcode <= 6'h25);
        is_control_op = (opcode >= 6'h30 && opcode <= 6'h34);
    end

endmodule
```

#### 3.4.2 Dispatch Handshake Protocol

| Step | Signal | Direction | Description |
|------|--------|-----------|-------------|
| 1 | dec_valid_o | Output | Decode complete |
| 2 | op_valid_o | Output | Dispatch request |
| 3 | op_ready_i | Input | Target acknowledge |
| 4 | op_start_o | Output | Execution trigger |
| 5 | op_done_i | Input | Execution complete |

## 4. Pipeline Structure

### 4.1 Pipeline Registers

| Stage | Register | Width | Purpose |
|-------|----------|-------|---------|
| S0 | inst_buf | 32-bit | Instruction storage |
| S0 | pc_reg | 32-bit | Program Counter |
| S1 | opcode_reg | 6-bit | Opcode storage |
| S1 | format_reg | 2-bit | Format type |
| S2 | vd_reg | 5-bit | Destination register |
| S2 | vs1_reg, vs2_reg | 5-bit each | Source registers |
| S2 | imm_reg | 16/21-bit | Immediate value |
| S3 | target_reg | 4-bit | Target module ID |

### 4.2 Pipeline Timing

| Instruction Type | Decode | Execute | Total |
|------------------|--------|---------|-------|
| Vector Arithmetic | 4 cycles | 2 cycles | 6 cycles |
| MatMul (MMUL) | 4 cycles | s_dim cycles | 4 + s_dim |
| Special Function | 4 cycles | 4 cycles | 8 cycles |
| Reduction | 4 cycles | 6 cycles | 10 cycles |
| Memory Access | 4 cycles | 4 cycles | 8 cycles |
| BNZ (taken) | 4 cycles | 3 cycles | 7 cycles |
| BNZ (not taken) | 4 cycles | 1 cycle | 5 cycles |

## 5. Interface Summary

### 5.1 Input Interface (from M16)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| isa_inst_valid_i | 1 | Input | Instruction valid |
| isa_inst_data_i | 32 | Input | 32-bit instruction |
| isa_inst_ready_o | 1 | Output | Ready to receive |
| isa_pc_i | 32 | Input | Program Counter |

### 5.2 Decoded Output Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| dec_valid_o | 1 | Output | Decode valid |
| dec_opcode_o | 6 | Output | Opcode |
| dec_format_o | 2 | Output | Format type |
| dec_vd_o | 5 | Output | Destination register |
| dec_vs1_o | 5 | Output | Source register 1 |
| dec_vs2_o | 5 | Output | Source register 2 |
| dec_imm16_o | 16 | Output | Immediate (VI/M/S) |

### 5.3 Operator Dispatch Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| op_valid_o | 1 | Output | Dispatch valid |
| op_target_o | 4 | Output | Target module ID |
| op_ready_i | 1 | Input | Target ready |
| op_start_o | 1 | Output | Start execution |
| op_done_i | 1 | Input | Execution done |

### 5.4 Control Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| sched_start_i | 1 | Input | Start decode |
| sched_pause_i | 1 | Input | Pause decode |
| sched_abort_i | 1 | Input | Abort decode |
| dec_busy_o | 1 | Output | Decoder busy |
| dec_done_o | 1 | Output | Decode done |
| sec_en_i | 1 | Input | Secure Boot enable |

## 6. Datapath Parameters Summary

### 6.1 Component Parameters

| Component | Width | Count | Latency | Area Est. |
|-----------|-------|-------|---------|-----------|
| Instruction Buffer | 32-bit | 1 | 1 cycle | 2,000 um2 |
| Opcode Decoder | 6-bit LUT | 32 entries | 1 cycle | 5,000 um2 |
| Format Detector | 2-bit | 1 | 1 cycle | 1,000 um2 |
| Operand Extractors | 5-21 bit | 4 types | 1 cycle | 8,000 um2 |
| Target Selector | 4-bit | 7 targets | 1 cycle | 3,000 um2 |
| Dispatch Router | handshake | 7 paths | 1 cycle | 10,000 um2 |
| **Total** | - | - | **4 cycles** | **~29,000 um2** |

### 6.2 Timing Parameters @ 500 MHz

| Parameter | Value | Description |
|-----------|-------|-------------|
| Decode Latency | 4 cycles = 8 ns | Fixed pipeline |
| Dispatch Latency | 1 cycle = 2 ns | Handshake |
| Branch Penalty | 2 cycles = 4 ns | Pipeline flush |
| Max Decode Rate | 125 MIPS | Million Inst Per Second |

## 7. References

- **Parent MAS**: `/spec_mas/M13/MAS.md` - Complete module specification
- **FSM Design**: `/spec_mas/M13/FSM.md` - Decode state machine
- **ISA Overview**: `/doc/isa/overview.md` - Instruction set architecture
- **Module Tree**: `/spec_mas/module_tree.md` - M13 module classification