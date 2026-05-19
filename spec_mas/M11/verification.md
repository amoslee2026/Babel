---
module: M11
type: verification
status: complete
parent: M11/MAS.md
module_type: compute
generated: "2026-05-17T16:00:00+08:00"
---

# M11 Verification Plan: RMSNorm/RoPE Unit

## Overview

M11 RMSNorm/RoPE Unit 验证计划涵盖 RMSNorm 数值精度、RoPE Position Encoding、Combined Flow 三大核心功能。验证目标是确保归一化计算精度误差 < 1e-4，位置编码旋转正确性，以及 RMSNorm+RoPE 组合流水线的高效执行，满足 REQ-COMPUTE-008 规定的算子支持要求。

**验证范围**：

| Category | Description | Priority |
|----------|-------------|----------|
| RMSNorm | 归一化精度、epsilon 处理 | P0 |
| RoPE | 旋转编码、cos/sin 表 | P0 |
| Combined | RMSNorm+RoPE 组合流水 | P0 |
| Precision | FP16/FP32 精度切换 | P1 |

## Functional Coverage Points

### 1. RMSNorm Computation Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_rmsnorm_input` | 输入向量覆盖 (dim=64) | 100% |
| `cp_rmsnorm_ss` | 平方和计算 | 100% |
| `cp_rmsnorm_mean` | 均值计算 (ss/dim) | 100% |
| `cp_rmsnorm_epsilon` | epsilon 加法 (1e-5) | 100% |
| `cp_rmsnorm_rms` | RMS 因子 (1/sqrt(ss+eps)) | 100% |
| `cp_rmsnorm_scale` | 归一化+缩放 (w * rms * x) | 100% |
| `cp_rmsnorm_weight` | 权重向量覆盖 | 100% |
| `cp_rmsnorm_output` | 输出向量覆盖 | 100% |

### 2. RoPE Computation Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_rope_position` | Position 遍历 (0-511) | 100% |
| `cp_rope_head_dim` | Head_dim 遍历 (0-7) | 100% |
| `cp_rope_freq` | 频率计算 | 100% |
| `cp_rope_theta` | Theta = position * freq | 100% |
| `cp_rope_cos` | cos(theta) 计算 | 100% |
| `cp_rope_sin` | sin(theta) 计算 | 100% |
| `cp_rope_rotation` | 旋转矩阵应用 | 100% |
| `cp_rope_pairs` | 32 对元素旋转 | 100% |
| `cp_rope_table` | 预计算表查表 | 100% |

### 3. Combined Operation Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_combined_norm_rope` | RMSNorm → RoPE 流水 | 100% |
| `cp_combined_sram_opt` | SRAM 访问优化 (4 vs 6) | 100% |
| `cp_combined_latency` | 组合延迟 (~15 cycles) | 100% |

### 4. Precision Mode Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_precision_fp16` | FP16 精度模式 | 100% |
| `cp_precision_fp32` | FP32 精度模式 | 100% |
| `cp_precision_switch` | 精度切换 | 100% |

### 5. Pipeline Control Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_fsm_idle` | IDLE 状态 | 100% |
| `cp_fsm_fetch` | FETCH 状态 | 100% |
| `cp_fsm_compute_norm` | COMPUTE_NORM 状态 | 100% |
| `cp_fsm_compute_rope` | COMPUTE_ROPE 状态 | 100% |
| `cp_fsm_write` | WRITE 状态 | 100% |
| `cp_fsm_done` | DONE 状态 | 100% |
| `cp_fsm_all_trans` | 所有状态转换 | 100% |

## Assertion List

### 1. RMSNorm Assertions

```verilog
// A1: Sum of squares positive
assert property (@(posedge clk) ss_valid |-> ss >= 0);

// A2: RMS factor in valid range
assert property (@(posedge clk) rms_valid |-> (rms > 0 && rms <= 10));

// A3: epsilon added correctly
assert property (@(posedge clk) norm_factor_valid |-> norm_factor == (1.0/sqrt(ss/dim + 1e-5)));

// A4: Output dimension matches input
assert property (@(posedge clk) rmsnorm_out_valid |-> out_dim == 64);

// A5: All 64 elements processed
assert property (@(posedge clk) rmsnorm_done |-> processed_cnt == 64);
```

### 2. RoPE Assertions

```verilog
// A6: Position in valid range
assert property (@(posedge clk) rope_start |-> (pos >= 0 && pos <= 511));

// A7: Head_dim modulo head_size
assert property (@(posedge clk) head_dim_valid |-> (head_dim >= 0 && head_dim <= 7));

// A8: Frequency positive
assert property (@(posedge clk) freq_valid |-> freq > 0);

// A9: Rotation pairs count
assert property (@(posedge clk) rotation_done |-> pairs_cnt == 32);

// A10: cos/sin table address valid
assert property (@(posedge clk) table_read |-> (table_addr >= 0 && table_addr < 4096));
```

### 3. Combined Operation Assertions

```verilog
// A11: RMSNorm before RoPE in combined mode
assert property (@(posedge clk) op_type == COMBINED & op_start |-> ##1 fsm_state == COMPUTE_NORM);

// A12: RoPE after RMSNorm in combined mode
assert property (@(posedge clk) fsm_state == COMPUTE_ROPE |-> $past(fsm_state) == COMPUTE_NORM);

// A13: Combined latency constraint
assert property (@(posedge clk) combined_done |-> cycle_count <= 20);

// A14: SRAM access reduced in combined mode
assert property (@(posedge clk) op_type == COMBINED |-> sram_access_cnt == 4);
```

### 4. Precision Assertions

```verilog
// A15: FP16 computation precision
assert property (@(posedge clk) precision == FP16 |-> data_width == 16);

// A16: FP32 computation precision
assert property (@(posedge clk) precision == FP32 |-> data_width == 32);

// A17: Precision switch no data loss
assert property (@(posedge clk) precision_switch |-> ##1 op_error == 0);
```

### 5. FSM Assertions

```verilog
// A18: FSM starts from IDLE
assert property (@(posedge clk) rst_n |-> ##1 fsm_state == IDLE);

// A19: FETCH before COMPUTE
assert property (@(posedge clk) fsm_state == COMPUTE_NORM |-> $past(fsm_state) == FETCH);

// A20: WRITE before DONE
assert property (@(posedge clk) fsm_state == DONE |-> $past(fsm_state) == WRITE);

// A21: Done signal assertion
assert property (@(posedge clk) op_done |-> fsm_state == DONE);

// A22: No deadlock
assert property (@(posedge clk) fsm_state != ERROR |-> ##[1:100] fsm_state != ERROR);
```

## Test Scenarios

### 1. RMSNorm Precision Test (T-RMSN-01)

**Purpose**: 验证 RMSNorm 归一化计算精度

**Golden Reference**: NumPy/PyTorch RMSNorm

```python
import numpy as np

def reference_rmsnorm(x, weight, epsilon=1e-5):
    # x: [dim=64], weight: [dim=64]
    ss = np.sum(x ** 2) / len(x)
    rms = 1.0 / np.sqrt(ss + epsilon)
    return weight * rms * x
```

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| dim | 64 |
| epsilon | 1e-5 |
| precision | FP16, FP32 |
| input_range | [-10, 10] |

**Expected Result**: Hardware output matches golden within tolerance:
- FP32: tolerance = 1e-4
- FP16: tolerance = 1e-3

### 2. RMSNorm Edge Cases Test (T-RMSN-02)

**Purpose**: 验证 RMSNorm 边界条件处理

**Test Cases**:

| Input | Expected Behavior |
|-------|-------------------|
| All zeros | epsilon prevents division by zero |
| Large values (10+) | Normalization to reasonable range |
| Negative values | Correct handling (square eliminates sign) |
| Single element | Still computes mean correctly |

**Expected Result**: All edge cases handled without error

### 3. RoPE Position Encoding Test (T-ROPE-03)

**Purpose**: 验证 RoPE 位置编码旋转正确性

**Golden Reference**: RoPE rotation implementation

```python
import numpy as np

def reference_rope(x, pos, head_size=8, base=10000):
    # x: [dim=64], pos: position index
    dim = len(x)
    out = np.zeros_like(x)
    for i in range(0, dim, 2):
        head_dim = i % head_size
        freq = 1.0 / (base ** (head_dim / head_size))
        theta = pos * freq
        cos_theta = np.cos(theta)
        sin_theta = np.sin(theta)
        out[i] = x[i] * cos_theta - x[i+1] * sin_theta
        out[i+1] = x[i] * sin_theta + x[i+1] * cos_theta
    return out
```

**Test Parameters**:

| Position | Expected Rotation Angle |
|----------|-------------------------|
| pos = 0 | theta = 0 (no rotation) |
| pos = 1 | theta = freq (small rotation) |
| pos = 512 | theta = 512 * freq (max rotation) |

**Expected Result**: Hardware RoPE matches reference within 1e-4

### 4. RoPE Frequency Table Test (T-ROPE-04)

**Purpose**: 验证 RoPE 频率表正确性

**Expected Frequencies (head_size=8)**:

| head_dim | Expected freq |
|----------|---------------|
| 0 | 1.0000 |
| 1 | 0.3162 |
| 2 | 0.1000 |
| 3 | 0.0316 |
| 4 | 0.0100 |
| 5 | 0.0032 |
| 6 | 0.0010 |
| 7 | 0.0003 |

**Expected Result**: Hardware frequencies match expected values within 1e-4

### 5. RoPE Pre-computed Table Test (T-TABLE-05)

**Purpose**: 验证预计算 cos/sin 表查表正确性

**Test Flow**:
1. Enable rope_table_en
2. Verify table address calculation
3. Compare table values with reference cos/sin
4. Verify latency reduction (5 cycles vs 15 cycles)

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| table_size | 4096 floats (16 KB) |
| seq_len | 512 |
| head_size | 8 |

**Expected Result**: Table lookup matches real-time computation within tolerance

### 6. Combined RMSNorm+RoPE Test (T-COMB-06)

**Purpose**: 验证组合流水线正确性和效率

**Golden Reference**: Sequential RMSNorm then RoPE

```python
def reference_combined(x, weight, pos, epsilon=1e-5):
    normalized = reference_rmsnorm(x, weight, epsilon)
    rotated = reference_rope(normalized, pos)
    return rotated
```

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| mode | Combined (op_type = 2) |
| dim | 64 |
| positions | 0, 128, 256, 512 |

**Expected Result**: 
- Output matches sequential golden within tolerance
- Latency ~15 cycles (with table)
- SRAM accesses = 4 (vs 6 in separate mode)

### 7. Precision Mode Test (T-PREC-07)

**Purpose**: 验证 FP16/FP32 精度模式

**Test Matrix**:

| Mode | Data Width | Computation | Tolerance |
|------|------------|-------------|-----------|
| FP16 | 16-bit | FP16 native | 1e-3 |
| FP32 | 32-bit | FP32 native | 1e-4 |

**Expected Result**: Each precision mode matches reference within mode-specific tolerance

### 8. SRAM Interface Test (T-SRAM-08)

**Purpose**: 验证 M02 SRAM 接口正确性

**Test Flow**:
1. Read input data from SRAM
2. Read weight/table from SRAM
3. Write output to SRAM
4. Verify all addresses and data

**Test Parameters**:

| Access Type | Expected Latency |
|-------------|------------------|
| Read | 2 cycles |
| Write | 2 cycles |

**Expected Result**: All SRAM transactions complete without error

### 9. Backpressure Test (T-BP-09)

**Purpose**: 验算子输出阻塞时的行为

**Test Flow**:
1. Set sram_rsp_ready = 0 (block write)
2. Verify FSM stalls in WRITE state
3. Release backpressure
4. Verify operation completes

**Expected Result**: No data loss, operation resumes after backpressure release

### 10. Error Handling Test (T-ERR-10)

**Purpose**: 验证错误检测和恢复

**Test Cases**:

| Error Type | Trigger | Expected Response |
|------------|---------|-------------------|
| Division by zero | ss + eps = 0 | error flag (should not happen) |
| Invalid position | pos > 511 | error flag |
| SRAM error | sram_rsp_error = 1 | error flag, abort |
| Table miss | rope_table_en but no table | fallback to real-time |

### 11. DVFS Test (T-DVFS-11)

**Purpose**: 验证不同频率下的功能

**Test Parameters**:

| OP | Frequency | Expected Latency |
|----|-----------|------------------|
| OP0 | 500 MHz | RMSNorm 10 cycles, RoPE 5 cycles |
| OP1 | 250 MHz | Same cycles, double time |

**Expected Result**: Functionality correct at both frequencies

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
tb_rmsnorm_rope/
  ├── tb_top.sv           # Top-level testbench
  ├── dut_wrapper.sv      # DUT wrapper with interfaces
  ├── interfaces/
  │   ├── sram_if.sv      # M02 SRAM interface
  │   ├── op_ctrl_if.sv   # Operator control interface
  │   ├── data_if.sv      # Input/Output data interface
  ├── drivers/
  │   ├── input_driver.py # Input data driver
  │   ├── weight_driver.py # Weight driver
  │   ├── table_driver.py  # RoPE table driver
  ├── monitors/
  │   ├── output_monitor.py # Output capture
  │   ├── pipeline_monitor.py # Pipeline tracking
  │   ├── coverage_monitor.py # Coverage collection
  ├── checkers/
  │   ├── rmsnorm_checker.py # RMSNorm accuracy
  │   ├── rope_checker.py    # RoPE accuracy
  │   ├── combined_checker.py # Combined validation
  ├── tests/
  │   ├── test_rmsnorm.py
  │   ├── test_rope.py
  │   ├── test_combined.py
  │   ├── test_precision.py
  │   ├── test_table.py
  ├── golden/
  │   ├── reference_rmsnorm.py # NumPy RMSNorm
  │   ├── reference_rope.py    # NumPy RoPE
```

## Schedule

| Phase | Duration | Tasks |
|-------|----------|-------|
| TB Setup | Day 1-2 | Infrastructure, interfaces |
| RMSNorm Tests | Day 3-5 | T-RMSN-01, T-RMSN-02 |
| RoPE Tests | Day 6-8 | T-ROPE-03, T-ROPE-04, T-TABLE-05 |
| Combined Tests | Day 9-10 | T-COMB-06 |
| Precision Tests | Day 11-12 | T-PREC-07, T-SRAM-08 |
| Stress Tests | Day 13-14 | T-BP-09, T-ERR-10, T-DVFS-11 |
| Coverage Closure | Day 15-16 | Coverage analysis |
| Regression | Day 17-18 | Full regression |

**Total**: 18 days