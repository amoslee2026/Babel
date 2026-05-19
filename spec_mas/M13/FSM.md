---
module: M13
type: FSM
status: complete
parent: M13
fsm_type: Instruction Decode FSM (Fetch -> Decode -> Dispatch)
generated: "2026-05-17T16:00:00+08:00"
---

# M13: Instruction Decode FSM

## 1. FSM Overview

M13 Instruction Decode FSM 控制 ISA Decoder 的指令获取、解码和分发流程。该 FSM 实现 Fetch -> Decode -> Dispatch 的 4 级流水线状态机，支持 32 条 NPU 专用指令的解码和分发。

### 1.1 FSM Architecture

| Parameter | Value | Description |
|-----------|-------|-------------|
| State Count | 8 | IDLE, FETCH, OPCODE_DECODE, OPERAND_EXTRACT, DISPATCH, EXECUTE_WAIT, BRANCH_TAKEN, ERROR |
| Clock Domain | CLK_SYS | 250-500 MHz |
| Power Domain | PD_MAIN | 0.7-0.9 V |
| Pipeline Depth | 4 stages | Fixed decode latency |

### 1.2 FSM Purpose

| Function | Description |
|----------|-------------|
| Instruction Fetch | 从 M16 ISA Interface 获取 32-bit 指令 |
| Format Detection | 识别指令格式 (V/VI/M/S) |
| Operand Extraction | 提取寄存器索引、立即数 |
| Target Dispatch | 分发至目标算子单元 |
| Branch Handling | BNZ 分支处理，pipeline flush |
| Error Detection | 无效 opcode/format/register 检测 |

## 2. State Definitions

### 2.1 State Summary

| State ID | State Name | Description | Duration |
|----------|------------|-------------|----------|
| S0 | IDLE | 空闲状态，等待启动 | Wait for sched_start_i |
| S1 | FETCH | 指令获取，从 M16 读取 | 1 cycle |
| S2 | OPCODE_DECODE | 操作码解码，格式识别 | 1 cycle |
| S3 | OPERAND_EXTRACT | 操作数提取 | 1 cycle |
| S4 | DISPATCH | 分发至目标模块 | 1 cycle |
| S5 | EXECUTE_WAIT | 等待算子执行完成 | Variable (op_done_i) |
| S6 | BRANCH_TAKEN | 分支跳转处理 | 2 cycles (pipeline flush) |
| S7 | ERROR | 错误状态，等待清除 | Wait for abort/reset |

### 2.2 State Encoding

```
State Encoding (3-bit):
S0: IDLE          = 000
S1: FETCH         = 001
S2: OPCODE_DECODE = 010
S3: OPERAND_EXTRACT = 011
S4: DISPATCH      = 100
S5: EXECUTE_WAIT  = 101
S6: BRANCH_TAKEN  = 110
S7: ERROR         = 111
```

## 3. State Transition Diagram

### 3.1 Main FSM Flow

```
                    +-------+
                    | IDLE  |
                    |  S0   |
                    +-------+
                        |
                        | sched_start_i == 1
                        v
                    +-------+
                    | FETCH |
                    |  S1   |
                    +-------+
                        |
                        | isa_inst_valid_i == 1
                        v
              +------------------+
              | OPCODE_DECODE    |
              |      S2          |
              +------------------+
                        |
            +-----------+-----------+
            |                       |
            | invalid_opcode        | valid opcode
            |                       |
            v                       v
      +---------+           +------------------+
      | ERROR   |           | OPERAND_EXTRACT  |
      |   S7    |           |       S3         |
      +---------+           +------------------+
                                    |
                        +-----------+-----------+
                        |                       |
                        | BNZ + ss != 0          | Non-branch / ss == 0
                        |                       |
                        v                       v
                +-------------+           +----------+
                | BRANCH_TAKEN|           | DISPATCH |
                |     S6      |           |    S4    |
                +-------------+           +----------+
                        |                       |
                        | 2 cycles flush        | op_ready_i == 1
                        |                       |
                        v                       v
                    +-------+           +--------------+
                    | FETCH |           | EXECUTE_WAIT |
                    |  S1   |           |      S5      |
                    +-------+           +--------------+
                        |                       |
                        |                       | op_done_i == 1
                        |                       |
                        +-----------------------+
                        |
                        | sched_pause_i == 1 -> IDLE
                        | sched_abort_i == 1 -> IDLE
                        | HALT -> IDLE
                        | else -> FETCH (next instruction)
                        v
                    +-------+
                    | IDLE  |
                    |  S0   |
                    +-------+
```

### 3.2 Branch FSM Sub-flow

```
BNZ Decode (S3: OPERAND_EXTRACT):
    |
    +-- Check ss register
    |
    +-- ss == 0 --> No branch (continue to S4: DISPATCH)
    |
    +-- ss != 0 --> Branch taken (S6: BRANCH_TAKEN)
        |
        v
    S6: BRANCH_TAKEN (Cycle 1):
        - Flush pipeline
        - Calculate branch_target = PC + IMM21
        |
        v
    S6: BRANCH_TAKEN (Cycle 2):
        - Update PC = branch_target
        - Clear pipeline registers
        |
        v
    S1: FETCH (Resume from new PC)
```

## 4. State Transition Table

### 4.1 Complete Transition Matrix

| Current State | Condition | Next State | Action |
|---------------|-----------|------------|--------|
| S0: IDLE | sched_start_i == 1 | S1: FETCH | Start decode, set busy=1 |
| S0: IDLE | sched_start_i == 0 | S0: IDLE | Remain idle |
| S1: FETCH | isa_inst_valid_i == 1 | S2: OPCODE_DECODE | Store instruction, increment PC |
| S1: FETCH | isa_inst_valid_i == 0 | S1: FETCH | Wait for instruction |
| S2: OPCODE_DECODE | opcode valid | S3: OPERAND_EXTRACT | Decode opcode, detect format |
| S2: OPCODE_DECODE | invalid_opcode | S7: ERROR | Set error flag, halt |
| S3: OPERAND_EXTRACT | BNZ && ss != 0 | S6: BRANCH_TAKEN | Branch taken path |
| S3: OPERAND_EXTRACT | Non-BNZ || ss == 0 | S4: DISPATCH | Normal decode path |
| S3: OPERAND_EXTRACT | invalid_format/reg | S7: ERROR | Set error flag, halt |
| S4: DISPATCH | op_ready_i == 1 | S5: EXECUTE_WAIT | Dispatch to target, start op |
| S4: DISPATCH | op_ready_i == 0 | S4: DISPATCH | Wait for target ready |
| S5: EXECUTE_WAIT | op_done_i == 1 && !HALT | S1: FETCH | Complete, next instruction |
| S5: EXECUTE_WAIT | op_done_i == 1 && HALT | S0: IDLE | Halt execution, set done=1 |
| S5: EXECUTE_WAIT | sched_pause_i == 1 | S0: IDLE | Pause decode |
| S5: EXECUTE_WAIT | sched_abort_i == 1 | S0: IDLE | Abort decode |
| S6: BRANCH_TAKEN | cycle_count == 2 | S1: FETCH | Resume from new PC |
| S6: BRANCH_TAKEN | cycle_count < 2 | S6: BRANCH_TAKEN | Continue flush |
| S7: ERROR | abort/reset == 1 | S0: IDLE | Clear error, restart |
| S7: ERROR | abort/reset == 0 | S7: ERROR | Remain in error |

### 4.2 Conditional Transitions

| Condition | Expression | Priority |
|-----------|------------|----------|
| Invalid Opcode | opcode > 0x34 || opcode in [0x06,0x07,0x0B-0x0F,0x15-0x17,0x1C-0x1F,0x26-0x27,0x2B-0x2F] | High |
| Invalid Format | format > 3 || format mismatch | High |
| Invalid Register | vd/vs1/vs2/vs3 > 31 || sd/base > 15 | Medium |
| Branch Taken | opcode == 0x33 && ss != 0 | Normal |
| Halt | opcode == 0x34 | Normal |
| Secure Boot Fail | sec_en_i == 0 && dec_enable == 1 | High (REQ-SEC-001) |

## 5. State Operations

### 5.1 S0: IDLE

| Operation | Signal | Description |
|-----------|--------|-------------|
| Clear busy | dec_busy_o = 0 | Decoder not busy |
| Clear done | dec_done_o = 0 | Not complete |
| Clear error | ISA_ERROR = 0 | No errors |
| Wait start | sched_start_i | Wait for scheduler trigger |

**Entry Conditions:**
- Initial reset (rst_sys_n_i)
- Halt instruction complete
- Scheduler pause/abort
- Error cleared

**Exit Conditions:**
- sched_start_i == 1

### 5.2 S1: FETCH

| Operation | Signal | Description |
|-----------|--------|-------------|
| Request instruction | isa_inst_ready_o = 1 | Ready to receive |
| Wait valid | isa_inst_valid_i | Wait for instruction |
| Store instruction | ISA_INST = isa_inst_data_i | Store 32-bit instruction |
| Update PC | ISA_PC = PC + 1 | Increment PC (for non-branch) |

**Timing:**
- 1 cycle if isa_inst_valid_i == 1
- Variable if M16 not ready

**Latency:** 1 cycle (typical)

### 5.3 S2: OPCODE_DECODE

| Operation | Signal | Description |
|-----------|--------|-------------|
| Extract opcode | dec_opcode_o = inst[31:26] | 6-bit opcode |
| Detect format | dec_format_o = detect_format(opcode) | V/VI/M/S |
| Check validity | if opcode invalid -> ERROR | Validate opcode |
| Update status | ISA_STATUS[8:13] = opcode | Current opcode |

**Format Detection Logic:**
```
Format Detection Table:
| OPCODE Range | Format |
|--------------|--------|
| 0x00-0x05    | V      |
| 0x02         | VI     |  (VSMUL special)
| 0x08-0x0A    | M/S    |  (MLOAD=M, MMUL=V, MSET_DIM=S)
| 0x10-0x14    | V      |
| 0x18-0x1B    | V      |
| 0x20-0x25    | M/S    |  (VLD/VST/SLD/SST/ROPE_LD=M, EMBED=S)
| 0x28-0x2A    | V/M/S  |  (KV_WRITE=V, KV_READ=M, KV_RESET=S)
| 0x30-0x34    | S      |
```

**Timing:** 1 cycle

### 5.4 S3: OPERAND_EXTRACT

| Operation | Signal | Description |
|-----------|--------|-------------|
| V-Type Extract | vd, vs1, vs2, vs3, func | Extract all fields |
| VI-Type Extract | vd, vs1, imm16 | Extract immediate |
| M-Type Extract | vd, base, sd, offset11 | Extract memory fields |
| S-Type Extract | sd, imm21 | Extract scalar/control fields |
| Check BNZ | if opcode == 0x33 && ss != 0 | Branch condition |
| Validate registers | if invalid -> ERROR | Check bounds |

**Field Extraction per Format:**

| Format | Fields | Bit Positions |
|--------|--------|---------------|
| V | vd[25:21], vs1[20:16], vs2[15:11], vs3[10:6], func[5:0] |
| VI | vd[25:21], vs1[20:16], imm16[15:0] |
| M | vd[25:21], base[20:16], sd[15:11], offset11[10:0] |
| S | sd[25:21], imm21[20:0] |

**Timing:** 1 cycle

### 5.5 S4: DISPATCH

| Operation | Signal | Description |
|-----------|--------|-------------|
| Select target | op_target_o = select_target(opcode) | Target module ID |
| Request dispatch | op_valid_o = 1 | Dispatch request |
| Wait ready | op_ready_i == 1 | Target acknowledge |
| Start execution | op_start_o = 1 | Trigger execution |
| Update status | ISA_STATUS[0] = 1 | Set busy |

**Target Selection Logic:**
```
Target Module Selection:
| OPCODE Range | op_target_o | Target Module |
|--------------|-------------|---------------|
| 0x00-0x05    | 2           | M10 (FFN/MatMul) |
| 0x08-0x0A    | 0           | M00 (Systolic Array) |
| 0x10-0x14    | 3/4         | M11/M12 (Special func) |
| 0x18-0x1B    | 1/4         | M09/M12 (Reduction) |
| 0x20-0x25    | -           | M02/M03 (Memory, special path) |
| 0x28-0x2A    | 1           | M09 (KV Cache) |
| 0x30-0x34    | -           | M13 internal (Scalar/Control) |
```

**Timing:** 1 cycle (if op_ready_i == 1)

### 5.6 S5: EXECUTE_WAIT

| Operation | Signal | Description |
|-----------|--------|-------------|
| Wait completion | op_done_i == 1 | Wait for execution |
| Monitor interrupt | sched_pause_i, sched_abort_i | Scheduler control |
| Check HALT | if opcode == 0x34 -> IDLE | Halt detection |
| Clear busy | dec_busy_o = 0 | Execution complete |

**Timing:**
- Variable, depends on instruction latency
- Range: 1 cycle (VCOPY) to 512 cycles (MMUL max)

**Average Latencies:**
| Instruction Type | Typical Latency |
|------------------|-----------------|
| Vector Arithmetic | 2 cycles |
| Special Function | 4 cycles |
| Reduction | 6 cycles |
| Memory Access | 4 cycles |
| Scalar | 2 cycles |
| Control (BNZ) | 1 cycle (not taken) |
| MatMul (MMUL) | s_dim cycles (variable) |

### 5.7 S6: BRANCH_TAKEN

| Operation | Cycle | Description |
|-----------|-------|-------------|
| Pipeline Flush | 1 | Clear S1-S4 registers |
| Target Calculation | 1 | branch_target = PC + IMM21 (signed) |
| PC Update | 2 | ISA_PC = branch_target |
| Set branch flag | 2 | ISA_STATUS[3] = 1 (branch_taken) |
| Resume fetch | 2 -> S1 | Continue from new PC |

**Pipeline Flush Operations:**
- Clear ISA_INST register
- Clear decoded fields (opcode, format, operands)
- Invalidate pending dispatches

**Timing:** 2 cycles (fixed pipeline flush penalty)

### 5.8 S7: ERROR

| Operation | Signal | Description |
|-----------|--------|-------------|
| Set error flag | ISA_STATUS[2] = 1 | Error detected |
| Set specific error | ISA_ERROR[cause] = 1 | Error type |
| Halt decoder | dec_busy_o = 0 | Stop execution |
| Wait clear | abort/reset | Wait for recovery |

**Error Types:**
| Error | ISA_ERROR Bit | Condition |
|-------|---------------|-----------|
| invalid_opcode | [0] | opcode > 0x34 or in reserved range |
| invalid_format | [1] | format detection mismatch |
| invalid_reg | [2] | register index out of bounds |
| secure_boot_fail | [3] | sec_en_i == 0 (REQ-SEC-001) |

**Timing:** Indeterminate (wait for external clear)

## 6. State Timing Analysis

### 6.1 Normal Decode Path Timing

| Path | States | Total Cycles | Description |
|------|--------|--------------|-------------|
| Normal Decode | S0->S1->S2->S3->S4->S5->S1 | 4 + execute | Complete decode + execute |
| Branch Not Taken | S0->S1->S2->S3->S4->S5->S1 | 4 + 1 | BNZ with ss == 0 |
| Branch Taken | S0->S1->S2->S3->S6->S1 | 4 + 2 | BNZ with ss != 0, pipeline flush |
| Error Path | S0->S1->S2->S7 | 2 | Invalid opcode detection |

### 6.2 Instruction-Specific Timing

| Instruction | Decode (cycles) | Execute (cycles) | Total (cycles) |
|-------------|-----------------|------------------|----------------|
| VADD/VMUL/VSUB | 4 | 2 | 6 |
| VCOPY | 4 | 1 | 5 |
| VSMUL | 4 | 2 | 6 |
| MLOAD | 4 | 4 | 8 |
| MMUL | 4 | s_dim | 4 + s_dim |
| MSET_DIM | 4 | 1 | 5 |
| VEXP/VSIN/VCOS | 4 | 4 | 8 |
| VSQRT_INV/VSIGMOID | 4 | 4 | 8 |
| VSUM/VMAX/VARGMAX | 4 | 6 | 10 |
| VDOT | 4 | 4 | 8 |
| VLD/VST | 4 | 4 | 8 |
| SLD/SST | 4 | 4 | 8 |
| KV_WRITE/KV_READ | 4 | 4 | 8 |
| KV_RESET | 4 | 1 | 5 |
| SADD | 4 | 1 | 5 |
| SMUL | 4 | 2 | 6 |
| SDIV | 4 | 8 | 12 |
| BNZ (not taken) | 4 | 1 | 5 |
| BNZ (taken) | 4 | 3 | 7 (includes flush) |
| HALT | 4 | 1 | 5 |

### 6.3 Pipeline Performance

| Metric | Value | Description |
|--------|-------|-------------|
| Decode Throughput | 1 inst / 4 cycles | Max decode rate |
| Branch Penalty | 2 cycles | BNZ taken pipeline flush |
| Max Latency | 4 + 512 cycles | MMUL with s_dim=512 |
| Avg CPI | ~10 cycles | Average cycles per instruction |

## 7. FSM Control Signals

### 7.1 Input Control Signals

| Signal | Source | Effect |
|--------|--------|--------|
| sched_start_i | M08 Scheduler | Start decode (S0 -> S1) |
| sched_pause_i | M08 Scheduler | Pause to IDLE |
| sched_abort_i | M08 Scheduler | Abort to IDLE |
| isa_inst_valid_i | M16 ISA Interface | Instruction ready |
| op_ready_i | Target Module | Dispatch acknowledge |
| op_done_i | Target Module | Execution complete |
| sec_en_i | M14 Secure Boot | Secure Boot enable (REQ-SEC-001) |
| rst_sys_n_i | System Reset | Reset FSM to IDLE |

### 7.2 Output Control Signals

| Signal | Target | Effect |
|--------|--------|--------|
| dec_busy_o | M08 Scheduler | Decoder busy status |
| dec_done_o | M08 Scheduler | Decode complete |
| isa_inst_ready_o | M16 ISA Interface | Ready for instruction |
| op_valid_o | Target Module | Dispatch request |
| op_start_o | Target Module | Execution trigger |
| isa_pc_update_o | M16 ISA Interface | PC update request |

### 7.3 Internal FSM Registers

| Register | Width | Description |
|----------|-------|-------------|
| fsm_state | 3 | Current FSM state (S0-S7) |
| branch_counter | 2 | Branch flush cycle counter |
| current_opcode | 6 | Decoded opcode |
| current_format | 2 | Detected format |
| branch_target | 32 | Calculated branch address |
| wait_counter | 16 | Execute wait cycle counter |

## 8. Exception Handling

### 8.1 Invalid Opcode

```
Condition: opcode > 0x34 or opcode in reserved ranges

FSM Response:
1. Transition to S7: ERROR
2. Set ISA_ERROR[0] = 1 (invalid_opcode)
3. Set ISA_STATUS[2] = 1 (error)
4. Halt decoder (dec_busy_o = 0)
5. Wait for sched_abort_i or reset
```

### 8.2 Invalid Format

```
Condition: format > 3 or format mismatch with opcode

FSM Response:
1. Transition to S7: ERROR
2. Set ISA_ERROR[1] = 1 (invalid_format)
3. Set ISA_STATUS[2] = 1 (error)
4. Halt decoder
```

### 8.3 Invalid Register Index

```
Condition: vd/vs > 31 or sd/base > 15

FSM Response:
1. Transition to S7: ERROR
2. Set ISA_ERROR[2] = 1 (invalid_reg)
3. Halt decoder
```

### 8.4 Secure Boot Failure

```
Condition: sec_en_i == 0 when dec_enable == 1 (REQ-SEC-001)

FSM Response:
1. Transition to S7: ERROR immediately
2. Set ISA_ERROR[3] = 1 (secure_boot_fail)
3. Block all instruction execution
4. Wait for M14 re-verification
```

### 8.5 Branch Handling

```
BNZ Instruction:
1. Decode in S2/S3
2. Check ss register in S3
3. If ss == 0: Normal path (S4 -> S5)
4. If ss != 0: Branch path (S6)
   - Pipeline flush (2 cycles)
   - PC = PC + IMM21 (signed)
   - Resume from S1 with new PC
```

### 8.6 Scheduler Control

```
Pause Request (sched_pause_i == 1):
1. Complete current instruction execution
2. Transition to S0: IDLE
3. Set dec_busy_o = 0
4. Preserve PC and registers

Abort Request (sched_abort_i == 1):
1. Immediate transition to S0: IDLE
2. Clear all pipeline registers
3. Reset PC to saved value
```

## 9. Implementation Notes

### 9.1 Hardware Implementation

| Component | Description |
|-----------|-------------|
| FSM Controller | 3-bit state register + transition logic |
| Opcode Decoder | 6-bit opcode lookup table |
| Format Detector | Opcode-to-format mapping |
| Operand Extractor | Field extraction multiplexers |
| Target Selector | Opcode-to-target dispatch logic |
| Branch Logic | BNZ condition check + PC update |
| Error Detector | Opcode/format/register validity check |

### 9.2 Critical Paths

| Path | Timing Constraint | Solution |
|------|-------------------|----------|
| Opcode Decode | < 2 ns @ 500 MHz | Combinational lookup |
| Branch Target Calc | < 2 ns | Adder with signed extension |
| Target Dispatch | < 2 ns | Multiplexer selection |
| Error Detection | < 2 ns | Parallel validity check |

### 9.3 Testability (DFT)

| Feature | Description |
|---------|-------------|
| State Scan | Scan chain for FSM state register |
| Opcode Injection | Force specific opcode for testing |
| Branch Force | Force branch taken/not taken |
| Error Injection | Inject error conditions |

### 9.4 Power Optimization

| Technique | Application |
|-----------|-------------|
| Clock Gating | Gate unused pipeline stages |
| State Encoding | Minimal transition encoding |
| Operand Latch | Latch operands only when needed |
| Idle Power Down | Power gate in IDLE state |

## 10. Verification Requirements

### 10.1 FSM Coverage

| Test Category | Target Coverage |
|---------------|-----------------|
| State Coverage | 100% (all 8 states) |
| Transition Coverage | 100% (all transitions) |
| Branch Coverage | 100% (taken/not taken) |
| Error Coverage | 100% (all error types) |

### 10.2 Test Cases

| Test | Description | FSM Path |
|------|-------------|----------|
| Normal Decode | Valid instruction decode | S0->S1->S2->S3->S4->S5->S1 |
| Branch Not Taken | BNZ with ss == 0 | S0->S1->S2->S3->S4->S5->S1 |
| Branch Taken | BNZ with ss != 0 | S0->S1->S2->S3->S6->S1 |
| Invalid Opcode | Opcode > 0x34 | S0->S1->S2->S7 |
| Invalid Register | vd > 31 | S0->S1->S2->S3->S7 |
| Halt | HALT instruction | S0->S1->S2->S3->S4->S5->S0 |
| Scheduler Pause | sched_pause_i | S5->S0 |
| Scheduler Abort | sched_abort_i | S5->S0 |
| Secure Boot Fail | sec_en_i == 0 | S0->S7 (REQ-SEC-001) |

## 11. Dependencies

| Module | Dependency Type | FSM Impact |
|--------|-----------------|------------|
| M16 ISA Interface | Input | FETCH state input |
| M14 Secure Boot | Control | ERROR state trigger (REQ-SEC-001) |
| M08 Scheduler | Control | Start/Pause/Abort control |
| M00-M12 Operators | Dispatch | EXECUTE_WAIT state input |
| M02/M03 Memory | Memory | Memory instruction dispatch |
| M05 Power Manager | Power | DVFS impact on timing |