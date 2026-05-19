---
module: M09
type: verification
status: complete
parent: M09/MAS.md
module_type: compute
generated: "2026-05-17T16:00:00+08:00"
---

# M09 Verification Plan: Attention Unit

## Overview

M09 Attention Unit 验证计划涵盖 Multi-Head Attention、Causal Masking、KV Cache Interface、MQA Optimization 四大核心功能。验证目标是确保 Transformer Attention 算子在 FP8/FP16/INT8 混合精度下的计算正确性，满足 REQ-COMPUTE-008 规定的算子支持要求。

**验证范围**：

| Category | Description | Priority |
|----------|-------------|----------|
| Functional | Multi-Head Attention 计算正确性 | P0 |
| Numerical | Score 精度、SoftMax 稳定性 | P0 |
| Interface | KV Cache、M00/M12/M11 协作 | P0 |
| Performance | Prefill/Decode latency | P1 |

## Functional Coverage Points

### 1. Attention Computation Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_mha_heads` | 8 Head 索引遍历 (0-7) | 100% |
| `cp_mha_positions` | Position 遍历 (0-511) | 100% |
| `cp_mha_layers` | Layer 遍历 (0-4) | 100% |
| `cp_score_compute` | QK Score 计算 (dot product) | 100% |
| `cp_av_compute` | Attention × V 计算 | 100% |
| `cp_scale_factor` | 1/sqrt(head_size) 应用 | 100% |

### 2. Causal Masking Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_mask_pos0` | Position 0 (仅自身可见) | 100% |
| `cp_mask_pos128` | Position 128 (0-127 可见) | 100% |
| `cp_mask_pos511` | Position 511 (全部可见) | 100% |
| `cp_mask_all_pos` | 所有位置掩码模式 | 100% |
| `cp_mask_value_fp32` | FP32 mask = -1e20 | 100% |
| `cp_mask_value_fp16` | FP16 mask = -65504 | 100% |
| `cp_mask_value_fp8` | FP8 mask = -240 | 100% |

### 3. KV Cache Interface Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_kv_read` | KV Cache 读取 | 100% |
| `cp_kv_write` | KV Cache 写入 | 100% |
| `cp_kv_prefill` | Prefill phase KV update | 100% |
| `cp_kv_decode` | Decode phase KV access | 100% |
| `cp_kv_boundary` | KV Cache 边界 (pos=0, 511) | 100% |
| `cp_kv_layer_all` | 5 Layer KV 遍历 | 100% |

### 4. MQA Optimization Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_mqa_kv_head0` | KV Head 0 (shared by Q Head 0,1) | 100% |
| `cp_mqa_kv_head1` | KV Head 1 (shared by Q Head 2,3) | 100% |
| `cp_mqa_kv_head2` | KV Head 2 (shared by Q Head 4,5) | 100% |
| `cp_mqa_kv_head3` | KV Head 3 (shared by Q Head 6,7) | 100% |
| `cp_mqa_head_mapping` | 所有 Q-KV Head 组合 | 100% |

### 5. Precision Mode Coverage

| Cover Point | Description | Target |
|-------------|-------------|--------|
| `cp_precision_fp32` | FP32 全精度模式 | 100% |
| `cp_precision_fp16` | FP16 精度模式 | 100% |
| `cp_precision_fp8_kv` | FP8 KV Cache 模式 | 100% |
| `cp_precision_int8` | INT8 输入量化模式 | 100% |
| `cp_precision_conv` | 精度转换路径 | 100% |

## Assertion List

### 1. Interface Assertions

```verilog
// A1: Score input valid implies ready within timeout
assert property (@(posedge clk) score_valid |-> ##[1:16] score_ready);

// A2: KV Cache address within valid range
assert property (@(posedge clk) kv_valid |-> (kv_addr >= KV_KEY_BASE && kv_addr <= KV_VAL_END));

// A3: M00 Systolic Array handshake
assert property (@(posedge clk) sa_cmd_valid & sa_cmd_ready |-> ##1 sa_op_valid);

// A4: SoftMax handshake
assert property (@(posedge clk) sm_valid |-> ##[1:512] sm_result_valid);

// A5: RoPE handshake (when enabled)
assert property (@(posedge clk) rope_en & rope_start |-> ##[1:8] rope_valid);
```

### 2. Computation Assertions

```verilog
// A6: Score vector length matches position
assert property (@(posedge clk) score_valid |-> score_len == (current_pos + 1));

// A7: Attention weights sum to ~1.0 after SoftMax
assert property (@(posedge clk) sm_result_valid |-> (sm_result_sum >= 0.99 && sm_result_sum <= 1.01));

// A8: Causal mask applied before SoftMax
assert property (@(posedge clk) softmax_start |-> causal_mask_done);

// A9: KV Cache write after each position
assert property (@(posedge clk) attn_done |-> kv_update_done);

// A10: Output vector dimension matches head_size × n_heads
assert property (@(posedge clk) out_valid |-> out_data_width == 64);
```

### 3. MQA Assertions

```verilog
// A11: MQA KV head shared correctly
assert property (@(posedge clk) mqa_mode |-> (n_kv_heads == 4 && kv_mul == 2));

// A12: KV head mapping for each query head
assert property (@(posedge clk) q_head_idx % 2 == kv_head_idx);

// A13: KV cache size reduced 50% with MQA
assert property (@(posedge clk) mqa_mode |-> kv_cache_size == 160KB);
```

### 4. FSM Assertions

```verilog
// A14: FSM starts from IDLE
assert property (@(posedge clk) rst_n |-> ##1 fsm_state == IDLE);

// A15: Score compute before AV compute
assert property (@(posedge clk) fsm_state == AV_COMPUTE |-> $past(fsm_state) == SOFTMAX_WAIT);

// A16: Done signal after complete pipeline
assert property (@(posedge clk) attn_done |-> fsm_state == DONE);

// A17: No deadlock in FSM
assert property (@(posedge clk) fsm_state != ERROR |-> ##[1:1000] fsm_state != ERROR);
```

## Test Scenarios

### 1. Multi-Head Attention Test (T-MHA-01)

**Purpose**: 验证 8 Head Multi-Head Attention 计算正确性

**Golden Reference**: PyTorch reference implementation

```python
import torch
import torch.nn.functional as F

def reference_attention(Q, K, V, n_heads=8, head_size=8):
    # Q: [seq_len, n_heads, head_size]
    # K, V: [seq_len, n_kv_heads, head_size]
    scores = torch.matmul(Q, K.transpose(-2, -1)) / math.sqrt(head_size)
    weights = F.softmax(scores, dim=-1)
    output = torch.matmul(weights, V)
    return output
```

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| seq_len | 1, 16, 64, 256, 512 |
| n_heads | 8 |
| n_kv_heads | 4 |
| head_size | 8 |
| precision | FP16, FP32 |

**Expected Result**: Hardware output matches golden reference within tolerance:
- FP32: tolerance = 1e-6
- FP16: tolerance = 1e-3

### 2. Causal Masking Test (T-CMASK-02)

**Purpose**: 验证自回归因果掩码正确性

**Golden Reference**: Causal mask matrix generation

```python
def causal_mask(seq_len, position):
    mask = torch.zeros(seq_len)
    mask[position+1:] = float('-inf')
    return mask
```

**Test Parameters**:

| Position | Valid Positions | Masked Positions |
|----------|-----------------|------------------|
| 0 | [0] | [1-511] |
| 128 | [0-128] | [129-511] |
| 255 | [0-255] | [256-511] |
| 511 | [0-511] | none |

**Expected Result**: Masked positions result in attention weight = 0 after SoftMax

### 3. KV Cache Interface Test (T-KVC-03)

**Purpose**: 验证 KV Cache 存取正确性

**Test Flow**:
1. Prefill phase: Write K/V for positions 0-255
2. Verify KV Cache content matches written data
3. Decode phase: Read K/V for positions 0-255, write position 256
4. Verify new K/V correctly appended

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| cache_size | 160 KB (MQA) / 320 KB (standard) |
| precision | FP16, FP8 |
| layer | 0-4 |

**Expected Result**: KV Cache read returns correct historical data

### 4. MQA Optimization Test (T-MQA-04)

**Purpose**: 验证 Multi-Query Attention KV 共享机制

**Test Flow**:
1. Compute Q for all 8 heads
2. Compute K/V for 4 KV heads
3. Verify KV head sharing: Head 0,1 share KV0; Head 2,3 share KV1; etc.
4. Compare MQA output with standard attention output

**Expected Result**: MQA output matches standard attention within tolerance (max 0.5% deviation)

### 5. Prefill Pipeline Test (T-PREFILL-05)

**Purpose**: 验证 Prefill phase 完整流程

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| prompt_len | 16, 64, 256 |
| layer | 0-4 |
| precision | FP16 |

**Expected Result**: 
- All prompt tokens correctly processed
- KV Cache populated for all prompt positions
- Attention output matches golden reference

### 6. Decode Pipeline Test (T-DECODE-06)

**Purpose**: 验证 Decode phase 单 token 推理

**Test Parameters**:

| Parameter | Value |
|-----------|-------|
| current_pos | 256, 400, 511 |
| precision | FP16 |

**Expected Result**:
- Historical KV correctly retrieved
- New KV correctly appended
- Single token attention output matches golden

### 7. RoPE Integration Test (T-ROPE-07)

**Purpose**: 验证与 M11 RoPE Unit 协作

**Test Flow**:
1. Enable RoPE (rope_en = 1)
2. Send Q/K to M11 for rotation
3. Verify rotated Q/K used in score computation
4. Compare with non-RoPE baseline

**Expected Result**: RoPE output matches reference implementation

### 8. Precision Mode Test (T-PREC-08)

**Purpose**: 验证 FP8/FP16/INT8 混合精度

**Test Matrix**:

| Mode | Q/K/V | KV Cache | Score | Output |
|------|-------|----------|-------|--------|
| FP32 | FP32 | FP32 | FP32 | FP32 |
| FP16 | FP16 | FP16 | FP16 | FP16 |
| FP8 KV | FP16 | FP8 | FP16 | FP16 |
| INT8 | INT8 | FP16 | INT32 | FP16 |

**Expected Result**: Each precision mode output matches reference within mode-specific tolerance

### 9. Backpressure Test (T-BP-09)

**Purpose**: 验证输出阻塞时的 Pipeline 行为

**Test Flow**:
1. Set out_ready = 0 (block output)
2. Verify pipeline stalls without data loss
3. Release backpressure
4. Verify pipeline resumes correctly

**Expected Result**: No data loss, pipeline resumes after backpressure release

### 10. Error Handling Test (T-ERR-10)

**Purpose**: 验证错误检测和恢复

**Test Cases**:

| Error Type | Trigger | Expected Response |
|------------|---------|-------------------|
| SRAM timeout | KV access timeout | error flag, FSM to ERROR |
| SoftMax overflow | exp overflow | saturate output, error flag |
| Invalid position | pos > seq_len | error flag, abort |

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
tb_attention_unit/
  ├── tb_top.sv           # Top-level testbench
  ├── dut_wrapper.sv      # DUT wrapper with interfaces
  ├── interfaces/
  │   ├── sram_if.sv      # M02 SRAM interface
  │   ├── systolic_if.sv  # M00 Systolic Array interface
  │   ├── softmax_if.sv   # M12 SoftMax interface
  │   └── rope_if.sv      # M11 RoPE interface
  ├── drivers/
  │   ├── sram_driver.py  # SRAM access driver
  │   ├── score_driver.py # Score input driver
  │   └── kv_driver.py    # KV Cache driver
  ├── monitors/
  │   ├── output_monitor.py # Output capture
  │   ├── coverage_monitor.py # Coverage collection
  ├── checkers/
  │   ├── score_checker.py  # Score validation
  │   ├── weight_checker.py # Weight sum validation
  │   ├── output_checker.py # Output vs golden
  ├── tests/
  │   ├── test_mha.py
  │   ├── test_causal_mask.py
  │   ├── test_kv_cache.py
  │   ├── test_mqa.py
  │   ├── test_pipeline.py
  ├── golden/
  │   ├── reference_attention.py # PyTorch golden
  │   ├── reference_rope.py      # RoPE golden
```

## Schedule

| Phase | Duration | Tasks |
|-------|----------|-------|
| TB Setup | Day 1-2 | Infrastructure, interfaces |
| Basic Tests | Day 3-5 | T-MHA-01, T-CMASK-02, T-KVC-03 |
| Pipeline Tests | Day 6-8 | T-PREFILL-05, T-DECODE-06 |
| Integration Tests | Day 9-11 | T-ROPE-07, T-MQA-04 |
| Precision Tests | Day 12-13 | T-PREC-08 |
| Stress Tests | Day 14-15 | T-BP-09, T-ERR-10 |
| Coverage Closure | Day 16-18 | Coverage analysis, fill holes |
| Regression | Day 19-20 | Full regression |

**Total**: 20 days