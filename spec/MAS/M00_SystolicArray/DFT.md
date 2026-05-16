---
module: M00
type: DFT
status: complete
parent: MAS.md
generated: 2026-05-12T09:20:00Z
---

# M00_SystolicArray — DFT Spec

## 1. 扫描链配置

| 参数 | 值 | 说明 |
|------|----|------|
| 扫描链数量 | 32 | 每行 PE 对应 1 条链 |
| 每链长度 | ~1024 bits | 32 个 PE × ~32 FF/PE |
| 总扫描 FF 数 | ~32768 | 估算值，综合后确认 |
| 扫描模式 | MUXED_SCAN | 标准 MUX 扫描 |
| 扫描时钟 | scan_clk | 独立扫描时钟，与 CLK_SYS 隔离 |

扫描链划分原则：按 PE 行划分，每行 32 个 PE 串联为 1 条链，便于 ATPG 利用阵列规则结构生成高质量测试向量。

```
scan_in[0]  → PE[0,0] → PE[0,1] → ... → PE[0,31] → scan_out[0]
scan_in[1]  → PE[1,0] → PE[1,1] → ... → PE[1,31] → scan_out[1]
...
scan_in[31] → PE[31,0]→ PE[31,1]→ ... → PE[31,31]→ scan_out[31]
```

## 2. PE 阵列 BIST（LBIST）

| 属性 | 值 |
|------|----|
| BIST 类型 | LBIST（Logic BIST） |
| PRPG | 32-bit LFSR，多项式 x^32+x^22+x^2+x+1 |
| MISR | 32-bit MISR，每条扫描链独立 |
| 测试模式数 | 256 patterns（可配置） |
| 预期故障覆盖率 | ≥ 95%（stuck-at） |
| BIST 控制寄存器 | SA_BIST_CTRL（偏移 0x10） |
| BIST 状态寄存器 | SA_BIST_STATUS（偏移 0x14） |

SA_BIST_CTRL 字段：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_en | 使能 LBIST |
| [1] | bist_start | 启动 BIST（自清零） |
| [9:2] | bist_pattern_cnt | 测试 pattern 数（默认 256） |

SA_BIST_STATUS 字段：

| 位 | 字段 | 描述 |
|----|------|------|
| [0] | bist_done | BIST 完成 |
| [1] | bist_pass | 1=通过，0=失败 |
| [5:2] | fail_chain_id | 首个失败扫描链编号 |

## 3. JTAG 接口

| 信号 | 方向 | 描述 |
|------|------|------|
| tck | input | JTAG 时钟（最大 50 MHz） |
| tms | input | 测试模式选择 |
| tdi | input | 测试数据输入 |
| tdo | output | 测试数据输出 |
| trst_n | input | JTAG 复位（低有效） |

支持的 JTAG 指令：

| 指令 | 编码 | 功能 |
|------|------|------|
| BYPASS | 4'hF | 旁路 |
| IDCODE | 4'h1 | 读取器件 ID |
| SAMPLE | 4'h2 | 边界扫描采样 |
| EXTEST | 4'h3 | 外部测试 |
| INTEST | 4'h4 | 内部扫描链访问 |
| BIST_RUN | 4'h5 | 触发 LBIST |

## 4. ATPG 约束

PE 阵列规则结构对 ATPG 友好，建议约束如下：

```tcl
# 扫描链并行压缩（32:1）
set_scan_compression_mode -ratio 32

# PE 阵列时钟约束
set_dft_signal -type ScanClock -port scan_clk -timing {45 55}

# 隔离 CLK_SYS 与 scan_clk
set_dft_signal -type MasterClock -port clk -off_state 0

# 利用 PE 阵列规则性生成 chain-based ATPG
set_atpg_constraints -chain_based_patterns true

# 目标故障覆盖率
set_fault_coverage_target 95
```

预期 ATPG 结果：
- Stuck-at 故障覆盖率：≥ 95%
- Transition 故障覆盖率：≥ 90%
- 测试向量数：< 5000（利用扫描压缩）
