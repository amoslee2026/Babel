---
module: M01
type: DFT
status: complete
parent: M01
module_type: control
generated: "2026-05-17T16:30:00+08:00"
---

# M01: Dataflow Controller - DFT Specification

## 1. Overview

M01 Dataflow Controller 是数据流调度控制器，DFT 策略覆盖 Dispatch Logic、Thread Scheduler、Pipeline Control、Memory Interface 四大测试对象。目标测试覆盖率 >= 95% (REQ-DFT-001)。

| Test Object | Coverage Target | Priority |
|-------------|-----------------|----------|
| Dispatch Logic | 98% | Highest |
| Thread Scheduler | 98% | Highest |
| Pipeline Control FSM | 95% | High |
| Memory Interface | 95% | High |

## 2. Scan Chain Configuration

### 2.1 Scan Chain Architecture

采用功能分组 scan chain 架构，便于针对性测试。

| Chain Group | Chain ID | Elements | Length (FFs) | Description |
|--------------|----------|----------|--------------|-------------|
| Dispatch FSM | SC0 | 1 chain | 2,500 | Operator dispatch state machine |
| Thread Context | SC1 | 1 chain | 800 | Thread 0/1 context registers |
| Pipeline Control | SC2 | 1 chain | 1,200 | Pipeline stage registers |
| Operator Interface | SC3-SC6 | 4 chains | 400 each | M09-M12 operator dispatch interface |
| Memory Request | SC7 | 1 chain | 600 | Memory request interface registers |
| System Bus Interface | SC8 | 1 chain | 500 | AXI4 bus interface registers |
| Interrupt Logic | SC9 | 1 chain | 200 | Interrupt generation logic |
| Performance Counter | SC10 | 1 chain | 300 | Performance monitor registers |

**Total Scan Chains**: 11 chains
**Total Scan Elements**: ~7,600 FFs

### 2.2 Scan Chain Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_enable_i | Input | 1 | Global scan enable |
| scan_mode_i | Input | 2 | Scan mode selection |
| scan_in_i | Input | 11 | Scan data input (per chain) |
| scan_out_o | Output | 11 | Scan data output (per chain) |
| scan_clk_i | Input | 1 | Scan clock |
| scan_rst_n_i | Input | 1 | Scan reset |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Clock Frequency | 10-50 MHz | Low frequency test clock |
| Scan Chain Cycle | <= 1 ms | Max chain length / scan_clk |
| Scan Capture Window | >= 10 ns | Setup + Hold time margin |

## 3. BIST Design

### 3.1 Logic BIST (LBIST) for Control Logic

LBIST 覆盖 Dispatch FSM 和 Thread Scheduler。

| Parameter | Value | Description |
|-----------|-------|-------------|
| BIST Controller | 1 instance | Centralized LBIST controller |
| PRPG | LFSR-32 | 32-bit pattern generator |
| MISR | MISR-32 | 32-bit signature compactor |
| Test Patterns | 5,000 | FSM state transition coverage |
| Coverage Target | 98% | Control logic fault coverage |

**LBIST FSM Coverage**:

```
Dispatch FSM State Coverage:
  IDLE -> FETCH_OP -> DECODE -> DISPATCH -> WAIT_DONE -> COMPLETE -> IDLE
  
  Test Coverage:
    - All state transitions
    - All input conditions (op_valid, op_ready, op_done)
    - All output responses (dispatch signals, interrupt)
    
Thread Scheduler State Coverage:
  Thread states: idle, running, waiting, context_switch
  
  Test Coverage:
    - Round-Robin transitions
    - Priority boost scenarios
    - Yield mechanism
    - Context switch latency <= 4 cycles
```

### 3.2 Pipeline Test

Pipeline 测试验证 Spatial Dataflow 利用率。

| Test Type | Description | Coverage Target |
|-----------|-------------|-----------------|
| Pipeline Stage Test | 验证 Stage 0-4 正确执行 | 100% stage coverage |
| Pipeline Utilization Test | 验证 utilization >= 80% | Utilization measurement |
| Pipeline Stall Test | 验证 stall/resume 正确性 | All stall conditions |
| Pipeline Flush Test | 验证 flush 操作完整性 | Flush correctness |

**Pipeline Test Sequence**:

```
Pipeline Functional Test:
  1. Stage 0 (Memory Load): Test SRAM/DRAM request generation
  2. Stage 1 (Attention): Verify dispatch to M09, M12
  3. Stage 2 (FFN): Verify dispatch to M10
  4. Stage 3 (Normalization): Verify dispatch to M11
  5. Stage 4 (Writeback): Test output write completion
  
Pipeline Utilization Measurement:
  6. Execute full inference sequence
  7. Measure active cycles / total cycles
  8. Verify >= 80% utilization (REQ-COMPUTE-005)
```

### 3.3 Thread Scheduler Test

多线程调度测试。

| Test Scenario | Description | Coverage |
|---------------|-------------|----------|
| Round-Robin Test | T0 -> T1 -> T0 循环调度 | All thread transitions |
| Priority Boost Test | 长时间等待线程优先级提升 | Priority logic |
| Yield Test | 算子完成时让出机制 | Yield correctness |
| Context Switch Test | 上下文切换 <= 4 cycles | Switch latency |
| Thread Interrupt Test | 线程中断处理 | IRQ per thread |

## 4. Test Access Mechanism (TAM)

### 4.1 JTAG TAP Controller

标准 IEEE 1149.1 JTAG TAP 接口。

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tck_i | Input | 1 | JTAG Test Clock |
| tms_i | Input | 1 | JTAG Test Mode Select |
| tdi_i | Input | 1 | JTAG Test Data Input |
| tdo_o | Output | 1 | JTAG Test Data Output |
| trst_n_i | Input | 1 | JTAG Test Reset |

**JTAG Instructions**:

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| EXTEST | 0x00 | External test |
| SAMPLE | 0x01 | Sample boundary |
| INTEST | 0x02 | Internal test |
| IDCODE | 0x04 | Device ID read |
| BYPASS | 0x0F | Bypass mode |
| USER1 | 0x08 | LBIST control |
| USER2 | 0x09 | Pipeline test |
| USER3 | 0x0A | Thread scheduler test |

### 4.2 Memory Interface Test Access

| Interface | Test Method | Description |
|-----------|-------------|-------------|
| M02 SRAM | Direct access test | Verify SRAM request/response |
| M03 DRAM | DMA test | Verify DRAM DMA request |
| M04 System Bus | AXI4 test | Verify AXI4 protocol compliance |

## 5. Test Mode Definition

### 5.1 Test Mode Register

| Mode | Code | Description | Active Chains |
|------|------|-------------|---------------|
| NORMAL_MODE | 0x00 | Functional operation | None |
| SCAN_MODE | 0x01 | Scan chain access | All 11 chains |
| LBIST_MODE | 0x02 | Logic BIST execution | FSM chains |
| PIPELINE_TEST | 0x03 | Pipeline functional test | Pipeline chain |
| THREAD_TEST | 0x04 | Thread scheduler test | Thread context chain |
| OPERATOR_TEST | 0x05 | Operator dispatch test | Operator interface chains |
| BURN_IN_MODE | 0x06 | Burn-in stress test | Selected chains |

### 5.2 Test Mode Control Signals

| Signal | Width | Description |
|--------|-------|-------------|
| test_mode_i | 3 | Test mode selection |
| test_start_i | 1 | Test execution start |
| test_done_o | 1 | Test completion |
| test_pass_o | 1 | Test pass indicator |
| test_fail_o | 1 | Test fail indicator |
| test_error_code_o | 8 | Error code detail |

## 6. Coverage Target

### 6.1 Fault Coverage Summary

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Stuck-at Fault | 98% | Scan + LBIST |
| Transition Fault | 95% | At-speed scan |
| Path Delay Fault | 92% | At-speed LBIST |
| Bridging Fault | 95% | LBIST |
| Open Fault | 95% | Connectivity test |

### 6.2 Module-Level Coverage

| Sub-Module | Stuck-at | Transition | Path Delay | Overall |
|------------|----------|------------|------------|---------|
| Dispatch FSM | 98% | 95% | 92% | 96% |
| Thread Scheduler | 98% | 95% | 92% | 96% |
| Pipeline Control | 95% | 93% | 90% | 94% |
| Operator Interface | 95% | 92% | 88% | 93% |
| Memory Interface | 95% | 93% | 90% | 94% |

### 6.3 Test Time Estimation

| Test Type | Duration | Patterns |
|-----------|----------|----------|
| Scan Chain Load/Unload | ~1 ms | 11 chains @ 10 MHz |
| LBIST Execution | ~50 ms | 5,000 patterns |
| Pipeline Test | ~20 ms | Stage tests |
| Thread Test | ~10 ms | Scheduler tests |
| Total Test Time | ~85 ms | All modes combined |

## 7. DFT Implementation Notes

### 7.1 Scan Insertion Guidelines

1. **FSM Scan**: Dispatch FSM 所有状态寄存器插入 scan，覆盖状态转换。
2. **Thread Context**: 线程上下文寄存器完整扫描，支持上下文验证。
3. **Pipeline Register**: Pipeline stage 寄存器独立 scan chain。

### 7.2 LBIST Design Guidelines

1. **At-Speed FSM Test**: LBIST 在 functional clock 下执行 FSM 状态转换。
2. **Self-Checking**: MISR 签名自动比较，输出 pass/fail。
3. **Pattern Reuse**: 公共测试模式可复用于不同配置。

### 7.3 Test Integration

| Integration Point | Description |
|-------------------|-------------|
| M00 Systolic Array | 协同计算单元测试 |
| M09-M12 Operators | 算子单元测试协调 |
| M04 System Bus | 总线协议测试 |
| M15 JTAG Interface | JTAG TAP 接入 |

## 8. References

- IEEE 1149.1: JTAG Standard
- REQ-DFT-001: Test coverage >= 95%
- REQ-COMPUTE-005: Pipeline utilization >= 80%
- M01 MAS.md: Module architecture specification