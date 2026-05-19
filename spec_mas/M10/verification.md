---
module: M10
type: verification
status: complete
parent: M10/MAS.md
module_type: compute
generated: "2026-05-17T16:00:00+08:00"
---

# M10 Verification Plan: FFN/MatMul Unit

## Overview

M10 FFN/MatMul Unit 验证计划涵盖 FFN Pipeline、MatMul Dispatch、Activation Functions (GELU/SiLU/ReLU) 三大核心功能。验证目标是确保 Transformer FFN 层完整流水线和通用矩阵乘法在多种精度模式下的正确性，满足 REQ-COMPUTE-008 规定的算子支持要求。

**验证范围**：

| Category | Description | Priority |
|----------|-------------|----------|
| Functional | FFN Pipeline 完整流程 | P0 |
| MatMul | M00 Systolic Array 调度 | P0 |
| Activation | GELU/SiLU/ReLU 精度 | P0 |
| Mode | MatMul Only / FFN Complete / Activation Only | P1 |

## Functional Coverage Points

### 1. FFN Pipeline Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_ffn_w1_matmul` | w1 MatMul (dim → hidden) | 100% |
| `cp_ffn_w3_matmul` | w3 MatMul (dim → hidden) | 100% |
| `cp_ffn_w1w3_parallel` | w1/w3 并行执行 | 100% |
| `cp_ffn_silu` | SiLU 激活函数 | 100% |
| `cp_ffn_gate` | SwiGLU gating (SiLU * w3_out) | 100% |
| `cp_ffn_w2_matmul` | w2 MatMul (hidden → dim) | 100% |
| `cp_ffn_complete` | 完整 FFN 流水线 | 100% |

### 2. MatMul Dispatch Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_mmul_cmd_mmul` | CMD_MMUL (0x1) 矩阵向量乘 | 100% |
| `cp_mmul_cmd_mload` | CMD_MLOAD (0x2) 预加载权重 | 100% |
| `cp_mmul_cmd_mset` | CMD_MSET (0x3) 设置维度 | 100% |
| `cp_mmul_dim_64` | dim=64 (input dimension) | 100% |
| `cp_mmul_dim_256` | dim=256 (hidden dimension) | 100% |
| `cp_mmul_dim_512` | dim=512 (vocab size) | 100% |
| `cp_mmul_handshake` | M00 handshake 协议 | 100% |

### 3. Activation Function Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_act_sigmoid_lut` | Sigmoid 查表 (256 entries) | 100% |
| `cp_act_silu` | SiLU = x * sigmoid(x) | 100% |
| `cp_act_gelu` | GELU 激活函数 | 100% |
| `cp_act_relu` | ReLU 激活函数 | 100% |
| `cp_act_input_range` | 输入范围 [-8, 8] | 100% |
| `cp_act_saturation` | 饱和边界处理 | 100% |

### 4. Operation Mode Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_mode_matmul_only` | mode=0x0 MatMul Only | 100% |
| `cp_mode_ffn_complete` | mode=0x1 FFN Complete | 100% |
| `cp_mode_act_only` | mode=0x2 Activation Only | 100% |
| `cp_mode_switch` | 模式切换无死锁 | 100% |

### 5. Precision Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_precision_fp32` | FP32 全精度 | 100% |
| `cp_precision_fp16` | FP16 精度 | 100% |
| `cp_precision_int8` | INT8 量化 | 100% |

## Assertion List

### 1. Interface Assertions

```verilog
// A1: Input valid implies ready within timeout
assert property (@(posedge clk) x_valid |-> ##[1:8] x_ready);

// A2: Systolic Array command handshake
assert property (@(posedge clk) sa_cmd_valid & sa_cmd_ready |-> ##1 sa_cmd_sent);

// A3: M00 result handshake
assert property (@(posedge clk) sa_done |-> ##[1:512] sa_result_valid);

// A4: Output valid after completion
assert property (@(posedge clk) fsm_state == OUTPUT |-> ##1 y_valid);

// A5: Error flag indicates abnormal condition
assert property (@(posedge clk) error |-> (sa_timeout | lut_error | overflow));
```

### 2. Pipeline Assertions

```verilog
// A6: w1/w3 parallel start
assert property (@(posedge clk) fsm_state == MATMUL_W1W3 |-> w1_start & w3_start);

// A7: Activation after w1/w3 complete
assert property (@(posedge clk) fsm_state == ACTIVATION |-> $past(sa_done));

// A8: w2 after activation complete
assert property (@(posedge clk) fsm_state == MATMUL_W2 |-> $past(activation_done));

// A9: Pipeline completion sequence
assert property (@(posedge clk) done |-> ##1 fsm_state == IDLE);

// A10: Pipeline depth constraint
assert property (@(posedge clk) cycle_count <= 328);  // FFN Complete max latency
```

### 3. Activation Assertions

```verilog
// A11: Sigmoid output in [0, 1]
assert property (@(posedge clk) sigmoid_out_valid |-> (sigmoid_out >= 0 && sigmoid_out <= 1));

// A12: SiLU output range
assert property (@(posedge clk) silu_out_valid |-> (silu_out >= -8 && silu_out <= 8));

// A13: GELU output range
assert property (@(posedge clk) gelu_out_valid |-> (gelu_out >= -8 && gelu_out <= 8));

// A14: ReLU output >= 0
assert property (@(posedge clk) relu_out_valid |-> relu_out >= 0);

// A15: LUT address in valid range
assert property (@(posedge clk) lut_read |-> (lut_addr >= 0 && lut_addr <= 255));
```

### 4. FSM Assertions

```verilog
// A16: FSM starts from IDLE
assert property (@(posedge clk) rst_n |-> ##1 fsm_state == IDLE);

// A17: No invalid state transition
assert property (@(posedge clk) fsm_state == MATMUL_W1W3 |-> ##1 fsm_state inside {WAIT_SA1, ERROR});

// A18: Done after complete pipeline
assert property (@(posedge clk) done |-> $past(fsm_state) == OUTPUT);

// A19: No deadlock in FSM
assert property (@(posedge clk) fsm_state != ERROR |-> ##[1:1000] fsm_state != ERROR);

// A20: Busy flag during operation
assert property (@(posedge clk) fsm_state != IDLE |-> busy);
```

## Test Scenarios

### 1. FFN Complete Test (T-FFN-01)

**Purpose**: 验证完整 FFN 流水线 (SwiGLU)

**Golden Reference**: PyTorch SwiGLU implementation

```python
import torch
import torch.nn.functional as F

def reference_ffn(x, w1, w3, w2):
    # x: [dim=64], w1/w3: [hidden=256, dim=64], w2: [dim=64, hidden=256]
    w1_out = torch.matmul(w1, x)      # [256]
    w3_out = torch.matmul(w3, x)      # [256]
    silu_out = F.silu(w1_out)         # SiLU activation
    gate_out = silu_out * w3_out      # SwiGLU gating
    y = torch.matmul(w2, gate_out)    # [64]
    return y
```

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| dim | 64 |
| hidden_dim | 256 |
| precision | FP16, FP32 |
| layer | 0-4 |

**Expected Result**: Hardware output matches golden reference within tolerance:
- FP32: tolerance = 1e-5
- FP16: tolerance = 1e-3

### 2. MatMul Dispatch Test (T-MMUL-02)

**Purpose**: 验证 M00 Systolic Array 调度正确性

**Test Flow**:
1. Issue CMD_MMUL with various dimensions
2. Verify M00 command handshake
3. Compare MatMul result with golden
4. Verify latency matches expected cycles

**Test Parameters**:

| MatMul Type | Dimension | Expected Latency |
|-------------|-----------|------------------|
| w1 | (256, 64) | 256 cycles |
| w3 | (256, 64) | 256 cycles |
| w2 | (64, 256) | 64 cycles |
| wcls | (512, 64) | 512 cycles |

**Expected Result**: MatMul results match NumPy golden, latency within tolerance

### 3. Sigmoid LUT Test (T-SIG-03)

**Purpose**: 验证 Sigmoid 查表精度

**Golden Reference**: Standard sigmoid function

```python
def reference_sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))
```

**Test Parameters**:

| Input Range | Test Points | Tolerance |
|-------------|-------------|-----------|
| [-8, -4] | 64 points | 0.1% |
| [-4, 0] | 64 points | 0.05% |
| [0, 4] | 64 points | 0.05% |
| [4, 8] | 64 points | 0.1% |

**Expected Result**: LUT sigmoid matches reference within tolerance (< 0.1% error)

### 4. SiLU Activation Test (T-SILU-04)

**Purpose**: 验证 SiLU 激活函数

**Golden Reference**: SiLU = x * sigmoid(x)

```python
def reference_silu(x):
    return x * (1.0 / (1.0 + np.exp(-x)))
```

**Test Parameters**:

| Input | Expected Output |
|-------|-----------------|
| x = 0 | 0 |
| x = 1 | 0.7311 |
| x = -1 | -0.2689 |
| x = 8 | ~8 (sigmoid ≈ 1) |
| x = -8 | ~-0.003 (sigmoid ≈ 0) |

**Expected Result**: Hardware SiLU matches reference within 0.1%

### 5. GELU Activation Test (T-GELU-05)

**Purpose**: 验证 GELU 激活函数

**Golden Reference**: GELU approximation

```python
def reference_gelu(x):
    return 0.5 * x * (1 + np.tanh(np.sqrt(2/np.pi) * (x + 0.044715 * x**3)))
```

**Test Parameters**:

| Input | Tolerance |
|-------|-----------|
| [-8, 8] | 0.5% |

**Expected Result**: Hardware GELU matches reference within tolerance

### 6. ReLU Activation Test (T-RELU-06)

**Purpose**: 验证 ReLU 激活函数

**Golden Reference**: ReLU(x) = max(0, x)

**Test Parameters**:

| Input | Expected Output |
|-------|-----------------|
| x = -5 | 0 |
| x = 0 | 0 |
| x = 5 | 5 |

**Expected Result**: Hardware ReLU matches reference exactly

### 7. w1/w3 Parallelism Test (T-PAR-07)

**Purpose**: 验证 w1 和 w3 MatMul 并行执行

**Test Flow**:
1. Start FFN Complete mode
2. Measure w1 and w3 start time
3. Verify both start simultaneously
4. Verify completion time matches parallel execution

**Expected Result**: 
- w1 and w3 start within same cycle
- Total latency = 256 + 8 + 64 = 328 cycles (not 512 + 8 + 64)

### 8. Mode Switching Test (T-MODE-08)

**Purpose**: 验证操作模式切换无死锁

**Test Flow**:
1. Execute MatMul Only mode
2. Switch to FFN Complete mode
3. Switch to Activation Only mode
4. Verify no deadlock or hang

**Expected Result**: All mode transitions complete successfully

### 9. Backpressure Test (T-BP-09)

**Purpose**: 验证输出阻塞时的 Pipeline 行为

**Test Flow**:
1. Set y_ready = 0 (block output)
2. Verify pipeline stalls
3. Release backpressure
4. Verify pipeline resumes correctly

**Expected Result**: No data loss, pipeline resumes after backpressure release

### 10. Error Handling Test (T-ERR-10)

**Purpose**: 验证错误检测和恢复

**Test Cases**:

| Error Type | Trigger | Expected Response |
|------------|---------|-------------------|
| SA timeout | M00 response timeout | error flag, FSM to ERROR |
| LUT error | Invalid LUT address | error flag |
| Overflow | Activation overflow | saturate, error flag |
| Invalid dim | dim > max_dim | error flag, abort |

### 11. Precision Mode Test (T-PREC-11)

**Purpose**: 验证 FP32/FP16/INT8 精度模式

**Test Matrix**:

| Mode | Input | Activation | Output | Tolerance |
|------|-------|------------|--------|-----------|
| FP32 | FP32 | FP32 | FP32 | 1e-5 |
| FP16 | FP16 | FP16 | FP16 | 1e-3 |
| INT8 | INT8 | FP16 | FP16 | 0.5% |

**Expected Result**: Each precision mode output matches reference within mode-specific tolerance

## Coverage Targets

| Category | Target | Weight |
|----------|--------|--------|
| Functional Coverage | 95% | 40% |
| Code Coverage (Line) | 80% | 20% |
| FSM Coverage (State) | 100% | 15% |
| FSM Coverage (Transition) | 100% | 15% |
| Assertion Coverage | 100% | 10% |

**Total Target**: 95%

## Verification Tools

### Simulation Environment

| Tool | Purpose | Version |
|------|---------|---------|
| Verilator | RTL simulation | 5.x |
| Cocotb | Python test framework | 1.x |
| PyTorch | Golden reference | 2.x |
| NumPy | Numerical validation | 1.x |

### Coverage Analysis

| Tool | Purpose |
|------|---------|
| Verilator coverage | Code coverage |
| Custom functional coverage | Covergroup analysis |
| Assertion coverage | SVA coverage |

### Waveform Analysis

| Tool | Purpose |
|------|---------|
| GTKWave | Waveform viewing |
| Surfer | Interactive debug |

## Testbench Architecture

```
tb_ffn_matmul/
  ├── tb_top.sv           # Top-level testbench
  ├── dut_wrapper.sv      # DUT wrapper with interfaces
  ├── interfaces/
  │   ├── systolic_if.sv  # M00 Systolic Array interface
  │   ├── bus_if.sv       # M04 System Bus interface
  │   ├── data_if.sv      # Input/Output data interface
  ├── drivers/
  │   ├── input_driver.py # Input data driver
  │   ├── sa_driver.py    # Systolic Array mock
  │   ├── weight_driver.py # Weight loader
  ├── monitors/
  │   ├── output_monitor.py # Output capture
  │   ├── pipeline_monitor.py # Pipeline stage tracking
  │   ├── coverage_monitor.py # Coverage collection
  ├── checkers/
  │   ├── ffn_checker.py    # FFN output validation
  │   ├── activation_checker.py # Activation accuracy
  │   ├── latency_checker.py # Latency verification
  ├── tests/
  │   ├── test_ffn_complete.py
  │   ├── test_matmul_dispatch.py
  │   ├── test_activation.py
  │   ├── test_parallelism.py
  │   ├── test_mode_switch.py
  ├── golden/
  │   ├── reference_ffn.py     # PyTorch FFN golden
  │   ├── reference_activation.py # Activation golden
```

## Schedule

| Phase | Duration | Tasks |
|-------|----------|-------|
| TB Setup | Day 1-2 | Infrastructure, interfaces, mock M00 |
| Basic Tests | Day 3-5 | T-FFN-01, T-MMUL-02, T-SIG-03 |
| Activation Tests | Day 6-8 | T-SILU-04, T-GELU-05, T-RELU-06 |
| Pipeline Tests | Day 9-11 | T-PAR-07, T-MODE-08 |
| Stress Tests | Day 12-14 | T-BP-09, T-ERR-10, T-PREC-11 |
| Coverage Closure | Day 15-17 | Coverage analysis, fill holes |
| Regression | Day 18-20 | Full regression |

**Total**: 20 days