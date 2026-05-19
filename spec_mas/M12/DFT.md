---
module: M12_SoftMax
type: DFT
status: complete
parent: M12
module_type: compute
generated: "2026-05-17T16:30:00+08:00"
---

# M12 SoftMax Unit — DFT Spec

## Overview

M12 SoftMax Unit 实现 Numerical Stable SoftMax (Max Subtraction)、Exp Approximation (LUT/Taylor/Hybrid)、Probability Normalization。DFT 设计涵盖 Scan Chain、Exp LUT Test、Normalizer Test、Pipeline Test，目标是实现 95% 以上的故障覆盖率。

| 属性 | 值 |
|------|-----|
| 模块类型 | Compute (SoftMax) |
| Pipeline 阶数 | 4-Stage (Max Finder → Exp Approx → Sum Accum → Normalizer) |
| 关键接口 | M09 Attention Unit |
| DFT 目标覆盖率 | ≥ 95% |

## Scan Chain Configuration

### Scan Chain Architecture

| 参数 | 值 | 说明 |
|------|----|------|
| 扫描链数量 | 4 | 按 Pipeline Stage 划分 |
| 每链长度 | ~512 bits | 每个 Stage 的 FF 数 |
| 总扫描 FF 数 | ~2048 | 估算值，综合后确认 |
| 扫描模式 | MUXED_SCAN | 标准 MUX 扫描 |
| 扫描时钟 | scan_clk | 独立扫描时钟 |

**按 Pipeline Stage 划分的扫描链**：

```
scan_in[0] → STAGE1_MAX Finder FF → scan_out[0]
scan_in[1] → STAGE2_EXP Approx FF → scan_out[1]
scan_in[2] → STAGE3_SUM Accum FF → scan_out[2]
scan_in[3] → STAGE4_NORM FF + Control → scan_out[3]
```

### Scan Chain Details

| Chain ID | Stage | FF Count | Description |
|----------|-------|----------|-------------|
| 0 | STAGE1_MAX | 256 | Max Finder 比较/选择逻辑 |
| 1 | STAGE2_EXP | 512 | Exp Approximation (LUT + Taylor) |
| 2 | STAGE3_SUM | 256 | Sum Accumulator (FP32) |
| 3 | STAGE4_NORM | 256 | Normalizer + Control + FSM |

### Scan Signals

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| scan_en | input | 1 | 扫描使能 |
| scan_in[3:0] | input | 4 | 扫描输入（4 条链） |
| scan_out[3:0] | output | 4 | 扫描输出（4 条链） |
| scan_clk | input | 1 | 扫描时钟 |
| scan_rst_n | input | 1 | 扫描复位 |

## BIST Design

### Logic BIST (LBIST)

| 属性 | 值 |
|------|-----|
| BIST 类型 | LBIST (Logic BIST) |
| PRPG | 32-bit LFSR，多项式 x^32+x^22+x^2+x+1 |
| MISR | 32-bit MISR，每条扫描链独立 |
| 测试模式数 | 256 patterns |
| 预期故障覆盖率 | ≥ 95% (stuck-at) |
| BIST 控制寄存器 | SM_BIST_CTRL (偏移 0x50) |
| BIST 状态寄存器 | SM_BIST_STATUS (偏移 0x54) |

**SM_BIST_CTRL 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_en | 使能 LBIST |
| [1] | bist_start | 启动 BIST（自清零） |
| [9:2] | bist_pattern_cnt | 测试 pattern 数（默认 256） |
| [10] | lut_test_en | Exp LUT 测试使能 |
| [11] | norm_test_en | Normalizer 测试使能 |
| [12] | pipeline_test_en | Pipeline 测试使能 |

**SM_BIST_STATUS 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_done | BIST 完成 |
| [1] | bist_pass | 1=通过，0=失败 |
| [5:2] | fail_chain_id | 首个失败扫描链编号 |
| [10:6] | lut_test_result | Exp LUT 测试结果 |
| [15:11] | norm_test_result | Normalizer 测试结果 |
| [20:16] | pipeline_test_result | Pipeline 测试结果 |

### Exp LUT Test Design

针对 Exponential LUT (128 entries) 的测试：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| LUT 地址测试 | 128 entries 地址遍历 | 100% |
| Exp 值精度 | exp(x) 精度验证 (x ∈ [-8, 0]) | 100% |
| Taylor 2阶 | 2阶展开精度 | 100% |
| Taylor 3阶 | 3阶展开精度 | 100% |
| Taylor 4阶 | 4阶展开精度 | 100% |
| Hybrid 模式 | LUT + Taylor 混合 | 100% |
| 输入范围 | [-8, 0] 完整覆盖 | 100% |

**Exp LUT Test Pattern**：

```
// 测试 Exp LUT 128 entries
for (addr = 0; addr < 128; addr++) {
    lut_input = -8.0 + addr * step;  // 输入映射 [-8, 0]
    lut_output = exp_lut[addr];
    expected = reference_exp(lut_input);
    assert |lut_output - expected| < tolerance;
}

// 测试 Taylor 近似
for (x = -8; x <= 0; x += 0.1) {
    taylor_o2 = 1 + x + x^2/2;
    taylor_o3 = 1 + x + x^2/2 + x^3/6;
    taylor_o4 = 1 + x + x^2/2 + x^3/6 + x^4/24;
    // 验证精度在各自范围内
}
```

**Exp Accuracy Test Cases**：

| Method | Input Range | Expected Accuracy |
|--------|-------------|-------------------|
| LUT | [-8, 0] | < 0.05% error |
| Taylor-2 | [-2, 0] | < 0.5% error |
| Taylor-3 | [-4, 0] | < 0.1% error |
| Taylor-4 | [-8, 0] | < 0.05% error |
| Hybrid | [-8, 0] | < 0.02% error |

### Normalizer Test Design

针对 Newton-Raphson 除法归一化的测试：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| 初始估计 | 1/sum 初始值计算 | 100% |
| Newton-Raphson 迭代 | 2-3 次迭代精度 | 100% |
| 除法精度 | exp/sum 结果验证 | 100% |
| Sum 范围 | [1.0, 256.0] 覆盖 | 100% |
| Sum=0 错误 | 边界条件处理 | 100% |
| 输出概率范围 | [0, 1] 验证 | 100% |

**Normalizer Test Cases**：

| Iterations | Expected Accuracy |
|------------|-------------------|
| 1 iteration | ~5% error (fast) |
| 2 iterations | ~1% error |
| 3 iterations | ~0.1% error (accurate) |

**Newton-Raphson Test Flow**：

```
1. 给定 sum_val ∈ [1.0, 256.0]
2. 计算初始估计 inv_sum_est = 1.0 / sum_val
3. 执行 Newton-Raphson 迭代:
   inv_est_new = inv_est * (2 - sum_val * inv_est)
4. 验证最终精度 < tolerance
5. 验证 prob = exp * inv_sum ∈ [0, 1]
```

### Pipeline Test Design

针对 4-Stage SoftMax Pipeline 的测试：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| FSM 状态转换 | 4 Stage 状态遍历 | 100% |
| Max Finder | 256 elements 最大值查找 | 100% |
| Exp Approx | LUT/Taylor 模式切换 | 100% |
| Sum Accumulator | FP32 累加正确性 | 100% |
| Normalizer | Newton-Raphson 除法 | 100% |
| Total Latency | ≤ 21 cycles 验证 | 100% |
| Backpressure | Stage 4 stall 处理 | 100% |

**Pipeline Test Flow**：

```
1. 设置 input vector (256 elements)
2. 触发 softmax_start
3. 验证 FSM 转换：IDLE → STAGE1_MAX → STAGE2_EXP → STAGE3_SUM → STAGE4_NORM → COMPLETE
4. 测量 cycle_count ≤ 21
5. 验证 checksum = sum(prob) ≈ 1.0
```

**Numerical Stability Test Cases**：

| Input Pattern | Expected Behavior |
|---------------|-------------------|
| [1000, 1000, 1000] | All probabilities = 1/3 |
| [0, 1000, 2000] | Prob[0] ≈ 0, Prob[1] ≈ 0, Prob[2] ≈ 1 |
| [-1000, -1000, -1000] | All probabilities = 1/3 |
| [1e10, 1e10, 1e10] | No overflow, all equal |

## Test Access Mechanism

### JTAG Interface

| 信号 | 方向 | 描述 |
|------|------|------|
| tck | input | JTAG 时钟（最大 50 MHz） |
| tms | input | 测试模式选择 |
| tdi | input | 测试数据输入 |
| tdo | output | 测试数据输出 |
| trst_n | input | JTAG 复位（低有效） |

**支持的 JTAG 指令**：

| 指令 | 编码 | 功能 |
|------|------|------|
| BYPASS | 4'hF | 旁路 |
| IDCODE | 4'h1 | 读取器件 ID |
| SAMPLE | 4'h2 | 边界扫描采样 |
| EXTEST | 4'h3 | 外部测试 |
| INTEST | 4'h4 | 内部扫描链访问 |
| BIST_RUN | 4'h5 | 触发 LBIST |
| EXP_LUT_TEST | 4'h6 | Exp LUT 测试 |
| NORM_TEST | 4'h7 | Normalizer 测试 |
| PIPELINE_TEST | 4'h8 | Pipeline 测试 |

### IDCODE Register

| 位 | 值 | 描述 |
|----|-----|------|
| [31:28] | 4'h1 | 版本号 |
| [27:12] | 16'h000C | 部件号 (M12) |
| [11:1] | 11'h0A1 | 制造商 ID |
| [0] | 1'b1 | 固定为 1 |

## Test Mode Definition

### DFT Mode Summary

| 模式 | scan_en | bist_en | lut_en | norm_en | pipeline_en | 功能 |
|------|---------|----------|--------|---------|-------------|------|
| 功能模式 | 0 | 0 | 0 | 0 | 0 | 正常 SoftMax 计算 |
| 扫描模式 | 1 | 0 | 0 | 0 | 0 | 扫描链移位/捕获 |
| LBIST 模式 | 0 | 1 | 0 | 0 | 0 | Logic BIST 测试 |
| Exp LUT 测试 | 0 | 1 | 1 | 0 | 0 | Exp LUT 测试 |
| Normalizer 测试 | 0 | 1 | 0 | 1 | 0 | Normalizer 测试 |
| Pipeline 测试 | 0 | 1 | 0 | 0 | 1 | Pipeline 测试 |

### Mode Switching Requirements

- 模式切换必须在 FSM IDLE 状态进行
- Exp LUT 测试需要表数据加载
- Normalizer 测试需要不同 sum 值输入

## Coverage Target

| 测试类型 | 目标覆盖率 | Weight |
|----------|-----------|--------|
| Scan Chain (Stuck-at) | ≥ 95% | 25% |
| LBIST Fault Coverage | ≥ 95% | 25% |
| Exp LUT Test | 100% | 20% |
| Normalizer Test | 100% | 15% |
| Pipeline Test | 100% | 10% |
| JTAG Functional | 100% | 5% |

**Total Target**: ≥ 95%

## ATPG Constraints

```tcl
# 扫描链配置
set_scan_chain_count 4
set_scan_chain_length 512

# Pipeline 结构约束
set_dft_signal -type ScanClock -port scan_clk -timing {45 55}

# 隔离功能时钟
set_dft_signal -type MasterClock -port clk -off_state 0

# Exp LUT 地址约束
set_atpg_constraints -lut_address_range 0 127

# Sum 范围约束
set_atpg_constraints -sum_range 1.0 256.0

# 目标故障覆盖率
set_fault_coverage_target 95

# Transition fault coverage
set_atpg_mode -transition_fault -target 90
```

## Implementation Notes

1. **Numerical Stability**: Max Subtraction 保证 exp 输入 ≤ 0，防止溢出
2. **Exp LUT**: 128 entries LUT 需要 Hybrid 模式支持完整 [-8, 0] 范围
3. **FP32 Accumulator**: FP16 输入用 FP32 累加防止精度丢失
4. **Causal Mask Support**: 与 M09 Causal Masking 协作，masked positions prob = 0
5. **Newton-Raphson**: 2-3 次迭代实现高精度除法，比直接除法更快