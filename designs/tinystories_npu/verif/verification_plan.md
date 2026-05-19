---
design: tinystories_npu
type: verification_plan
target_coverage: 99%
coverage_types: [functional, line, branch, toggle]
generated: "2026-05-17T22:30:00+08:00"
---

# TinyStories NPU Verification Plan

## 1. Coverage Targets

| Coverage Type | Target | Weight |
|---------------|--------|--------|
| Functional    | 99%    | 40%    |
| Line          | 99%    | 30%    |
| Branch        | 99%    | 20%    |
| Toggle        | 99%    | 10%    |

## 2. Module Verification Strategy

### 2.1 M00: Systolic Array

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M00-001 | WS Mode operation | weight preload + input streaming + output collection | HIGH |
| F-M00-002 | OS Mode operation | weight/input streaming + output stationary | HIGH |
| F-M00-003 | FP8 precision (E4M3) | FP8 MAC, quantization, saturation | HIGH |
| F-M00-004 | FP8 precision (E5M2) | FP8 MAC, range handling | HIGH |
| F-M00-005 | FP16 precision | FP16 MAC, accumulator | HIGH |
| F-M00-006 | INT8 precision | INT8 MAC, overflow handling | HIGH |
| F-M00-007 | FP32 precision | FP32 MAC, baseline | MEDIUM |
| F-M00-008 | Round modes (RN/RZ/RU/RD) | All 4 rounding modes | HIGH |
| F-M00-009 | Saturation vs wrap-around | Overflow behavior | HIGH |
| F-M00-010 | Matrix size boundary | M/N/K limits, error flags | HIGH |
| F-M00-011 | Activity control | pe_row_cnt/pe_col_cnt gating | MEDIUM |
| F-M00-012 | Mixed precision mode | FP16 input, INT8 weight | MEDIUM |

**Branch Coverage Points**:

| ID | Branch | Condition |
|----|--------|-----------|
| B-M00-001 | pe_mode selection | WS=0, OS=1 |
| B-M00-002 | pe_precision selection | FP8/FP16/INT8/FP32 |
| B-M00-003 | fp8_format selection | E4M3/E5M2 |
| B-M00-004 | saturation enable | sat=1 vs sat=0 |
| B-M00-005 | size error detection | M>128, N>128, K>256 |

### 2.2 M01: Dataflow Controller

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M01-001 | Operator dispatch FSM | IDLE→FETCH→DECODE→DISPATCH→WAIT→COMPLETE | HIGH |
| F-M01-002 | Attention operator | op_code=0x01 sequence | HIGH |
| F-M01-003 | FFN operator | op_code=0x02 sequence | HIGH |
| F-M01-004 | RMSNorm operator | op_code=0x03 sequence | HIGH |
| F-M01-005 | RoPE operator | op_code=0x04 sequence | HIGH |
| F-M01-006 | SoftMax operator | op_code=0x05 sequence | HIGH |
| F-M01-007 | Thread 0 execution | TID=0 context management | HIGH |
| F-M01-008 | Thread 1 execution | TID=1 context management | HIGH |
| F-M01-009 | Thread switch | Round-Robin switch <= 4 cycles | HIGH |
| F-M01-010 | Memory coherence | SRAM allocation, read/write ordering | HIGH |
| F-M01-011 | Pipeline utilization | >= 80% throughput | HIGH |
| F-M01-012 | Error handling | syst_err, op_err responses | MEDIUM |

### 2.3 M02: SRAM Scratchpad

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M02-001 | SRAM read operation | Address decode, data output | HIGH |
| F-M02-002 | SRAM write operation | Address decode, data input | HIGH |
| F-M02-003 | Bank arbitration | Multi-port access | HIGH |
| F-M02-004 | Burst access | Sequential read/write | MEDIUM |

### 2.4 M03: DRAM Controller

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M03-001 | DRAM read burst | Row activation, column access | HIGH |
| F-M03-002 | DRAM write burst | Write data, precharge | HIGH |
| F-M03-003 | Refresh handling | Auto-refresh scheduling | MEDIUM |

### 2.5 M04: System Bus

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M04-001 | AXI4 write transaction | AW/W/B channels | HIGH |
| F-M04-002 | AXI4 read transaction | AR/R channels | HIGH |
| F-M04-003 | Burst handling | AWLEN/ARLEN | MEDIUM |
| F-M04-004 | Error response | SLVERR/DECERR | MEDIUM |

### 2.6 M05: Power Manager

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M05-001 | DVFS transition | Voltage/frequency scaling | HIGH |
| F-M05-002 | Power gate enable | PD_MAIN, PD_PERIPH gating | HIGH |
| F-M05-003 | Wake-up sequence | Power domain restore | MEDIUM |

### 2.7 M06: Clock Manager

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M06-001 | Clock generation | CLK_SYS 250-500 MHz | HIGH |
| F-M06-002 | Clock gating | Module-specific gating | MEDIUM |

### 2.8 M07: Reset Manager

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M07-001 | Reset sequence | Power-on reset | HIGH |
| F-M07-002 | Soft reset | Warm reset handling | MEDIUM |

### 2.9 M08: Thread Scheduler

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M08-001 | Thread enable | T0/T1 enable/disable | HIGH |
| F-M08-002 | Priority arbitration | Priority configuration | HIGH |
| F-M08-003 | Yield mechanism | sched_yield assertion | MEDIUM |

### 2.10 M09: Attention Unit

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M09-001 | Multi-Head Attention | 8 heads, head_size=8 | HIGH |
| F-M09-002 | MQA optimization | 4 KV heads shared | HIGH |
| F-M09-003 | Causal masking | pos 0-511 mask validation | HIGH |
| F-M09-004 | KV Cache update | Prefill/Decode phases | HIGH |
| F-M09-005 | KV Cache overflow | pos > 512 handling | HIGH |
| F-M09-006 | RoPE integration | Q/K rotation | HIGH |
| F-M09-007 | QK Score computation | Q*K^T via M00 | HIGH |
| F-M09-008 | AV Output computation | SoftMax*V via M00 | HIGH |
| F-M09-009 | SoftMax handshake | sm_valid/sm_ready protocol | HIGH |
| F-M09-010 | Precision modes | FP8/FP16/INT8/FP32 | HIGH |

### 2.11 M10: FFN/MatMul Unit

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M10-001 | FFN W1 MatMul | hidden→intermediate | HIGH |
| F-M10-002 | GELU activation | Activation function | HIGH |
| F-M10-003 | FFN W2 MatMul | intermediate→hidden | HIGH |
| F-M10-004 | Precision handling | FP16/INT8/FP32 | MEDIUM |

### 2.12 M11: RMSNorm/RoPE Unit

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M11-001 | RMSNorm computation | Layer normalization | HIGH |
| F-M11-002 | RoPE rotation | Position embedding | HIGH |
| F-M11-003 | Position handling | pos 0-511 | HIGH |

### 2.13 M12: SoftMax Unit

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M12-001 | SoftMax computation | exp, sum, normalize | HIGH |
| F-M12-002 | Max subtraction | Numerical stability | HIGH |
| F-M12-003 | Causal mask handling | -inf score handling | HIGH |

### 2.14 M13: ISA Decoder

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M13-001 | Instruction decode | Opcode parsing | HIGH |
| F-M13-002 | Operand extraction | Register/immediate | MEDIUM |

### 2.15 M14: Secure Boot

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M14-001 | Boot sequence | Secure initialization | HIGH |
| F-M14-002 | Authentication | Signature verification | MEDIUM |

### 2.16 M15: JTAG Interface

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M15-001 | JTAG TAP controller | TCK/TMS/TDI/TDO | MEDIUM |
| F-M15-002 | Debug access | Register read/write | MEDIUM |

### 2.17 M16: ISA Interface

**Functional Coverage Points**:

| ID | Feature | Test Case | Priority |
|----|---------|-----------|----------|
| F-M16-001 | ISA instruction input | Instruction stream | HIGH |
| F-M16-002 | ISA to M13 handshake | Valid/ready protocol | HIGH |

## 3. Testbench Architecture

### 3.1 TB Structure

```
tb/
├── tb_top.sv              # Top-level testbench
├── tb_env.sv              # Test environment
├── tb_scoreboard.sv       # Result verification
├── tb_driver.sv           # Stimulus generation
├── tb_monitor.sv          # Output observation
├── tb_sequences.sv        # Test sequences
├── tb_coverage.sv         # Coverage collection
└── module_specific/
    ├── tb_M00.sv          # M00 Systolic Array TB
    ├── tb_M01.sv          # M01 Dataflow Controller TB
    ├── tb_M09.sv          # M09 Attention Unit TB
    └── ...
```

### 3.2 Coverage Collection

Using Verilator coverage:

```bash
verilator --coverage --trace \
  -f file_list.f \
  tb/tb_top.sv \
  --top-module tb_top
```

Coverage types enabled:
- `--coverage-line`: Line coverage
- `--coverage-branch`: Branch coverage
- `--coverage-toggle`: Toggle coverage

### 3.3 Coverage Analysis

Post-processing with verilator_coverage:

```bash
verilator_coverage -write coverage.json \
  coverage.dat
```

## 4. Test Execution Plan

### Phase 1: Module-Level Tests (Priority: HIGH)

| Module | Test Count | Estimated Coverage |
|--------|------------|-------------------|
| M00    | 15         | 85%               |
| M01    | 12         | 85%               |
| M09    | 10         | 85%               |
| M02-M08| 8 each     | 80% each          |
| M10-M16| 6 each     | 75% each          |

### Phase 2: Integration Tests

| Test | Description | Target Coverage Gain |
|------|-------------|---------------------|
| Transformer Pipeline | Attention→FFN→Norm | +5% |
| KV Cache Flow | Prefill→Decode | +3% |
| Multi-thread | T0/T1 interleaving | +2% |

### Phase 3: Coverage Closure

Iterate until 99% achieved:
1. Analyze uncovered code
2. Add targeted test cases
3. Re-run coverage collection
4. Repeat until target met

## 5. Coverage Metrics Dashboard

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Functional | 0% | 99% | 99% |
| Line | 0% | 99% | 99% |
| Branch | 0% | 99% | 99% |
| Toggle | 0% | 99% | 99% |

## 6. References

- RTL Artifact: `rtl_artifact.json`
- MAS Specifications: `spec_mas/M00-M16/MAS.md`
- REQ-COMPUTE-001~008: Compute requirements
- REQ-MEM-001~004: Memory requirements
- REQ-PWR-001~003: Power requirements