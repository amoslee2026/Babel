---
module: M09_AttentionUnit
type: DFT
status: complete
parent: M09
module_type: compute
generated: "2026-05-17T16:30:00+08:00"
---

# M09 Attention Unit — DFT Spec

## Overview

M09 Attention Unit 实现 Multi-Head Attention、Causal Masking、KV Cache Interface、MQA Optimization。DFT 设计涵盖 Scan Chain、Logic BIST、KV Cache Interface Test，目标是实现 95% 以上的故障覆盖率。

| 属性 | 值 |
|------|-----|
| 模块类型 | Compute (Attention) |
| Pipeline 阶数 | 5-Stage (QKV Load → RoPE → Score → SoftMax → AV) |
| 关键接口 | M00 Systolic Array, M02 SRAM, M12 SoftMax, M11 RoPE |
| DFT 目标覆盖率 | ≥ 95% |

## Scan Chain Configuration

### Scan Chain Architecture

| 参数 | 值 | 说明 |
|------|----|------|
| 扫描链数量 | 8 | 按 Pipeline Stage 划分 |
| 每链长度 | ~512 bits | 每个 Stage 的 FF 数 |
| 总扫描 FF 数 | ~4096 | 估算值，综合后确认 |
| 扫描模式 | MUXED_SCAN | 标准 MUX 扫描 |
| 扫描时钟 | scan_clk | 独立扫描时钟 |

**按 Pipeline Stage 划分的扫描链**：

```
scan_in[0] → QKV_LOAD Stage FF → scan_out[0]
scan_in[1] → ROPE Interface FF → scan_out[1]
scan_in[2] → SCORE_COMPUTE FF → scan_out[2]
scan_in[3] → CAUSAL_MASK FF → scan_out[3]
scan_in[4] → SOFTMAX_IF FF → scan_out[4]
scan_in[5] → AV_COMPUTE FF → scan_out[5]
scan_in[6] → KV_CACHE_ADDR FF → scan_out[6]
scan_in[7] → CONTROL_REG FF → scan_out[7]
```

### Scan Chain Details

| Chain ID | Stage | FF Count | Description |
|----------|-------|----------|-------------|
| 0 | QKV_LOAD | 128 | Q/K/V Buffer, Position/Layer Reg |
| 1 | ROPE_IF | 64 | RoPE handshake signals |
| 2 | SCORE_COMPUTE | 256 | Score Accumulator, Scale Factor |
| 3 | CAUSAL_MASK | 32 | Position Counter, Mask Logic |
| 4 | SOFTMAX_IF | 128 | Score Vector Buffer, Head Index |
| 5 | AV_COMPUTE | 256 | Weight Buffer, Output Buffer |
| 6 | KV_ADDR_GEN | 128 | KV Cache Address Generator |
| 7 | CONTROL | 128 | FSM, Control Registers |

### Scan Signals

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| scan_en | input | 1 | 扫描使能 |
| scan_in[7:0] | input | 8 | 扫描输入（8 条链） |
| scan_out[7:0] | output | 8 | 扫描输出（8 条链） |
| scan_clk | input | 1 | 扫描时钟 |
| scan_rst_n | input | 1 | 扫描复位 |

## BIST Design

### Logic BIST (LBIST)

| 属性 | 值 |
|------|-----|
| BIST 类型 | LBIST (Logic BIST) |
| PRPG | 32-bit LFSR，多项式 x^32+x^22+x^2+x+1 |
| MISR | 32-bit MISR，每条扫描链独立 |
| 测试模式数 | 512 patterns |
| 预期故障覆盖率 | ≥ 95% (stuck-at) |
| BIST 控制寄存器 | ATTN_BIST_CTRL (偏移 0x20) |
| BIST 状态寄存器 | ATTN_BIST_STATUS (偏移 0x24) |

**ATTN_BIST_CTRL 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_en | 使能 LBIST |
| [1] | bist_start | 启动 BIST（自清零） |
| [10:2] | bist_pattern_cnt | 测试 pattern 数（默认 512） |
| [11] | kv_test_en | KV Cache Interface 测试使能 |

**ATTN_BIST_STATUS 字段**：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_done | BIST 完成 |
| [1] | bist_pass | 1=通过，0=失败 |
| [5:2] | fail_chain_id | 首个失败扫描链编号 |
| [15:6] | kv_test_result | KV Interface 测试结果 |

### KV Cache Interface BIST

针对 KV Cache 地址生成和数据接口的专用 BIST：

| 测试项 | 描述 | 预期覆盖率 |
|--------|------|-----------|
| 地址范围测试 | 验证所有 KV Cache 地址空间 | 100% |
| Layer 遍历测试 | 5 Layer 地址正确性 | 100% |
| Position 遍历测试 | 512 Position 地址正确性 | 100% |
| KV Head 遍历测试 | 4 KV Head 地址正确性 | 100% |
| 读/写接口测试 | handshake 协议验证 | 100% |

**KV Cache Interface Test 流程**：

```
1. 设置 base_addr = KV_KEY_BASE
2. 遍历 layer[0-4], pos[0-511], kv_head[0-3]
3. 验证生成的地址在有效范围
4. 执行 dummy read/write handshake
5. 检查响应正确性
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
| KV_IF_TEST | 4'h6 | KV Cache Interface 测试 |

### IDCODE Register

| 位 | 值 | 描述 |
|----|-----|------|
| [31:28] | 4'h1 | 版本号 |
| [27:12] | 16'h0009 | 部件号 (M09) |
| [11:1] | 11'h0A1 | 制造商 ID |
| [0] | 1'b1 | 固定为 1 |

## Test Mode Definition

### DFT Mode Summary

| 模式 | scan_en | bist_en | kv_test_en | 功能 |
|------|---------|----------|------------|------|
| 功能模式 | 0 | 0 | 0 | 正常 Attention 计算 |
| 扫描模式 | 1 | 0 | 0 | 扫描链移位/捕获 |
| LBIST 模式 | 0 | 1 | 0 | Logic BIST 测试 |
| KV IF 测试模式 | 0 | 1 | 1 | KV Cache Interface 测试 |

### Mode Switching Requirements

- 模式切换必须在 FSM IDLE 状态进行
- LBIST 完成后需要复位返回功能模式
- KV IF 测试需要 M02 SRAM 配合

## Coverage Target

| 测试类型 | 目标覆盖率 | Weight |
|----------|-----------|--------|
| Scan Chain (Stuck-at) | ≥ 95% | 40% |
| LBIST Fault Coverage | ≥ 95% | 30% |
| KV Interface Test | 100% | 20% |
| JTAG Functional | 100% | 10% |

**Total Target**: ≥ 95%

## ATPG Constraints

```tcl
# 扫描链配置
set_scan_chain_count 8
set_scan_chain_length 512

# Pipeline 结构约束
set_dft_signal -type ScanClock -port scan_clk -timing {45 55}

# 隔离功能时钟
set_dft_signal -type MasterClock -port clk -off_state 0

# KV Cache 地址约束
set_atpg_constraints -address_range KV_KEY_BASE KV_VAL_END

# 目标故障覆盖率
set_fault_coverage_target 95

# Transition fault coverage
set_atpg_mode -transition_fault -target 90
```

## Implementation Notes

1. **MQA Optimization**: KV Cache 地址生成器支持 4 KV Head 共享模式，BIST 需覆盖所有共享映射
2. **Pipeline 深度**: 5-Stage Pipeline 要求扫描链按 Stage 划分，便于定位故障
3. **接口隔离**: 测试模式下 M00/M12/M11 接口需隔离，避免外部干扰
4. **KV Cache 压力**: 完整 KV 地址空间测试需要约 1024 次 address generation cycles