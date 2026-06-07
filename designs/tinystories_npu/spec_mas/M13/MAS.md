---
module: M13
type: MAS
status: complete
parent: null
module_type: control
chiplet_features: [Custom NPU ISA, Instruction Decode, Operand Extraction, Dispatch to Operators]
generated: "2026-05-17T16:00:00+08:00"
---

# M13: ISA Decoder

## 1. Overview

M13 ISA Decoder 是 TinyStories NPU 的指令解码单元，负责解码自定义 NPU ISA，提取操作码、操作数，并将指令分发给相应的算子执行单元。该模块位于 Main Power Domain (PD_MAIN)，运行于 CLK_SYS 时钟域 (250-500 MHz)，是 NPU 控制流的核心模块。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| Custom NPU ISA | 32条专用推理指令，固定32-bit编码 | REQ-SW-001 |
| Instruction Decode | 4种格式解码：V型、VI型、M型、S型 | REQ-SW-001 |
| Operand Extraction | 向量/标量寄存器索引提取，立即数提取 | REQ-SW-001 |
| Dispatch to Operators | 分发至 M09-M12 算子单元，M00 Systolic Array | REQ-COMPUTE-008 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 可调 |
| Power Domain | PD_MAIN | 0.7-0.9 V，支持 Power Gate |
| Base Address | 0x8009_0000 | Memory Map 中的 ISA Registers 基地址 |

### 1.3 ISA Summary

| Category | Instruction Count | OPCODE Range | Covered Operators |
|----------|-------------------|--------------|-------------------|
| Vector Arithmetic | 6 | 0x00-0x05 | Residual, RMSNorm, SwiGLU, Attention |
| Matrix Multiply | 3 | 0x08-0x0A | MatMul |
| Special Function | 5 | 0x10-0x14 | RMSNorm, RoPE, Softmax, SwiGLU |
| Reduction | 4 | 0x18-0x1B | RMSNorm, Softmax, Sampling |
| Memory Access | 6 | 0x20-0x25 | All operators |
| KV Cache | 3 | 0x28-0x2A | Attention |
| Scalar/Control | 5 | 0x30-0x34 | Loop, Branch |
| **Total** | **32** | | |

### 1.4 Register File Overview

| Register Type | Count | Width | Description |
|---------------|-------|-------|-------------|
| Vector Registers (v0-v31) | 32 | 64 x FP32 = 2048 bit | General vector registers |
| Scalar Registers (s0-s15) | 16 | 32 bit FP32 | Scalar operations, loop count |
| Special Registers | 5 | 8-32 bit | acc, kv_ptr, head_id, s_dim, status |

### 1.5 Use Cases

| Use Case | Phase | Description |
|----------|-------|-------------|
| Prefill Decode | Prefill | Decode batch MatMul, Attention instructions |
| Decode Decode | Decode | Decode single token inference instructions |
| KV Cache Control | Both | Decode KV_WRITE/KV_READ/KV_RESET instructions |
| Branch Handling | Both | Decode BNZ for loop control |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| clk_sys_i | Input | 1 | CLK_SYS | 主系统时钟 (250-500 MHz) |
| rst_sys_n_i | Input | 1 | CLK_SYS | 系统复位，低有效 |
| pg_main_en_i | Input | 1 | CLK_SYS | Power Gate 使能 (from M05) |

#### 2.1.2 ISA Interface (from M16)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| isa_inst_valid_i | Input | 1 | CLK_SYS | 指令输入有效 |
| isa_inst_data_i | Input | 32 | CLK_SYS | 32-bit 指令字 |
| isa_inst_ready_o | Output | 1 | CLK_SYS | 指令接收就绪 |
| isa_pc_i | Input | 32 | CLK_SYS | Program Counter (PC) |
| isa_pc_update_o | Output | 1 | CLK_SYS | PC 更新请求 |

#### 2.1.3 Decoded Output Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| dec_valid_o | Output | 1 | CLK_SYS | 解码输出有效 |
| dec_opcode_o | Output | 6 | CLK_SYS | 操作码 (6-bit) |
| dec_format_o | Output | 2 | CLK_SYS | 指令格式 (V=00, VI=01, M=10, S=11) |
| dec_vd_o | Output | 5 | CLK_SYS | 目标向量寄存器索引 |
| dec_vs1_o | Output | 5 | CLK_SYS | 源向量寄存器1索引 |
| dec_vs2_o | Output | 5 | CLK_SYS | 源向量寄存器2索引 |
| dec_vs3_o | Output | 5 | CLK_SYS | 源向量寄存器3索引 (V型) |
| dec_sd_o | Output | 5 | CLK_SYS | 目标标量寄存器索引 |
| dec_imm16_o | Output | 16 | CLK_SYS | 16-bit 立即数 (VI型) |
| dec_imm21_o | Output | 21 | CLK_SYS | 21-bit 立即数 (S型) |
| dec_base_o | Output | 5 | CLK_SYS | 基地址寄存器索引 (M型) |
| dec_offset_o | Output | 11 | CLK_SYS | 地址偏移 (M型) |
| dec_func_o | Output | 6 | CLK_SYS | 功能码 (V型) |

#### 2.1.4 Operator Dispatch Interface (to M09-M12)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| op_valid_o | Output | 1 | CLK_SYS | 算子分发有效 |
| op_target_o | Output | 4 | CLK_SYS | 目标算子单元 (M00=0, M09=1, M10=2, M11=3, M12=4) |
| op_ready_i | Input | 1 | CLK_SYS | 算子单元就绪 |
| op_start_o | Output | 1 | CLK_SYS | 算子执行启动 |
| op_done_i | Input | 1 | CLK_SYS | 算子执行完成 |

#### 2.1.5 Systolic Array Interface (to M00)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sa_cmd_valid_o | Output | 1 | CLK_SYS | Systolic Array 命令有效 |
| sa_op_o | Output | 2 | CLK_SYS | 操作类型 (0=MLOAD, 1=MMUL, 2=MSET_DIM) |
| sa_ready_i | Input | 1 | CLK_SYS | Systolic Array 就绪 |

#### 2.1.6 Memory Interface (to M02/M03)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| mem_addr_o | Output | 32 | CLK_SYS | 内存访问地址 |
| mem_wen_o | Output | 1 | CLK_SYS | 写使能 |
| mem_valid_o | Output | 1 | CLK_SYS | 内存访问有效 |
| mem_ready_i | Input | 1 | CLK_SYS | 内存就绪 |

#### 2.1.7 Secure Boot Interface (from M14)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sec_valid_i | Input | 1 | CLK_SYS | Secure Boot 验证有效 |
| sec_en_i | Input | 1 | CLK_SYS | Secure Boot 启用标志 REQ-SEC-001 |

#### 2.1.8 Control Interface (from M08 Scheduler)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sched_start_i | Input | 1 | CLK_SYS | 解码启动 |
| sched_pause_i | Input | 1 | CLK_SYS | 解码暂停 |
| sched_abort_i | Input | 1 | CLK_SYS | 解码终止 |
| dec_done_o | Output | 1 | CLK_SYS | 解码完成 |
| dec_busy_o | Output | 1 | CLK_SYS | 解码忙碌 |

### 2.2 Register Map (Base: 0x8009_0000)

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | ISA_CTRL | RW | 32 | ISA Decoder 控制寄存器 |
| 0x0004 | ISA_INST | W | 32 | 当前指令寄存器 |
| 0x0008 | ISA_OP | R | 32 | 解码后的操作码 |
| 0x000C | ISA_RD | R | 32 | 目标寄存器 |
| 0x0010 | ISA_RS1 | R | 32 | 源寄存器1 |
| 0x0014 | ISA_RS2 | R | 32 | 源寄存器2 |
| 0x0018 | ISA_IMM | R | 32 | 立即数 |
| 0x001C | ISA_PC | RW | 32 | Program Counter |
| 0x0020 | ISA_STATUS | R | 32 | ISA Decoder 状态寄存器 |
| 0x0024 | ISA_IRQ_EN | RW | 32 | 中断使能寄存器 |
| 0x0028 | ISA_IRQ_CLR | RW | 32 | 中断清除寄存器 |
| 0x002C | ISA_ERROR | R | 32 | 错误状态寄存器 |

#### 2.2.1 Register Bit Definitions

**ISA_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | dec_enable | 解码器使能 |
| [1] | inst_fetch_en | 指令获取使能 |
| [2] | op_dispatch_en | 算子分发使能 |
| [3] | branch_en | 分支跳转使能 |
| [4] | sec_boot_check | Secure Boot 检查使能 REQ-SEC-001 |
| [5] | start | 解码启动触发 |
| [6] | abort | 解码终止触发 |
| [7:31] | reserved | 保留 |

**ISA_STATUS (0x0020)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | busy | 解码忙碌标志 |
| [1] | done | 解码完成标志 |
| [2] | error | 错误标志 |
| [3] | branch_taken | 分支跳转发生 |
| [4:7] | current_format | 当前指令格式 (V=0, VI=1, M=2, S=3) |
| [8:13] | current_opcode | 当前操作码 |
| [14:31] | reserved | 保留 |

**ISA_ERROR (0x002C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | invalid_opcode | 无效操作码 |
| [1] | invalid_format | 无效指令格式 |
| [2] | invalid_reg | 无效寄存器索引 |
| [3] | secure_boot_fail | Secure Boot 验证失败 REQ-SEC-001 |
| [4:31] | reserved | 保留 |

## 3. Functional Description

### 3.1 ISA Encoding Format

固定32-bit编码，支持4种指令格式：

#### 3.1.1 V-Type (Vector Triple Operand)

```
31      26 25    21 20    16 15    11 10     6 5       0
+---------+--------+--------+--------+--------+--------+
| OPCODE  |   VD   |  VS1   |  VS2   |  VS3   |  FUNC  |
|  6 bit  |  5 bit |  5 bit |  5 bit |  5 bit |  6 bit |
+---------+--------+--------+--------+--------+--------+

VD: Destination vector register (v0-v31)
VS1: Source vector register 1
VS2: Source vector register 2
VS3: Source vector register 3 (optional, FUNC extension)
FUNC: Function code (extension)
```

适用指令：VADD, VMUL, VMAC, VSUB, VCOPY, VEXP, VSQRT_INV, VSIN, VCOS, VSIGMOID, VSUM, VMAX, VDOT, VARGMAX, KV_WRITE

#### 3.1.2 VI-Type (Vector + Immediate)

```
31      26 25    21 20    16 15                        0
+---------+--------+--------+---------------------------+
| OPCODE  |   VD   |  VS1   |          IMM16            |
|  6 bit  |  5 bit |  5 bit |          16 bit           |
+---------+--------+--------+---------------------------+

VD: Destination vector register
VS1: Source vector register
IMM16: 16-bit immediate value (signed or unsigned)
```

适用指令：VSMUL

#### 3.1.3 M-Type (Memory Access)

```
31      26 25    21 20    16 15    11 10                0
+---------+--------+--------+--------+------------------+
| OPCODE  |   VD   |  BASE  |   SD   |    OFFSET11      |
|  6 bit  |  5 bit |  5 bit |  5 bit |    11 bit        |
+---------+--------+--------+--------+------------------+

VD: Destination vector register (for VLD)
BASE: Base address register (s0-s15)
SD: Scalar register for offset/index
OFFSET11: 11-bit address offset (256-byte aligned for vectors)
```

适用指令：VLD, VST, SLD, SST, MLOAD, KV_READ, ROPE_LD

#### 3.1.4 S-Type (Scalar/Control)

```
31      26 25    21 20                                  0
+---------+--------+--------------------------------------+
| OPCODE  |   SD   |               IMM21                  |
|  6 bit  |  5 bit |               21 bit                 |
+---------+--------+--------------------------------------+

SD: Destination scalar register (s0-s15)
IMM21: 21-bit immediate value (for BNZ: signed branch offset)
```

适用指令：SADD, SMUL, SDIV, BNZ, HALT, MSET_DIM, KV_RESET, EMBED

### 3.2 Decode Pipeline

#### 3.2.1 Pipeline Stages

| Stage | Operation | Latency | Description |
|-------|-----------|---------|-------------|
| S0: Instruction Fetch | IF | 1 cycle | 从 M16 ISA Interface 获取 32-bit 指令 |
| S1: Opcode Decode | OD | 1 cycle | 提取 OPCODE[31:26]，识别指令格式 |
| S2: Operand Extract | OE | 1 cycle | 提取寄存器索引、立即数 |
| S3: Dispatch | DP | 1 cycle | 分发至目标算子单元 |
| S4: Execute Wait | EW | Variable | 等待算子执行完成 |

**Total Decode Latency**: 4 cycles (fixed)
**Execute Latency**: Variable per instruction (see Section 4.2)

#### 3.2.2 Decode Flow

```
Instruction Fetch (M16 ISA Interface)
    |
    v
Opcode Decode:
    - Extract OPCODE[31:26]
    - Determine format (V/VI/M/S)
    |
    v
Format Decode:
    - V-Type: Extract VD, VS1, VS2, VS3, FUNC
    - VI-Type: Extract VD, VS1, IMM16
    - M-Type: Extract VD, BASE, SD, OFFSET11
    - S-Type: Extract SD, IMM21
    |
    v
Target Selection:
    | OPCODE Range | Target Module |
    |--------------|---------------|
    | 0x00-0x05    | M09/M10/M11 (Vector ops) |
    | 0x08-0x0A    | M00 (Systolic Array) |
    | 0x10-0x14    | M11/M12 (Special func) |
    | 0x18-0x1B    | M09/M12 (Reduction) |
    | 0x20-0x25    | M02/M03 (Memory) |
    | 0x28-0x2A    | M09 (KV Cache) |
    | 0x30-0x34    | M13 (Scalar/Control) |
    |
    v
Dispatch to Target Module
    |
    v
Execute Wait (until op_done_i)
    |
    v
Next Instruction
```

#### 3.2.3 Opcode Decode Logic

| OPCODE | Mnemonic | Format | Category | Target Module |
|--------|----------|--------|----------|---------------|
| 0x00 | VADD | V | Vector Arith | M10 |
| 0x01 | VMUL | V | Vector Arith | M10 |
| 0x02 | VSMUL | VI | Vector Arith | M10 |
| 0x03 | VMAC | V | Vector Arith | M10 |
| 0x04 | VSUB | V | Vector Arith | M10 |
| 0x05 | VCOPY | V | Vector Arith | M10 |
| 0x08 | MLOAD | M | MatMul | M00 |
| 0x09 | MMUL | V | MatMul | M00 |
| 0x0A | MSET_DIM | S | MatMul | M00 |
| 0x10 | VEXP | V | Special Func | M12 |
| 0x11 | VSQRT_INV | V | Special Func | M11 |
| 0x12 | VSIN | V | Special Func | M11 |
| 0x13 | VCOS | V | Special Func | M11 |
| 0x14 | VSIGMOID | V | Special Func | M12 |
| 0x18 | VSUM | V | Reduction | M12 |
| 0x19 | VMAX | V | Reduction | M12 |
| 0x1A | VDOT | V | Reduction | M09 |
| 0x1B | VARGMAX | V | Reduction | M12 |
| 0x20 | VLD | M | Memory | M02 |
| 0x21 | VST | M | Memory | M02 |
| 0x22 | SLD | M | Memory | M02 |
| 0x23 | SST | M | Memory | M02 |
| 0x24 | EMBED | S | Memory | M02 |
| 0x25 | ROPE_LD | M | Memory | M02 |
| 0x28 | KV_WRITE | V | KV Cache | M09 |
| 0x29 | KV_READ | M | KV Cache | M09 |
| 0x2A | KV_RESET | S | KV Cache | M09 |
| 0x30 | SADD | S | Scalar | M13 |
| 0x31 | SMUL | S | Scalar | M13 |
| 0x32 | SDIV | S | Scalar | M13 |
| 0x33 | BNZ | S | Control | M13 |
| 0x34 | HALT | S | Control | M13 |

### 3.3 Branch Handling

#### 3.3.1 BNZ Instruction

BNZ (Branch if Not Zero) 是唯一的分支指令：

| Parameter | Value | Description |
|-----------|-------|-------------|
| OPCODE | 0x33 | Branch opcode |
| Format | S-Type | SD + IMM21 |
| Condition | ss != 0 | Scalar register not zero |
| Offset | IMM21 signed | PC-relative branch offset |
| Latency | 1 cycle (not taken) | No branch penalty |
| Latency | 3 cycles (taken) | 2 cycle pipeline flush |

Branch Target Calculation:
```
branch_target = PC + IMM21 (signed offset)
```

#### 3.3.2 Branch Pipeline

```
BNZ Decode:
    |
    v
Check ss register value
    |
    +-- ss == 0 --> No branch, PC = PC + 1
    |
    +-- ss != 0 --> Branch taken
        |
        v
    Pipeline Flush (2 cycles)
        |
        v
    PC = PC + IMM21
        |
        v
    Resume Instruction Fetch
```

### 3.4 Secure Boot Integration

REQ-SEC-001 要求 Secure Boot 验证：

| Stage | Operation | Description |
|-------|-----------|-------------|
| Boot | Verify Firmware | M14 验证固件签名 |
| Enable | sec_en_i | M14 发送验证成功信号 |
| Decode | Check sec_en_i | M13 检查 Secure Boot 使能 |
| Execute | Normal | 正常解码执行 |

Secure Boot Fail Handling:
```
if sec_en_i == 0:
    - Set ISA_ERROR[3] = 1 (secure_boot_fail)
    - Halt decoder
    - Wait for M14 re-verification
```

### 3.5 Instruction Dispatch

#### 3.5.1 Dispatch Protocol

| Step | Operation | Handshake |
|------|-----------|-----------|
| 1 | Decode complete | dec_valid_o = 1 |
| 2 | Select target | op_target_o = target_module |
| 3 | Request dispatch | op_valid_o = 1 |
| 4 | Target acknowledge | op_ready_i = 1 |
| 5 | Start execution | op_start_o = 1 |
| 6 | Wait completion | op_done_i = 1 |
| 7 | Next instruction | PC = PC + 1 |

#### 3.5.2 Target Module Dispatch

| Target | Module | Dispatch Interface |
|--------|--------|--------------------|
| M00 | Systolic Array | sa_cmd_valid_o, sa_op_o |
| M02 | SRAM Scratchpad | mem_addr_o, mem_wen_o, mem_valid_o |
| M09 | Attention Unit | op_valid_o (target=1) |
| M10 | FFN/MatMul Unit | op_valid_o (target=2) |
| M11 | RMSNorm/RoPE Unit | op_valid_o (target=3) |
| M12 | SoftMax Unit | op_valid_o (target=4) |

## 4. ISA Encoding Table

### 4.1 Complete Instruction Encoding

| OPCODE | Mnemonic | Format | Fields | Latency (cycles) |
|--------|----------|--------|--------|------------------|
| 0x00 | VADD | V | vd, vs1, vs2, func | 2 |
| 0x01 | VMUL | V | vd, vs1, vs2, func | 2 |
| 0x02 | VSMUL | VI | vd, vs1, imm16 | 2 |
| 0x03 | VMAC | V | vd, vs1, vs2, func | 2 |
| 0x04 | VSUB | V | vd, vs1, vs2, func | 2 |
| 0x05 | VCOPY | V | vd, vs1, func | 1 |
| 0x08 | MLOAD | M | vd, base, sd, offset11 | 4 |
| 0x09 | MMUL | V | vd, vs1, base, func | s_dim |
| 0x0A | MSET_DIM | S | sd, imm21 | 1 |
| 0x10 | VEXP | V | vd, vs1, func | 4 |
| 0x11 | VSQRT_INV | V | vd, vs1, func | 4 |
| 0x12 | VSIN | V | vd, vs1, func | 4 |
| 0x13 | VCOS | V | vd, vs1, func | 4 |
| 0x14 | VSIGMOID | V | vd, vs1, func | 4 |
| 0x18 | VSUM | V | vd, vs1, func | 6 |
| 0x19 | VMAX | V | vd, vs1, func | 6 |
| 0x1A | VDOT | V | vd, vs1, vs2, func | 4 |
| 0x1B | VARGMAX | V | vd, vs1, func | 6 |
| 0x20 | VLD | M | vd, base, sd, offset11 | 4 |
| 0x21 | VST | M | vd, base, sd, offset11 | 4 |
| 0x22 | SLD | M | sd, base, offset11 | 4 |
| 0x23 | SST | M | ss, base, offset11 | 4 |
| 0x24 | EMBED | S | vd, sd, imm21 | 4 |
| 0x25 | ROPE_LD | M | vcos, vsin, sd, offset11 | 4 |
| 0x28 | KV_WRITE | V | vs_k, vs_v, func | 4 |
| 0x29 | KV_READ | M | vk, vv, sd, offset11 | 4 |
| 0x2A | KV_RESET | S | sd, imm21 | 1 |
| 0x30 | SADD | S | sd, ss1, imm21 | 1 |
| 0x31 | SMUL | S | sd, ss1, imm21 | 2 |
| 0x32 | SDIV | S | sd, ss1, imm21 | 8 |
| 0x33 | BNZ | S | ss, imm21 | 1 (not taken) / 3 (taken) |
| 0x34 | HALT | S | - | 1 |

### 4.2 Instruction Category Summary

#### 4.2.1 Vector Arithmetic (OPCODE 0x00-0x05)

| Instruction | Semantics | Covered Operator |
|-------------|-----------|------------------|
| VADD vd, vs1, vs2 | vd[i] = vs1[i] + vs2[i] | Residual |
| VMUL vd, vs1, vs2 | vd[i] = vs1[i] * vs2[i] | SwiGLU, RoPE |
| VSMUL vd, vs1, sd | vd[i] = vs1[i] * sd | RMSNorm, Softmax |
| VMAC vd, vs1, vs2 | vd[i] += vs1[i] * vs2[i] | Attention weighted sum |
| VSUB vd, vs1, vs2 | vd[i] = vs1[i] - vs2[i] | Softmax (subtract max) |
| VCOPY vd, vs1 | vd[i] = vs1[i] | General |

#### 4.2.2 Matrix Multiply (OPCODE 0x08-0x0A)

| Instruction | Semantics | Covered Operator |
|-------------|-----------|------------------|
| MLOAD base, row_idx | Load 64xFP32 to MAC array row buffer | MatMul preload |
| MMUL vd, vs1, base | vd[i] = dot(W[i], vs1), i=0..s_dim-1 | MatMul core |
| MSET_DIM imm | s_dim = imm | MatMul config |

#### 4.2.3 Special Function (OPCODE 0x10-0x14)

| Instruction | Semantics | Covered Operator |
|-------------|-----------|------------------|
| VEXP vd, vs1 | vd[i] = exp(vs1[i]) | Softmax |
| VSQRT_INV vd, vs1 | vd[i] = 1/sqrt(vs1[i]) | RMSNorm |
| VSIN vd, vs1 | vd[i] = sin(vs1[i]) | RoPE |
| VCOS vd, vs1 | vd[i] = cos(vs1[i]) | RoPE |
| VSIGMOID vd, vs1 | vd[i] = sigmoid(vs1[i]) | SwiGLU |

#### 4.2.4 Reduction (OPCODE 0x18-0x1B)

| Instruction | Semantics | Covered Operator |
|-------------|-----------|------------------|
| VSUM sd, vs1 | sd = sum(vs1[0..63]) | RMSNorm, Softmax |
| VMAX sd, vs1 | sd = max(vs1[0..63]) | Softmax (numerical stability) |
| VDOT sd, vs1, vs2 | sd = sum(vs1[i] * vs2[i]) | Attention (Q dot K) |
| VARGMAX sd, vs1 | sd = argmax(vs1[0..63]) | Sampling |

#### 4.2.5 Memory Access (OPCODE 0x20-0x25)

| Instruction | Semantics | Latency |
|-------------|-----------|---------|
| VLD vd, [base + offset*256] | Load 64xFP32 from SRAM | 4 cycles |
| VST vs1, [base + offset*256] | Store 64xFP32 to SRAM | 4 cycles |
| SLD sd, [base + imm] | Load scalar | 4 cycles |
| SST ss, [base + imm] | Store scalar | 4 cycles |
| EMBED vd, sd | vd = embedding_table[sd] | 4 cycles |
| ROPE_LD vcos, vsin, sd | Load cos/sin for position sd | 4 cycles |

#### 4.2.6 KV Cache (OPCODE 0x28-0x2A)

| Instruction | Semantics | Covered Operator |
|-------------|-----------|------------------|
| KV_WRITE vs_k, vs_v | kv_cache[head_id][kv_ptr] = (vs_k, vs_v) | Attention KV update |
| KV_READ vk, vv, sd | Read kv_cache[head_id][sd] | Attention KV read |
| KV_RESET | kv_ptr = 0 | KV Cache reset |

#### 4.2.7 Scalar/Control (OPCODE 0x30-0x34)

| Instruction | Semantics | Latency |
|-------------|-----------|---------|
| SADD sd, ss1, ss2 | sd = ss1 + ss2 | 1 cycle |
| SMUL sd, ss1, ss2 | sd = ss1 * ss2 | 2 cycles |
| SDIV sd, ss1, ss2 | sd = ss1 / ss2 | 8 cycles |
| BNZ ss, label | if ss != 0: PC = PC + offset | 1/3 cycles |
| HALT | Stop execution, status.done = 1 | 1 cycle |

## 5. Timing

### 5.1 Decode Pipeline Timing

| Stage | Operation | Latency @ 500 MHz | Description |
|-------|-----------|-------------------|-------------|
| S0: IF | Instruction Fetch | 2 ns (1 cycle) | 从 M16 获取指令 |
| S1: OD | Opcode Decode | 2 ns (1 cycle) | 操作码识别 |
| S2: OE | Operand Extract | 2 ns (1 cycle) | 寄存器/立即数提取 |
| S3: DP | Dispatch | 2 ns (1 cycle) | 分发至目标模块 |
| **Total Decode** | | **8 ns (4 cycles)** | 固定延迟 |

### 5.2 Instruction Execution Timing

| Instruction Category | Average Latency | Range | Description |
|---------------------|-----------------|-------|-------------|
| Vector Arithmetic | 2 cycles | 1-2 cycles | VADD, VMUL, VSUB, VCOPY |
| Matrix Multiply | variable | 1-s_dim cycles | MMUL 依赖 s_dim |
| Special Function | 4 cycles | 4 cycles | VEXP, VSIN, VCOS, etc. |
| Reduction | 6 cycles | 4-6 cycles | VSUM, VMAX, VARGMAX |
| Memory Access | 4 cycles | 4-8 cycles | VLD/VST, SRAM/ROM |
| KV Cache | 4 cycles | 4 cycles | KV_WRITE, KV_READ |
| Scalar | 2 cycles | 1-8 cycles | SADD, SMUL, SDIV |
| Control | 1 cycle | 1-3 cycles | BNZ (not taken/taken) |

### 5.3 Branch Timing

| Branch Condition | Latency | Pipeline Impact |
|-------------------|---------|-----------------|
| BNZ not taken (ss == 0) | 1 cycle | No penalty |
| BNZ taken (ss != 0) | 3 cycles | 2 cycle pipeline flush |

### 5.4 MatMul Timing (Variable)

| s_dim Value | MMUL Latency | Total MatMul Cycles |
|-------------|--------------|---------------------|
| 32 | 32 cycles | MSET_DIM(1) + MLOAD(4x32) + MMUL(32) = 161 cycles |
| 64 | 64 cycles | MSET_DIM(1) + MLOAD(4x64) + MMUL(64) = 321 cycles |
| 256 | 256 cycles | MSET_DIM(1) + MLOAD(4x256) + MMUL(256) = 1281 cycles |
| 512 | 512 cycles | MSET_DIM(1) + MLOAD(4x512) + MMUL(512) = 2561 cycles |

### 5.5 DVFS Impact

| Operating Point | Frequency | Decode Latency | Memory Latency |
|-----------------|-----------|----------------|----------------|
| OP0 (High) | 500 MHz | 8 ns (4 cycles) | 8 ns (4 cycles) |
| OP1 (Low) | 250 MHz | 16 ns (4 cycles) | 16 ns (4 cycles) |

### 5.6 Throughput Analysis

| Metric | Value @ 500 MHz | Description |
|--------|-----------------|-------------|
| Max Decode Rate | 125 MIPS | 125 Million Instructions Per Second |
| Average CPI | ~10 cycles | 平均每指令周期数 (含执行) |
| Effective Throughput | ~12.5 MIPS | 实际指令吞吐量 |

### 5.7 Memory Access Priority

REQ-MEM-002 定义内存访问优先级：

| Priority | Master | Use Case |
|----------|--------|----------|
| 2 | M13 (ISA Decoder) | Instruction fetch | 优先级低于计算单元 |

## 6. Implementation Notes

### 6.1 Design Considerations

1. **Fixed 32-bit Encoding**: 简化解码逻辑，减少硬件复杂度。

2. **4 Format Support**: V/VI/M/S 四种格式覆盖所有算子需求。

3. **Vector Width 64**: 对应 dim=64，与 TinyStories 模型架构一致。

4. **Variable Latency Handling**: MMUL 等指令延迟可变，需等待 op_done_i。

5. **Secure Boot Integration**: REQ-SEC-001 要求启动时验证固件。

### 6.2 Integration Requirements

| Interface | Target Module | Protocol | Description |
|-----------|---------------|----------|-------------|
| ISA Interface | M16 | Custom handshake | Instruction I/O |
| Secure Boot | M14 | Control | Secure Boot verify |
| Systolic Array | M00 | Custom handshake | MatMul dispatch |
| SRAM | M02 | Memory access | VLD/VST/SLD/SST |
| Attention | M09 | Custom handshake | Attention ops |
| FFN/MatMul | M10 | Custom handshake | Vector ops |
| RMSNorm/RoPE | M11 | Custom handshake | Special func |
| SoftMax | M12 | Custom handshake | Reduction, exp |
| Scheduler | M08 | Control | Decode scheduling |
| Power Manager | M05 | Power | DVFS, Power Gate |

### 6.3 Verification Requirements

| Test Category | Description | Coverage Target |
|---------------|-------------|-----------------|
| Opcode Decode | 所有32条指令正确解码 | 100% opcode coverage |
| Format Decode | 4种格式正确解析 | 100% format coverage |
| Operand Extract | 寄存器索引、立即数提取正确 | 100% field coverage |
| Branch | BNZ taken/not taken | All branch conditions |
| Dispatch | 正确分发至目标模块 | All target modules |
| Secure Boot | M14 验证集成 | REQ-SEC-001 |
| Pipeline | Decode 流水线正确性 | All pipeline stages |

### 6.4 Power Budget Allocation

| Domain | Budget @ OP0 | Budget @ OP1 | Allocation |
|--------|-------------|-------------|------------|
| Decode Logic | 20 mW | 10 mW | Opcode/Operand decode |
| Dispatch Logic | 15 mW | 7.5 mW | Target selection |
| Control Logic | 10 mW | 5 mW | PC, branch handling |
| Register File | 5 mW | 2.5 mW | ISA registers |
| **Total** | **50 mW** | **25 mW** | REQ-PWR-001 contribution |

### 6.5 Physical Design Requirements

| Requirement | Value | Description |
|-------------|-------|-------------|
| Decode Logic Area | < 0.2 mm² | Opcode + Operand decode |
| Register File Area | < 0.1 mm² | ISA Registers |
| Control Logic Area | < 0.1 mm² | PC, branch |

### 6.6 Testability (DFT)

| Feature | Description |
|---------|-------------|
| Opcode Scan | 可扫描测试所有 opcode 解码路径 |
| Format Scan | 可扫描测试4种格式解码 |
| Register BIST | ISA Register 自测试 |
| Branch Test | 可注入 BNZ 条件测试 |

### 6.7 Quality Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| Decode Accuracy | 100% | 所有指令正确解码 |
| Dispatch Latency | <= 4 cycles | 分发延迟 |
| Branch Penalty | 2 cycles | BNZ taken pipeline flush |

## 7. Dependencies

| Module | Dependency Type | Description |
|--------|-----------------|-------------|
| M16 ISA Interface | Input | 指令获取 |
| M14 Secure Boot | Control | 固件验证 REQ-SEC-001 |
| M00 Systolic Array | Dispatch | MatMul 指令执行 |
| M02 SRAM Scratchpad | Memory | VLD/VST 内存访问 |
| M09 Attention Unit | Dispatch | Attention/KV Cache 指令 |
| M10 FFN/MatMul Unit | Dispatch | Vector 算术指令 |
| M11 RMSNorm/RoPE Unit | Dispatch | 特殊函数指令 |
| M12 SoftMax Unit | Dispatch | Reduction/Exp 指令 |
| M08 Scheduler | Control | 解码调度 |
| M05 Power Manager | Power | DVFS, Power Gate |
| M06 Clock Manager | Clock | CLK_SYS 时钟源 |