---
module: M01_DataflowController
type: verification
status: complete
parent: M01
module_type: control
generated: "2026-05-17T16:00:00+08:00"
---

# M01: Dataflow Controller Verification Plan

## 1. Overview

M01 Dataflow Controller 是 TinyStories NPU 的数据流调度控制器，负责 Spatial Dataflow 流水线调度、算子分发、多线程管理和内存一致性维护。验证目标是确保 Pipeline Utilization >= 80%、算子调度正确性、线程切换 <= 4 cycles、混合精度支持。

### 1.1 Verification Targets

| Metric | Target | REQ Reference |
|--------|--------|---------------|
| Pipeline Utilization | >= 80% | REQ-COMPUTE-005 |
| Operator Dispatch | 100% correct | REQ-COMPUTE-008 |
| Thread Switch Latency | <= 4 cycles | REQ-COMPUTE-006 |
| Thread Count | >= 2 threads | REQ-COMPUTE-006 |
| Precision Coverage | All combinations | REQ-COMPUTE-007 |
| Memory Coherence | Zero conflicts | Internal |

### 1.2 Verification Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 5.x | RTL simulation + coverage |
| Cocotb | 1.x | Python test framework |
| Formal | Yosys/ABC | Scheduler assertion proof |
| SystemC | TLM modeling | Pipeline performance model |

## 2. Functional Coverage Points

| ID | Feature | Description | Priority | Coverage Target |
|----|---------|-------------|----------|-----------------|
| FC-001 | Pipeline Schedule | Spatial dataflow pipeline stages | P0 | 100% |
| FC-002 | PE Assignment | PE array assignment to operators | P0 | 100% |
| FC-003 | Output Routing | Operator output routing to SRAM | P0 | 100% |
| FC-004 | Thread Round-Robin | T0/T1 Round-Robin scheduling | P0 | 100% |
| FC-005 | Thread Priority Boost | Priority boost mechanism | P1 | 100% |
| FC-006 | Thread Yield | Yield at operator boundary | P1 | 100% |
| FC-007 | Context Switch | Thread context save/restore | P0 | 100% |
| FC-008 | Op Dispatch Attention | Attention operator dispatch | P0 | 100% |
| FC-009 | Op Dispatch FFN | FFN operator dispatch | P0 | 100% |
| FC-010 | Op Dispatch RMSNorm | RMSNorm operator dispatch | P0 | 100% |
| FC-011 | Op Dispatch RoPE | RoPE operator dispatch | P0 | 100% |
| FC-012 | Op Dispatch SoftMax | SoftMax operator dispatch | P0 | 100% |
| FC-013 | Memory Request SRAM | SRAM scratchpad access | P0 | 100% |
| FC-014 | Memory Request DRAM | DRAM controller access | P0 | 100% |
| FC-015 | SRAM Allocation | Region allocation/deallocation | P1 | 100% |
| FC-016 | Data Dependency | Dependency check correctness | P0 | 100% |
| FC-017 | Precision FP32 | FP32 precision mode | P1 | 100% |
| FC-018 | Precision FP16 | FP16 precision mode | P0 | 100% |
| FC-019 | Precision INT8 | INT8 precision mode | P0 | 100% |
| FC-020 | Precision FP8 | FP8 precision mode | P0 | 100% |
| FC-021 | Precision Mixed | Mixed precision combinations | P0 | 100% |
| FC-022 | Pipeline Stall | Memory stall handling | P1 | 100% |
| FC-023 | Pipeline Bubble | Bubble injection/elimination | P2 | 95% |
| FC-024 | DVFS Transition | DVFS operating point switch | P1 | 100% |
| FC-025 | Interrupt Generation | IRQ on operator completion | P0 | 100% |
| FC-026 | Error Handling | Error detection and reporting | P0 | 100% |
| FC-027 | Utilization Counter | Pipeline utilization measurement | P1 | 100% |
| FC-028 | Perf Counter | Performance counter accuracy | P1 | 100% |
| FC-029 | Instruction Queue | Op queue depth management | P1 | 100% |
| FC-030 | Pipeline Flush | Flush on error/reset | P1 | 100% |

## 3. Assertion List

| ID | Type | Assertion | Description |
|----|------|-----------|-------------|
| AS-001 | Immediate | `syst_mode == 0 || syst_mode == 1` | WS/OS mode valid |
| AS-002 | Immediate | `syst_precision <= 3` | Precision valid |
| AS-003 | Immediate | `syst_row_cnt <= 127` | Row count valid |
| AS-004 | Immediate | `syst_col_cnt <= 127` | Column count valid |
| AS-005 | Immediate | `op_unit_sel in {1,2,3,4}` | Operator unit valid |
| AS-006 | Immediate | `op_tid in {0,1}` | Thread ID valid |
| AS-007 | Cover | `pipeline_utilization >= 80%` | REQ-COMPUTE-005 |
| AS-008 | Cover | `context_switch_latency <= 4` | REQ-COMPUTE-006 |
| AS-009 | Cover | `thread_count >= 2` | REQ-COMPUTE-006 |
| AS-010 | Concurrent | `op_valid -> op_ready or wait` | Handshake protocol |
| AS-011 | Concurrent | `op_done -> irq_op_done or clear` | Completion handling |
| AS-012 | Immediate | `sram_addr in valid_range` | Address valid |
| AS-013 | Concurrent | `dispatch_complete -> next_op_fetch` | Dispatch sequence |
| AS-014 | Concurrent | `syst_done -> op_done or syst_mode_switch` | Completion response |
| AS-015 | Immediate | `mem_req_addr >= 0x8000_0000 || < 0x8000_0000` | Address routing |
| AS-016 | Cover | `all_precision_combinations` | REQ-COMPUTE-007 |
| AS-017 | Concurrent | `thread_switch -> context_saved` | Context integrity |
| AS-018 | Cover | `sram_allocation_correct` | Allocation accuracy |
| AS-019 | Immediate | `pipeline_stage_valid` | Stage encoding valid |
| AS-020 | Concurrent | `error_detected -> irq_err` | Error interrupt |
| AS-021 | Cover | `perf_counter_increment` | Counter accuracy |
| AS-022 | Immediate | `sched_status in {idle,run,wait}` | Status valid |
| AS-023 | Concurrent | `yield_request -> thread_switch` | Yield handling |
| AS-024 | Cover | `dataflow_latency_measured` | Latency tracking |

## 4. Test Scenarios

### 4.1 Normal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TN-001 | Single Thread Attention | T0 runs Attention | Q,K,V tensors | Correct attention output |
| TN-002 | Single Thread FFN | T0 runs FFN | X tensor, W1/W2 weights | Correct FFN output |
| TN-003 | Single Thread RMSNorm | T0 runs RMSNorm | X tensor, weight | Normalized output |
| TN-004 | Single Thread RoPE | T0 runs RoPE | X tensor, freq | Position-encoded output |
| TN-005 | Dual Thread Parallel | T0/T1 concurrent ops | Two op streams | Both complete correctly |
| TN-006 | Round-Robin Switch | T0->T1->T0 cycle | Alternating ops | Fair scheduling |
| TN-007 | Priority Boost | Long wait thread boost | Priority config | Boost mechanism active |
| TN-008 | Yield at Boundary | Op completion yield | Yield request | Smooth thread switch |
| TN-009 | Context Save Restore | Thread switch | Context data | Context preserved |
| TN-010 | Full Pipeline Flow | Stage 0-4 complete | Full dataflow | All stages correct |
| TN-011 | FP16 Precision | FP16 mode ops | FP16 tensors | Correct precision handling |
| TN-012 | INT8 Precision | INT8 mode ops | INT8 tensors | Correct quantization |
| TN-013 | FP8 Precision | FP8 mode ops | FP8 tensors | Correct FP8 handling |
| TN-014 | Mixed Precision | FP16 input + INT8 weight | Mixed tensors | Correct accumulation |
| TN-015 | SRAM Read Request | SRAM data fetch | Valid address | Correct data returned |
| TN-016 | SRAM Write Request | SRAM data store | Valid address, data | Data stored correctly |
| TN-017 | DRAM Read Request | DRAM data fetch | Valid address | Correct data returned |
| TN-018 | Pipeline Utilization | Measure utilization | Full pipeline run | Utilization >= 80% |
| TN-019 | Perf Counter Accuracy | Counter increment | Op completions | Accurate count |
| TN-020 | Interrupt Generation | IRQ on completion | Op done signal | IRQ generated |
| TN-021 | Instruction Queue | Queue depth test | Multiple ops | Queue management correct |
| TN-022 | DVFS OP0-OP1 | Frequency switch | DVFS request | Seamless transition |
| TN-023 | Memory Prefetch | Prefetch mechanism | Next op data | Prefetch correct |
| TN-024 | Operator Overlap | Pipeline overlap | Concurrent stages | Overlap effective |
| TN-025 | Memory Stall Hide | Thread interleaving | Stall scenario | Latency hidden |

### 4.2 Boundary Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TB-001 | Min Thread 1 | Single thread mode | T0 only | T0 completes all ops |
| TB-002 | Thread Switch Timing | Measure switch latency | Context switch | Latency <= 4 cycles |
| TB-003 | Op Queue Full | Queue at max depth | Queue depth limit | Queue full handling |
| TB-004 | Op Queue Empty | Queue empty fetch | Empty queue | Idle state correctly |
| TB-005 | Max PE Assignment | Full array assignment | syst_row_cnt=127 | Full array used |
| TB-006 | Min PE Assignment | Single PE | syst_row_cnt=1 | Single PE used |
| TB-007 | SRAM Region Boundary | Region allocation edge | Boundary address | Correct allocation |
| TB-008 | Pipeline Full Load | All stages active | Maximum throughput | Utilization peak |
| TB-009 | Precision All FP32 | Baseline precision | FP32 mode | Correct FP32 ops |
| TB-010 | Interrupt Rate Max | High IRQ frequency | Rapid op completions | IRQ handling stable |
| TB-011 | DVFS All Points | All operating points | OP0/OP1/OP2 | All transitions correct |
| TB-012 | Memory Max BW | Bandwidth saturation | Max requests | BW limit handling |

### 4.3 Abnormal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TA-001 | Invalid Op Code | op_code = 0xFF | Illegal opcode | Error flag |
| TA-002 | Invalid Unit Sel | op_unit_sel = 0 | No unit selected | Error flag |
| TA-003 | Invalid Thread ID | op_tid = 2 | Out of range | Error flag |
| TA-004 | SRAM Addr Invalid | addr outside range | Bad address | Error flag |
| TA-005 | DRAM Addr Invalid | addr >= 0x8000_0000 | DRAM overflow | Error flag |
| TA-006 | Memory Timeout | No response | Timeout trigger | Timeout handling |
| TA-007 | Operator Error | op_err != 0 | Operator error | Error propagation |
| TA-008 | Pipeline Flush Error | Flush mid-op | Error trigger | Flush complete |
| TA-009 | Thread Starvation | Long wait thread | Priority issue | Boost mechanism |
| TA-010 | Queue Overflow | Too many ops | Queue overflow | Overflow handling |
| TA-011 | Precision Mismatch | Invalid precision combo | Illegal combo | Error flag |
| TA-012 | DVFS Under Compute | Switch during op | DVFS request | Deferred switch |
| TA-013 | Systolic Error | syst_err != 0 | PE error | Error handling |
| TA-014 | Double Yield | Yield twice | Double yield request | Second ignored |

## 5. Coverage Targets

| Category | Target | Metric |
|----------|--------|--------|
| Code Coverage | 100% | Line, branch, toggle, FSM |
| Functional Coverage | 95% | All FC points hit |
| Assertion Coverage | 100% | All AS covered |
| Corner Case Coverage | 95% | Boundary + abnormal scenarios |
| Performance Coverage | 100% | Utilization, latency metrics verified |

### 5.1 Code Coverage Details

| Type | Target | Description |
|------|--------|-------------|
| Line Coverage | 100% | All RTL lines executed |
| Branch Coverage | 100% | All if/case branches taken |
| Toggle Coverage | 100% | All signals 0->1 and 1->0 |
| FSM Coverage | 100% | All dispatch/scheduler FSM states |
| Expression Coverage | 95% | All expression conditions |

### 5.2 Functional Coverage Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Pipeline Utilization | >= 80% | Cycle counter measurement |
| Thread Switch Latency | <= 4 cycles | Timing measurement |
| Thread Count | >= 2 | Configuration check |
| Precision Coverage | All combinations | Cross-product test |
| Operator Coverage | All operators | All op_code tested |

## 6. Verification Tools

### 6.1 Simulation Environment

| Component | Tool | Configuration |
|-----------|------|---------------|
| RTL Simulator | Verilator 5.x | --coverage + --trace |
| Test Framework | Cocotb | Python-based test cases |
| Performance Model | SystemC TLM | Pipeline throughput model |
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
| Scheduler FSM | Yosys Sby | State transition proof |
| Thread Switch | Sby | Context save correctness |
| Arbitration | Sby | No starvation proof |

### 6.4 Test Execution Flow

```
1. Build RTL with Verilator + coverage
2. Run Normal scenarios (TN-001 to TN-025)
3. Run Boundary scenarios (TB-001 to TB-012)
4. Run Abnormal scenarios (TA-001 to TA-014)
5. Collect coverage data
6. Analyze coverage report
7. Fill coverage holes if < target
8. Generate verification report
```

## 7. References

- REQ-COMPUTE-005: Pipeline utilization >= 80%
- REQ-COMPUTE-006: Multi-thread >= 2
- REQ-COMPUTE-007: Mixed precision support
- REQ-COMPUTE-008: Transformer operator coverage
- REQ-PWR-003: DVFS >= 2 operating points
- MAS: /spec_mas/M01/MAS.md
- FSM: /spec_mas/M01/FSM.md
- Datapath: /spec_mas/M01/datapath.md