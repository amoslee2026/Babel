---
module: M10_FFNMatMul
type: DFT
status: complete
parent: M10
module_type: compute
generated: "2026-05-17T16:30:00+08:00"
---

# M10 FFN/MatMul Unit — DFT Spec

## Overview

M10 FFN/MatMul Unit 实现 FFN Pipeline (SwiGLU)、MatMul Dispatch、Activation Functions (GELU/SiLU/ReLU)。DFT 设计涵盖 Scan Chain、MatMul Interface Test、Activation Unit BIST，目标是实现 95% 以上的故障覆盖率。

| 属性 | 值 |
|------|-----|
| 模块类型 | Compute (FFN/MatMul) |
| Pipeline 阶数 | 4-Stage (MatMul w1/w3 → Activation → MatMul w2 → Output) |
| 关键接口 | M00 Systolic Array, M04 System Bus |
| DFT 目标覆盖率 | ≥ 95% |

## Scan Chain Configuration

### Scan Chain Architecture

| 参数 | 值 | 说明 |
|------|----|------|
| 扫描链数量 | 6 | 按 Pipeline Stage 划分 |
| 每链长度 | ~256 bits | 每个 Stage 的 FF 数 |
| 总扫描 FF 数 | ~1536 | 估算值，综合后确认 |
| 扫描模式 | MUXED_SCAN | 标准 MUX 扫描 |
| 扫描时钟 | scan_clk | 独立扫描时钟 |

**按 Pipeline Stage 划分的扫描链**：

```
scan_in[0] → MATMUL_W1W3 FF → scan_out[0]
scan_in[1] → ACTIVATION FF → scan_out[1]
scan_in[2] → MATMUL_W2 FF → scan_out[2]
scan_in[3] → OUTPUT_STAGE FF → scan_out[3]
scan_in[4] → M00_INTERFACE FF → scan_out[4]
scan_in[5] → CONTROL_REG FF → scan_out[5]
```

### Scan Chain Details

| Chain ID | Stage | FF Count | Description |
|----------|-------|----------|-------------|
| 0 | MATMUL_W1W3 | 256 | w1/w3 MatMul 控制寄存器 |
| 1 | ACTIVATION | 128 | SiLU/GELU/ReLU 逻辑 |
| 2 | MATMUL_W2 | 128 | w2 MatMul 控制寄存器 |
| 3 | OUTPUT | 64 | Output Buffer |
| 4 | M00_IF | 256 | Systolic Array Interface |
| 5 | CONTROL | 256 | FSM, Mode Register |

### Scan Signals

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| scan_en | input | 1 | 扫描使能 |
| scan_in[5:0] | input | 6 | 扫描输入（6 条链） |
| scan_out[5:0] | output | 6 | 扫描输出（6 条链） |
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
| BIST 控制寄存器 | FFN_BIST_CTRL (偏移 0x30) |
| BIST 状态寄存器 | FFN_BIST_STATUS (偏移 0x34) |

**FFN_BIST_CTRL 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_en | 使能 LBIST |
| [1] | bist_start | 启动 BIST（自清零） |
| [9:2] | bist_pattern_cnt | 测试 pattern 数（默认 256） |
| [10] | act_bist_en | Activation Unit BIST 使能 |
| [11] | mmul_if_test_en | MatMul Interface 测试使能 |

**FFN_BIST_STATUS 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_done | BIST 完成 |
| [1] | bist_pass | 1=通过，0=失败 |
| [5:2] | fail_chain_id | 首个失败扫描链编号 |
| [10:6] | act_bist_result | Activation BIST 结果 |
| [15:11] | mmul_if_result | MatMul Interface 测试结果 |

### Activation Unit BIST

针对 Sigmoid LUT 和 Activation 逻辑的专用 BIST：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| Sigmoid LUT 测试 | 256 entries 查表验证 | 100% |
| SiLU 计算测试 | x * sigmoid(x) 精度验证 | 100% |
| GELU 计算测试 | GELU approximation 验证 | 100% |
| ReLU 计算测试 | max(0, x) 逻辑验证 | 100% |
| 输入范围测试 | [-8, 8] 覆盖 | 100% |
| 饱和边界测试 | 输出饱和逻辑 | 100% |

**Sigmoid LUT Test Pattern**：

```
// 测试 LUT 地址范围 [0, 255]
for (addr = 0; addr < 256; addr++) {
    lut_input = (addr - 128) * step;  // 输入映射
    lut_output = sigmoid_lut[addr];
    expected = reference_sigmoid(lut_input);
    assert |lut_output - expected| < tolerance;
}
```

**Activation Test Cases**：

| Activation | Input | Expected Output | Tolerance |
|------------|-------|-----------------|-----------|
| SiLU | x = 0 | 0 | exact |
| SiLU | x = 1 | 0.7311 | < 0.1% |
| SiLU | x = -1 | -0.2689 | < 0.1% |
| GELU | x = 0 | 0 | exact |
| GELU | x = 1 | 0.8413 | < 0.5% |
| ReLU | x = -5 | 0 | exact |
| ReLU | x = 5 | 5 | exact |

### MatMul Interface Test

针对 M00 Systolic Array 接口的验证：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| CMD_MMUL (0x1) | 矩阵向量乘命令 | 100% |
| CMD_MLOAD (0x2) | 预加载权重命令 | 100% |
| CMD_MSET (0x3) | 设置维度命令 | 100% |
| Handshake 协议 | valid/ready 协议验证 | 100% |
| Dimension 测试 | dim=64, 256, 512 | 100% |

**MatMul Interface Test Flow**：

```
1. 发送 CMD_MSET (dim=64, hidden=256)
2. 验证 sa_cmd_valid & sa_cmd_ready handshake
3. 发送 CMD_MMUL (matrix A, vector x)
4. 等待 sa_result_valid
5. 比较结果与 golden reference
```

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
| ACT_BIST | 4'h6 | Activation Unit BIST |
| MMUL_IF_TEST | 4'h7 | MatMul Interface 测试 |

### IDCODE Register

| 位 | 值 | 描述 |
|----|-----|------|
| [31:28] | 4'h1 | 版本号 |
| [27:12] | 16'h000A | 部件号 (M10) |
| [11:1] | 11'h0A1 | 制造商 ID |
| [0] | 1'b1 | 固定为 1 |

## Test Mode Definition

### DFT Mode Summary

| 模式 | scan_en | bist_en | act_bist_en | mmul_if_en | 功能 |
|------|---------|----------|-------------|------------|------|
| 功能模式 | 0 | 0 | 0 | 0 | 正常 FFN/MatMul 计算 |
| 扫描模式 | 1 | 0 | 0 | 0 | 扫描链移位/捕获 |
| LBIST 模式 | 0 | 1 | 0 | 0 | Logic BIST 测试 |
| Activation BIST | 0 | 1 | 1 | 0 | Activation 逻辑测试 |
| MatMul IF 测试 | 0 | 1 | 0 | 1 | MatMul Interface 测试 |

### Mode Switching Requirements

- 模式切换必须在 FSM IDLE 状态进行
- Activation BIST 需要 LUT 数据加载
- MatMul IF 测试需要 M00 配合

## Coverage Target

| 测试类型 | 目标覆盖率 | Weight |
|----------|-----------|--------|
| Scan Chain (Stuck-at) | ≥ 95% | 30% |
| LBIST Fault Coverage | ≥ 95% | 30% |
| Activation BIST | 100% | 20% |
| MatMul Interface Test | 100% | 10% |
| JTAG Functional | 100% | 10% |

**Total Target**: ≥ 95%

## ATPG Constraints

```tcl
# 扫描链配置
set_scan_chain_count 6
set_scan_chain_length 256

# Pipeline 结构约束
set_dft_signal -type ScanClock -port scan_clk -timing {45 55}

# 隔离功能时钟
set_dft_signal -type MasterClock -port clk -off_state 0

# Activation LUT 约束
set_atpg_constraints -lut_address_range 0 255

# 目标故障覆盖率
set_fault_coverage_target 95

# Transition fault coverage
set_atpg_mode -transition_fault -target 90
```

## Implementation Notes

1. **Sigmoid LUT**: 256 entries LUT 需要完整覆盖测试，每个 entry 测试精度
2. **并行 Pipeline**: w1/w3 并行执行要求扫描链独立，避免 cross-talk
3. **Activation 精度**: FP16 精度下需要验证饱和边界处理
4. **M00 协作**: MatMul Interface 测试需要 M00 Systolic Array mock 或协作