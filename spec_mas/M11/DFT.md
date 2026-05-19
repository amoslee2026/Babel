---
module: M11_RMSNormRoPE
type: DFT
status: complete
parent: M11
module_type: compute
generated: "2026-05-17T16:30:00+08:00"
---

# M11 RMSNorm/RoPE Unit — DFT Spec

## Overview

M11 RMSNorm/RoPE Unit 实现 RMSNorm 归一化、RoPE Position Encoding、Combined Flow (RMSNorm+RoPE)。DFT 设计涵盖 Scan Chain、LUT Test (Sigmoid/Cos/Sin)、Pipeline Test，目标是实现 95% 以上的故障覆盖率。

| 属性 | 值 |
|------|-----|
| 模块类型 | Compute (Normalization/Encoding) |
| Pipeline 阶数 | 5-Stage (Fetch → Compute_Norm → Compute_RoPE → Write → Done) |
| 关键接口 | M02 SRAM, M09 Attention Unit |
| DFT 目标覆盖率 | ≥ 95% |

## Scan Chain Configuration

### Scan Chain Architecture

| 参数 | 值 | 说明 |
|------|----|------|
| 扫描链数量 | 5 | 按 Pipeline Stage 划分 |
| 每链长度 | ~256 bits | 每个 Stage 的 FF 数 |
| 总扫描 FF 数 | ~1280 | 估算值，综合后确认 |
| 扫描模式 | MUXED_SCAN | 标准 MUX 扫描 |
| 扫描时钟 | scan_clk | 独立扫描时钟 |

**按 Pipeline Stage 划分的扫描链**：

```
scan_in[0] → FETCH Stage FF → scan_out[0]
scan_in[1] → COMPUTE_NORM FF → scan_out[1]
scan_in[2] → COMPUTE_ROPE FF → scan_out[2]
scan_in[3] → WRITE Stage FF → scan_out[3]
scan_in[4] → CONTROL_REG FF → scan_out[4]
```

### Scan Chain Details

| Chain ID | Stage | FF Count | Description |
|----------|-------|----------|-------------|
| 0 | FETCH | 128 | SRAM 请求/响应寄存器 |
| 1 | COMPUTE_NORM | 256 | RMSNorm 计算逻辑 |
| 2 | COMPUTE_ROPE | 256 | RoPE 计算逻辑 |
| 3 | WRITE | 128 | SRAM 写入寄存器 |
| 4 | CONTROL | 256 | FSM, Mode Register, Precision Reg |

### Scan Signals

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| scan_en | input | 1 | 扫描使能 |
| scan_in[4:0] | input | 5 | 扫描输入（5 条链） |
| scan_out[4:0] | output | 5 | 扫描输出（5 条链） |
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
| BIST 控制寄存器 | NR_BIST_CTRL (偏移 0x40) |
| BIST 状态寄存器 | NR_BIST_STATUS (偏移 0x44) |

**NR_BIST_CTRL 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_en | 使能 LBIST |
| [1] | bist_start | 启动 BIST（自清零） |
| [9:2] | bist_pattern_cnt | 测试 pattern 数（默认 256） |
| [10] | lut_test_en | LUT 测试使能 |
| [11] | pipeline_test_en | Pipeline 测试使能 |

**NR_BIST_STATUS 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_done | BIST 完成 |
| [1] | bist_pass | 1=通过，0=失败 |
| [5:2] | fail_chain_id | 首个失败扫描链编号 |
| [10:6] | lut_test_result | LUT 测试结果 |
| [15:11] | pipeline_test_result | Pipeline 测试结果 |

### LUT Test Design

针对 RoPE cos/sin 表和 RMSNorm 计算的 LUT 测试：

**RoPE cos/sin 表测试**：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| 表地址测试 | 4096 entries 地址遍历 | 100% |
| cos 值精度 | cos(theta) 精度验证 | 100% |
| sin 值精度 | sin(theta) 精度验证 | 100% |
| theta 范围 | position[0-511] × freq 覆盖 | 100% |
| 频率计算 | freq = 1/(base^(head_dim/head_size)) | 100% |

**LUT Test Pattern**：

```
// 测试 RoPE 预计算表
for (pos = 0; pos < 512; pos++) {
    for (head_dim = 0; head_dim < 8; head_dim++) {
        addr = pos * 8 + head_dim;
        cos_val = cos_table[addr];
        sin_val = sin_table[addr];
        freq = 1.0 / pow(10000, head_dim / 8);
        theta = pos * freq;
        expected_cos = cos(theta);
        expected_sin = sin(theta);
        assert |cos_val - expected_cos| < tolerance;
        assert |sin_val - expected_sin| < tolerance;
    }
}
```

**RoPE Frequency Test Cases**：

| head_dim | Expected freq | Tolerance |
|----------|---------------|-----------|
| 0 | 1.0000 | < 1e-4 |
| 1 | 0.3162 | < 1e-4 |
| 2 | 0.1000 | < 1e-4 |
| 3 | 0.0316 | < 1e-4 |
| 4 | 0.0100 | < 1e-4 |
| 5 | 0.0032 | < 1e-4 |
| 6 | 0.0010 | < 1e-4 |
| 7 | 0.0003 | < 1e-4 |

**RMSNorm 计算测试**：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| SS 计算 | 平方和累加正确性 | 100% |
| RMS 因子 | 1/sqrt(ss/dim + eps) 精度 | 100% |
| epsilon 处理 | eps = 1e-5 加法验证 | 100% |
| 输入范围 | [-10, 10] 覆盖 | 100% |
| 权重向量 | 64 entries 权重遍历 | 100% |

**RMSNorm Test Cases**：

| Input Condition | Expected Behavior |
|-----------------|-------------------|
| All zeros | epsilon prevents division by zero |
| Large values (10+) | Normalization to reasonable range |
| Negative values | Square eliminates sign correctly |
| Single element | Mean still computed correctly |

### Pipeline Test Design

针对 RMSNorm → RoPE 组合流水线的测试：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| FSM 状态转换 | 所有状态遍历 | 100% |
| Combined 流水 | RMSNorm → RoPE 连续执行 | 100% |
| SRAM 访问优化 | 4 vs 6 accesses 验证 | 100% |
| Latency 验证 | ~15 cycles 组合延迟 | 100% |
| Backpressure | 输出阻塞处理 | 100% |

**Pipeline Test Flow**：

```
1. 设置 op_type = COMBINED
2. 触发 op_start
3. 验证 FSM 转换序列：IDLE → FETCH → COMPUTE_NORM → COMPUTE_ROPE → WRITE → DONE
4. 测量 cycle_count ≤ 20
5. 验证 SRAM access count = 4
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
| LUT_TEST | 4'h6 | LUT (cos/sin) 测试 |
| PIPELINE_TEST | 4'h7 | Pipeline 测试 |

### IDCODE Register

| 位 | 值 | 描述 |
|----|-----|------|
| [31:28] | 4'h1 | 版本号 |
| [27:12] | 16'h000B | 部件号 (M11) |
| [11:1] | 11'h0A1 | 制造商 ID |
| [0] | 1'b1 | 固定为 1 |

## Test Mode Definition

### DFT Mode Summary

| 模式 | scan_en | bist_en | lut_test_en | pipeline_en | 功能 |
|------|---------|----------|-------------|-------------|------|
| 功能模式 | 0 | 0 | 0 | 0 | 正常 RMSNorm/RoPE 计算 |
| 扫描模式 | 1 | 0 | 0 | 0 | 扫描链移位/捕获 |
| LBIST 模式 | 0 | 1 | 0 | 0 | Logic BIST 测试 |
| LUT 测试模式 | 0 | 1 | 1 | 0 | cos/sin 表测试 |
| Pipeline 测试模式 | 0 | 1 | 0 | 1 | Pipeline 流程测试 |

### Mode Switching Requirements

- 模式切换必须在 FSM IDLE 状态进行
- LUT 测试需要表数据加载
- Pipeline 测试需要 M02 SRAM 配合

## Coverage Target

| 测试类型 | 目标覆盖率 | Weight |
|----------|-----------|--------|
| Scan Chain (Stuck-at) | ≥ 95% | 30% |
| LBIST Fault Coverage | ≥ 95% | 25% |
| LUT Test (cos/sin) | 100% | 25% |
| Pipeline Test | 100% | 10% |
| JTAG Functional | 100% | 10% |

**Total Target**: ≥ 95%

## ATPG Constraints

```tcl
# 扫描链配置
set_scan_chain_count 5
set_scan_chain_length 256

# Pipeline 结构约束
set_dft_signal -type ScanClock -port scan_clk -timing {45 55}

# 隔离功能时钟
set_dft_signal -type MasterClock -port clk -off_state 0

# RoPE 表地址约束
set_atpg_constraints -lut_address_range 0 4095

# Position 范围约束
set_atpg_constraints -position_range 0 511

# 目标故障覆盖率
set_fault_coverage_target 95

# Transition fault coverage
set_atpg_mode -transition_fault -target 90
```

## Implementation Notes

1. **RoPE 表**: 4096 entries (16 KB) cos/sin 表需要完整覆盖测试
2. **Combined 优化**: Pipeline 测试验证 SRAM 访问从 6 减少到 4
3. **精度处理**: FP16/FP32 模式切换需要独立测试
4. **实时 vs 表查**: 需验证实时计算和表查两种模式的精度一致性