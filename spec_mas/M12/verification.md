---
module: M12
type: verification
status: complete
parent: M12/MAS.md
module_type: compute
generated: "2026-05-17T16:00:00+08:00"
---

# M12 Verification Plan: SoftMax Unit

## Overview

M12 SoftMax Unit 验证计划涵盖 Numerical Stability、Causal Masking、Overflow/Underflow Prevention 三大核心功能。验证目标是确保 SoftMax 概率计算在各种输入条件下数值稳定，输出概率分布正确（sum ≈ 1.0），满足 REQ-SW-003 规定的算子支持要求。

**验证范围**：

| Category | Description | Priority |
|----------|-------------|----------|
| Numerical | Max subtraction 数值稳定性 | P0 |
| Precision | LUT/Taylor/Hybrid 近似精度 | P0 |
| Pipeline | 4-Stage pipeline 流控 | P0 |
| Error | Overflow/Underflow 检测 | P1 |

## Functional Coverage Points

### 1. Numerical Stability Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_max_find` | 最大值查找 (256 elements) | 100% |
| `cp_max_subtract` | input - max subtraction | 100% |
| `cp_normalized_range` | 输入归一化到 [-8, 0] | 100% |
| `cp_exp_safe_range` | exp(x - max) 安全范围 | 100% |
| `cp_sum_positive` | sum(exp) >= 1.0 | 100% |
| `cp_prob_sum_one` | 输出概率 sum ≈ 1.0 | 100% |

### 2. Exponential Approximation Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_exp_lut` | LUT 查表法 (128 entries) | 100% |
| `cp_exp_taylor_o2` | Taylor 2阶展开 | 100% |
| `cp_exp_taylor_o3` | Taylor 3阶展开 | 100% |
| `cp_exp_taylor_o4` | Taylor 4阶展开 | 100% |
| `cp_exp_hybrid` | Hybrid 混合近似 | 100% |
| `cp_exp_accuracy` | 近似精度 < 0.1% | 100% |

### 3. Pipeline Stage Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_stage1_max` | Stage 1 Max Finder (8 cycles) | 100% |
| `cp_stage2_exp` | Stage 2 Exp Approx (2 cycles) | 100% |
| `cp_stage3_sum` | Stage 3 Sum Accumulator (8 cycles) | 100% |
| `cp_stage4_norm` | Stage 4 Normalizer (3 cycles) | 100% |
| `cp_pipeline_full` | 完整 Pipeline (21 cycles) | 100% |
| `cp_pipeline_backpressure` | Pipeline stall handling | 100% |

### 4. Precision Mode Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_precision_fp16` | FP16 精度模式 | 100% |
| `cp_precision_fp8_e4m3` | FP8 E4M3 精度 | 100% |
| `cp_precision_fp8_e5m2` | FP8 E5M2 精度 | 100% |
| `cp_sum_accum_fp32` | FP16 输入用 FP32 累加 | 100% |

### 5. Error Handling Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_err_overflow_input` | 输入溢出检测 | 100% |
| `cp_err_overflow_exp` | exp 溢出检测 | 100% |
| `cp_err_underflow_exp` | exp 下溢检测 | 100% |
| `cp_err_sum_zero` | sum = 0 错误 | 100% |
| `cp_err_precision_loss` | 精度丢失警告 | 100% |
| `cp_err_timeout` | 计算超时 | 100% |

## Assertion List

### 1. Max Finder Assertions

```verilog
// A1: Max value found within 8 cycles
assert property (@(posedge clk) stage1_start |-> ##[1:8] max_val_valid);

// A2: Max value is from input vector
assert property (@(posedge clk) max_val_valid |-> (max_val >= min_input && max_val <= max_input));

// A3: All elements compared
assert property (@(posedge clk) max_done |-> compare_cnt == 255);  // 256-1 comparisons

// A4: Max subtraction result <= 0
assert property (@(posedge clk) normalized_valid |-> normalized <= 0);
```

### 2. Exponential Approximator Assertions

```verilog
// A5: LUT address in valid range
assert property (@(posedge clk) lut_read |-> (lut_addr >= 0 && lut_addr < 128));

// A6: Exp result in valid range [0, 1]
assert property (@(posedge clk) exp_valid |-> (exp_result >= 0 && exp_result <= 1));

// A7: Hybrid mode uses LUT + Taylor
assert property (@(posedge clk) approx_method == HYBRID |-> lut_used & taylor_used);

// A8: Approximation error < 0.1%
assert property (@(posedge clk) exp_valid |-> abs(exp_result - reference) < 0.001);
```

### 3. Sum Accumulator Assertions

```verilog
// A9: Sum positive (at least one exp = 1)
assert property (@(posedge clk) sum_valid |-> sum_val >= 1.0);

// A10: Sum within reasonable range
assert property (@(posedge clk) sum_valid |-> (sum_val >= 1.0 && sum_val <= 256.0));

// A11: FP32 accumulator for FP16 input
assert property (@(posedge clk) precision == FP16 |-> sum_width == 32);

// A12: Sum complete in 8 cycles
assert property (@(posedge clk) stage3_start |-> ##[1:8] sum_valid);
```

### 4. Normalizer Assertions

```verilog
// A13: Division by sum
assert property (@(posedge clk) norm_start |-> sum_val > 0);

// A14: Probability output in [0, 1]
assert property (@(posedge clk) prob_valid |-> (prob >= 0 && prob <= 1));

// A15: Newton-Raphson iterations
assert property (@(posedge clk) norm_method == NEWTON |-> iteration_cnt inside {2, 3});

// A16: Checksum ≈ 1.0
assert property (@(posedge clk) checksum_en & prob_done |-> (checksum >= 0.99 && checksum <= 1.01));
```

### 5. Pipeline Assertions

```verilog
// A17: Pipeline starts from IDLE
assert property (@(posedge clk) rst_n |-> ##1 fsm_state == IDLE);

// A18: Stage sequence correct
assert property (@(posedge clk) fsm_state == STAGE2_EXP |-> $past(fsm_state) == STAGE1_MAX);

// A19: Complete after Stage 4
assert property (@(posedge clk) fsm_state == COMPLETE |-> $past(fsm_state) == STAGE4_NORM);

// A20: Total latency <= 21 cycles
assert property (@(posedge clk) softmax_done |-> cycle_count <= 21);

// A21: Backpressure handling
assert property (@(posedge clk) prob_ready == 0 |-> fsm_state == STAGE4_NORM);
```

### 6. Error Assertions

```verilog
// A22: Overflow flag set when exp > max
assert property (@(posedge clk) exp_overflow |-> error_flag[OVERFLOW_EXP]);

// A23: Underflow flag set when exp < min
assert property (@(posedge clk) exp_underflow |-> error_flag[UNDERFLOW_EXP]);

// A24: Sum zero triggers error
assert property (@(posedge clk) sum_val == 0 |-> error_flag[SUM_ZERO]);

// A25: Error recovery possible
assert property (@(posedge clk) error_flag != 0 |-> ##[1:10] abort_possible);
```

## Test Scenarios

### 1. Max Subtraction Test (T-MAX-01)

**Purpose**: 验证最大值查找和减法归一化

**Golden Reference**: NumPy max subtraction

```python
import numpy as np

def reference_max_subtract(x):
    max_val = np.max(x)
    normalized = x - max_val
    return max_val, normalized
```

**Test Parameters**:

| Input Pattern | Expected Behavior |
|---------------|-------------------|
| All zeros | max = 0, normalized = 0 |
| All same value | max = value, normalized = 0 |
| Large range [0, 100] | max = 100, normalized [-100, 0] |
| Mixed signs [-50, 50] | max = 50, normalized [-100, 0] |

**Expected Result**: Hardware max subtraction matches reference exactly

### 2. Exponential Approximation Test (T-EXP-02)

**Purpose**: 验证 LUT/Taylor/Hybrid 近似精度

**Golden Reference**: NumPy exp function

```python
import numpy as np

def reference_exp(x_normalized):
    return np.exp(x_normalized)  # x_normalized <= 0
```

**Test Matrix**:

| Method | Input Range | Expected Accuracy |
|--------|-------------|-------------------|
| LUT | [-8, 0] | < 0.05% error |
| Taylor-2 | [-2, 0] | < 0.5% error |
| Taylor-3 | [-4, 0] | < 0.1% error |
| Taylor-4 | [-8, 0] | < 0.05% error |
| Hybrid | [-8, 0] | < 0.02% error |

**Expected Result**: Hardware exp matches reference within method-specific tolerance

### 3. LUT Accuracy Test (T-LUT-03)

**Purpose**: 验证 Sigmoid LUT 256 entries 精度

**Test Flow**:
1. Test all 128 LUT entries
2. Test interpolation between entries
3. Compare with reference exp

**Test Points**:

| Test Type | Points | Tolerance |
|-----------|--------|-----------|
| Direct lookup | 128 | < 0.05% |
| Interpolation | 64 | < 0.1% |

**Expected Result**: LUT matches reference within tolerance

### 4. Sum Accumulator Test (T-SUM-04)

**Purpose**: 验证并行累加正确性

**Golden Reference**: NumPy sum

```python
def reference_sum(exp_vec):
    return np.sum(exp_vec)
```

**Test Parameters**:

| Vector Size | Precision | Expected Accuracy |
|--------------|-----------|-------------------|
| 256 elements | FP16 | FP32 accumulator, exact |
| 256 elements | FP8 | FP16 accumulator, < 0.1% error |

**Expected Result**: Hardware sum matches reference within tolerance

### 5. Normalizer Test (T-NORM-05)

**Purpose**: 验证 Newton-Raphson 除法归一化

**Golden Reference**: Standard division

```python
def reference_normalize(exp_vec, sum_val):
    return exp_vec / sum_val
```

**Test Parameters**:

| Iterations | Expected Accuracy |
|------------|-------------------|
| 1 iteration | ~5% error (fast) |
| 2 iterations | ~1% error |
| 3 iterations | ~0.1% error (accurate) |

**Expected Result**: Hardware division matches reference within iteration-specific tolerance

### 6. Probability Sum Test (T-PROB-06)

**Purpose**: 验证输出概率分布 sum ≈ 1.0

**Test Flow**:
1. Compute SoftMax for various inputs
2. Sum output probabilities
3. Verify sum ≈ 1.0

**Test Parameters**:

| Precision | Expected Sum Range |
|-----------|-------------------|
| FP32 | [0.9999, 1.0001] |
| FP16 | [0.99, 1.01] |
| FP8 | [0.95, 1.05] |

**Expected Result**: Sum of probabilities within expected range

### 7. Numerical Stability Test (T-STABLE-07)

**Purpose**: 验证大输入数值稳定性

**Test Cases**:

| Input | Expected Behavior |
|-------|-------------------|
| [1000, 1000, 1000] | All probabilities = 1/3 |
| [0, 1000, 2000] | Prob[0] ≈ 0, Prob[1] ≈ 0, Prob[2] ≈ 1 |
| [-1000, -1000, -1000] | All probabilities = 1/3 |
| [1e10, 1e10, 1e10] | No overflow, all equal |

**Expected Result**: No overflow/underflow, valid probability distribution

### 8. Overflow/Underflow Test (T-OFUF-08)

**Purpose**: 验证溢出和下溢检测

**Test Cases**:

| Condition | Trigger | Expected Response |
|-----------|---------|-------------------|
| Input overflow | input > FP16 max | Saturate + error flag |
| Exp overflow | exp(x) > FP16 max | Saturate to max + flag |
| Exp underflow | exp(x) < FP16 min | Saturate to 0 + flag |
| Sum zero | all inputs same = -inf | error flag |

**Expected Result**: Appropriate error flags and saturated outputs

### 9. Pipeline Backpressure Test (T-BP-09)

**Purpose**: 验证输出阻塞时的 Pipeline 行为

**Test Flow**:
1. Set prob_ready = 0 (block output)
2. Verify Stage 4 stalls
3. Release backpressure
4. Verify pipeline resumes

**Expected Result**: No data loss, pipeline resumes after backpressure release

### 10. Causal Mask Support Test (T-CAUSAL-10)

**Purpose**: 验证与 M09 Causal Masking 协作

**Test Flow**:
1. Input score vector with masked positions (-inf)
2. Verify masked positions yield prob = 0
3. Verify unmasked positions normalize correctly

**Expected Result**: 
- Masked positions: prob = 0
- Unmasked positions: valid probability distribution
- Sum of unmasked ≈ 1.0

### 11. Precision Mode Test (T-PREC-11)

**Purpose**: 验证 FP16/FP8 精度模式

**Test Matrix**:

| Mode | Input | Accumulator | Output | Tolerance |
|------|-------|-------------|--------|-----------|
| FP16 | FP16 | FP32 | FP16 | 0.01 |
| FP8 E4M3 | FP8 | FP16 | FP8 | 0.05 |
| FP8 E5M2 | FP8 | FP16 | FP8 | 0.05 |

**Expected Result**: Each precision mode output valid within tolerance

### 12. Attention Score Integration Test (T-ATTN-12)

**Purpose**: 验证与 M09 Attention Unit 协作

**Test Flow**:
1. Receive score vector from M09
2. Process SoftMax
3. Return attention weights
4. Verify weights used correctly by M09

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| score_len | 1, 16, 64, 256, 512 |
| n_heads | 8 |
| layer | 0-4 |

**Expected Result**: M09 attention output matches golden reference

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
| NumPy | Golden reference | 1.x |
| PyTorch | Alternative golden | 2.x |

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
tb_softmax_unit/
  ├── tb_top.sv           # Top-level testbench
  ├── dut_wrapper.sv      # DUT wrapper with interfaces
  ├── interfaces/
  │   ├── score_if.sv     # Score input interface
  │   ├── prob_if.sv      # Probability output interface
  │   ├── ctrl_if.sv      # Control interface
  │   ├── lut_if.sv       # LUT table interface
  ├── drivers/
  │   ├── score_driver.py # Score vector driver
  │   ├── config_driver.py # Configuration driver
  ├── monitors/
  │   ├── prob_monitor.py  # Probability output capture
  │   ├── pipeline_monitor.py # Pipeline stage tracking
  │   ├── coverage_monitor.py # Coverage collection
  ├── checkers/
  │   ├── exp_checker.py   # Exponential accuracy
  │   ├── sum_checker.py   # Sum verification
  │   ├── prob_checker.py  # Probability validation
  │   ├── checksum_checker.py # Sum ≈ 1.0 verification
  ├── tests/
  │   ├── test_max_subtract.py
  │   ├── test_exp_approx.py
  │   ├── test_lut.py
  │   ├── test_sum.py
  │   ├── test_normalizer.py
  │   ├── test_numerical_stability.py
  │   ├── test_overflow.py
  │   ├── test_pipeline.py
  ├── golden/
  │   ├── reference_softmax.py # NumPy SoftMax
  │   ├── reference_exp.py     # NumPy exp
```

## Schedule

| Phase | Duration | Tasks |
|-------|----------|-------|
| TB Setup | Day 1-2 | Infrastructure, interfaces |
| Basic Tests | Day 3-5 | T-MAX-01, T-EXP-02, T-LUT-03 |
| Pipeline Tests | Day 6-8 | T-SUM-04, T-NORM-05, T-PROB-06 |
| Stability Tests | Day 9-11 | T-STABLE-07, T-OFUF-08 |
| Integration Tests | Day 12-14 | T-CAUSAL-10, T-ATTN-12 |
| Stress Tests | Day 15-16 | T-BP-09, T-PREC-11 |
| Coverage Closure | Day 17-18 | Coverage analysis |
| Regression | Day 19-20 | Full regression |

**Total**: 20 days