---
module: M00_SystolicArray
type: verification
status: complete
parent: M00
module_type: compute
generated: "2026-05-17T16:00:00+08:00"
---

# M00: Systolic Array Verification Plan

## 1. Overview

M00 Systolic Array 是 TinyStories NPU 的核心计算单元，采用 128x128 PE 阵列结构，支持 WS/OS 双模式和 FP8/FP16/INT8/FP32 四种精度。验证目标是确保 MAC 正确性、模式切换无损、精度损失 <= 0.5%、Pipeline Utilization >= 80%。

### 1.1 Verification Targets

| Metric | Target | REQ Reference |
|--------|--------|---------------|
| MAC Correctness | 100% pass | REQ-COMPUTE-001~003 |
| WS/OS Mode Switch | Zero data loss | REQ-COMPUTE-005 |
| Precision Loss | <= 0.5% vs FP32 | REQ-COMPUTE-007 |
| Pipeline Utilization | >= 80% | REQ-COMPUTE-005 |
| TOPS (FP8) | >= 2 TOPS | REQ-COMPUTE-001 |
| TOPS (FP16) | >= 1 TOPS | REQ-COMPUTE-002 |
| TOPS (INT8) | >= 2 TOPS | REQ-COMPUTE-003 |

### 1.2 Verification Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 5.x | RTL simulation + coverage |
| Cocotb | 1.x | Python test framework |
| Formal | Yosys/ABC | Protocol assertion proof |
| Python NumPy | Reference model |

## 2. Functional Coverage Points

| ID | Feature | Description | Priority | Coverage Target |
|----|---------|-------------|----------|-----------------|
| FC-001 | WS Mode MAC | Weight Stationary mode matrix multiply | P0 | 100% |
| FC-002 | OS Mode MAC | Output Stationary mode matrix multiply | P0 | 100% |
| FC-003 | WS/OS Switch | Mode switch without data loss | P0 | 100% |
| FC-004 | FP8 E4M3 | FP8 E4M3 format MAC operation | P0 | 100% |
| FC-005 | FP8 E5M2 | FP8 E5M2 format MAC operation | P0 | 100% |
| FC-006 | FP16 | FP16 format MAC operation | P0 | 100% |
| FC-007 | INT8 | INT8 format MAC operation | P0 | 100% |
| FC-008 | FP32 | FP32 format MAC operation (baseline) | P1 | 100% |
| FC-009 | Mixed Precision | FP16 input + INT8 weight combinations | P0 | 100% |
| FC-010 | Rounding Modes | RN/RZ/RU/RD rounding behavior | P1 | 100% |
| FC-011 | Saturation | Overflow saturation vs wrap-around | P1 | 100% |
| FC-012 | Array Partial | pe_row_cnt/pe_col_cnt < 128 cases | P1 | 100% |
| FC-013 | Pipeline Fill | Full array pipeline fill timing | P0 | 100% |
| FC-014 | Pipeline Drain | Output drain correctness | P0 | 100% |
| FC-015 | DVFS Transition | OP0/OP1/OP2 frequency switch | P1 | 100% |
| FC-016 | Clock Gating | Inactive PE clock gating | P2 | 95% |
| FC-017 | Power Gating | Inactive PE power gating | P2 | 95% |
| FC-018 | PE Activity | Dynamic pe_row_cnt/pe_col_cnt | P1 | 100% |
| FC-019 | Data Width | 8/16/32-bit data path switching | P1 | 100% |
| FC-020 | Accumulator | 32-bit accumulator overflow handling | P1 | 100% |

## 3. Assertion List

| ID | Type | Assertion | Description |
|----|------|-----------|-------------|
| AS-001 | Immediate | `pe_mode == 0 || pe_mode == 1` | Mode selection valid |
| AS-002 | Immediate | `pe_precision <= 3` | Precision code valid |
| AS-003 | Immediate | `pe_row_cnt <= 127` | Row count within range |
| AS-004 | Immediate | `pe_col_cnt <= 127` | Column count within range |
| AS-005 | Cover | `pe_start == 1` | Start pulse triggered |
| AS-006 | Cover | `pe_done == 1` | Compute completion |
| AS-007 | Cover | `pe_err != 0` | Error detected |
| AS-008 | Immediate | `fp8_format == 0 || fp8_format == 1` | FP8 format valid |
| AS-009 | Immediate | `round_mode <= 3` | Rounding mode valid |
| AS-010 | Immediate | `saturation == 0 || saturation == 1` | Saturation mode valid |
| AS-011 | Concurrent | `pe_done -> next_cycle_no_pe_start` | Done clears start state |
| AS-012 | Concurrent | `ws_mode_weight_preload_complete -> input_stream_start` | WS preload sequence |
| AS-013 | Concurrent | `os_mode_init_complete -> weight_input_stream_start` | OS init sequence |
| AS-014 | Concurrent | `pipeline_fill_complete -> output_valid` | Pipeline output timing |
| AS-015 | Immediate | `pipeline_utilization >= 80%` | REQ-COMPUTE-005 compliance |
| AS-016 | Cover | `overflow_detected && saturation == 1` | Saturation triggered |
| AS-017 | Cover | `precision_loss <= 0.5%` | REQ-COMPUTE-007 compliance |
| AS-018 | Immediate | `sram_addr_valid` | Address within SRAM range |
| AS-019 | Concurrent | `dvfs_transition_complete -> timing_stable` | DVFS stability |
| AS-020 | Cover | `inactive_pe_clock_gated` | Clock gating active |

## 4. Test Scenarios

### 4.1 Normal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TN-001 | WS 128x128 FP16 | Full array WS mode FP16 matmul | A[128x128], B[128x128] | C = A*B (NumPy reference) |
| TN-002 | OS 128x128 FP16 | Full array OS mode FP16 matmul | A[128x128], B[128x128] | C = A*B (NumPy reference) |
| TN-003 | FP8 E4M3 MatMul | E4M3 format MAC | FP8 matrices | C <= 0.5% vs FP32 |
| TN-004 | FP8 E5M2 MatMul | E5M2 format MAC | FP8 matrices | C <= 0.5% vs FP32 |
| TN-005 | INT8 MatMul | INT8 quantized MAC | INT8 matrices | C <= 0.5% vs FP32 |
| TN-006 | Mixed Precision | FP16 input + INT8 weight | Mixed matrices | Correct accumulation |
| TN-007 | Partial Array 64x64 | Half array operation | A[64x64], B[64x64] | C = A*B |
| TN-008 | Partial Array 32x32 | Quarter array operation | A[32x32], B[32x32] | C = A*B |
| TN-009 | Pipeline Burst | 10 consecutive matmul ops | Sequential A, B matrices | All outputs correct |
| TN-010 | Rounding RN | Round-to-nearest-even | Values requiring rounding | RN behavior correct |
| TN-011 | Rounding RZ | Round-toward-zero | Values requiring rounding | RZ behavior correct |
| TN-012 | DVFS OP0-OP1 | Frequency switch 500->350 MHz | Matmul in progress | Seamless transition |
| TN-013 | Weight Preload WS | WS mode weight loading | W[128x128] | Correct preload timing |
| TN-014 | Input Streaming WS | WS mode input flow | X[128x128] | Correct streaming timing |
| TN-015 | Output Collection | OS mode output writeback | Y[128x128] | Correct writeback timing |

### 4.2 Boundary Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TB-001 | Min Array 1x1 | Single PE operation | A[1x1], B[1x1] | C = A*B |
| TB-002 | Non-square 1x128 | Row vector matmul | A[1x128], B[128x128] | C = A*B |
| TB-003 | Non-square 128x1 | Column vector matmul | A[128x128], B[128x1] | C = A*B |
| TB-004 | FP8 Max Value | E4M3 max (448) operation | A=448, B=448 | Saturation handling |
| TB-005 | FP8 Min Value | E5M2 min normal operation | Near-zero values | Correct quantization |
| TB-006 | INT8 Max Value | INT8 max (127) operation | A=127, B=127 | Overflow handling |
| TB-007 | Accumulator Max | 32-bit accumulator overflow | Large accumulation | Saturation/wrap correct |
| TB-008 | Zero Matrix | All-zero matmul | A=0, B=0 | C=0 |
| TB-009 | Identity Matrix | Identity matmul | A=I, B=X | C=X |
| TB-010 | Address Boundary | SRAM address at max | addr=0x8007_FFFC | Correct access |
| TB-011 | Pipeline Fill Timing | Measure fill cycles | 128x128 matrix | Fill <= 255 cycles |
| TB-012 | Mode Switch Boundary | Switch at compute boundary | Mode toggle at done | No data corruption |

### 4.3 Abnormal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TA-001 | Invalid Mode | pe_mode = 2 | Illegal mode | Error flag, no compute |
| TA-002 | Invalid Precision | pe_precision = 4 | Illegal precision | Error flag, no compute |
| TA-003 | Row Count Overflow | pe_row_cnt = 128 | Out of range | Error flag |
| TA-004 | Col Count Overflow | pe_col_cnt = 128 | Out of range | Error flag |
| TA-005 | Start Without Ready | pe_start when busy | Double start | Second start ignored |
| TA-006 | Overflow No Saturation | Large value, saturation=0 | Overflow condition | Wrap-around result |
| TA-007 | FP8 Denormal | E5M2 denormal values | Subnormal input | Correct handling |
| TA-008 | DVFS Under Compute | Frequency switch mid-compute | DVFS during op | Graceful handling |
| TA-009 | Clock Gating Active PE | Gating active row | Gating request | Reject or defer |
| TA-010 | Power Gating Active PE | Gating active row | Gating request | Reject or defer |
| TA-011 | Invalid FP8 Format | fp8_format = 2 | Illegal format | Error flag |
| TA-012 | Invalid SRAM Address | addr outside range | Bad address | Error flag |
| TA-013 | Premature Output Read | Read before done | Early read | Wait or error |
| TA-014 | Mode Switch Mid-Compute | Switch during operation | Toggle during compute | Deferred to completion |

## 5. Coverage Targets

| Category | Target | Metric |
|----------|--------|--------|
| Code Coverage | 100% | Line, branch, toggle, FSM |
| Functional Coverage | 95% | All FC points hit |
| Assertion Coverage | 100% | All AS covered |
| Corner Case Coverage | 95% | Boundary + abnormal scenarios |
| Performance Coverage | 100% | TOPS, utilization metrics verified |

### 5.1 Code Coverage Details

| Type | Target | Description |
|------|--------|-------------|
| Line Coverage | 100% | All RTL lines executed |
| Branch Coverage | 100% | All if/case branches taken |
| Toggle Coverage | 100% | All signals 0->1 and 1->0 |
| FSM Coverage | 100% | All state transitions |
| Expression Coverage | 95% | All expression conditions |

### 5.2 Functional Coverage Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| MAC Correctness | 100% | NumPy reference comparison |
| Precision Error | <= 0.5% | FP32 baseline comparison |
| Pipeline Utilization | >= 80% | Cycle counter measurement |
| TOPS FP8 | >= 2 | Throughput measurement |
| TOPS FP16 | >= 1 | Throughput measurement |
| TOPS INT8 | >= 2 | Throughput measurement |

## 6. Verification Tools

### 6.1 Simulation Environment

| Component | Tool | Configuration |
|-----------|------|---------------|
| RTL Simulator | Verilator 5.x | --coverage + --trace |
| Test Framework | Cocotb | Python-based test cases |
| Reference Model | NumPy | FP32 reference computation |
| Waveform | GTKWave | Debug visualization |

### 6.2 Coverage Collection

```bash
# Verilator coverage command
verilator --cc --exe --coverage -Wno-fatal top.v tb_top.cpp
make -C obj_dir
./obj_dir/Vtop --coverage

# Coverage analysis
verilator_coverage --annotate coverage.log obj_dir/Vtop_coverage.dat
```

### 6.3 Formal Verification

| Property | Tool | Method |
|----------|------|--------|
| Mode Valid | Yosys Sby | Proof of AS-001~010 |
| Sequence Correctness | Sby | Proof of AS-012~014 |
| Overflow Handling | Sby | Proof of AS-016 |

### 6.4 Test Execution Flow

```
1. Build RTL with Verilator + coverage
2. Run Normal scenarios (TN-001 to TN-015)
3. Run Boundary scenarios (TB-001 to TB-012)
4. Run Abnormal scenarios (TA-001 to TA-014)
5. Collect coverage data
6. Analyze coverage report
7. Fill coverage holes if < target
8. Generate verification report
```

## 7. References

- REQ-COMPUTE-001: FP8 TOPS >= 2
- REQ-COMPUTE-002: FP16 TOPS >= 1
- REQ-COMPUTE-003: INT8 TOPS >= 2
- REQ-COMPUTE-005: Pipeline utilization >= 80%
- REQ-COMPUTE-007: Precision loss <= 0.5%
- REQ-PWR-003: DVFS >= 2 operating points
- MAS: /spec_mas/M00/MAS.md
- FSM: /spec_mas/M00/FSM.md
- Datapath: /spec_mas/M00/datapath.md