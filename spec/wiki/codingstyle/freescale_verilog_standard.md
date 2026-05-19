# Freescale Verilog HDL Coding Standard

> **来源**: https://people.ece.cornell.edu/land/courses/ece5760/Verilog/FreescaleVerilog.pdf
> **文档编号**: IPMXDSRSHDL0001
> **版本**: SRS V3.2
> **发布日期**: 01 FEB 2005
> **版权**: © Freescale Semiconductor, Inc. 2005

---

## 目录

- [7.1 Introduction](#71-introduction)
- [7.2 Reference Information](#72-reference-information)
- [7.3 Naming Conventions](#73-naming-conventions)
- [7.4 Comments](#74-comments)
- [7.5 Code Style](#75-code-style)
- [7.6 Module Partitioning and Reusability](#76-module-partitioning-and-reusability)
- [7.7 Modeling Practices](#77-modeling-practices)
- [7.8 General Coding Techniques](#78-general-coding-techniques)
- [7.9 Standards for Structured Test Techniques](#79-standards-for-structured-test-techniques)
- [7.10 General Standards for Synthesis](#710-general-standards-for-synthesis)

---

## 7.1 Introduction

Verilog HDL 编码标准涉及虚拟组件 (VC) 生成，涵盖命名约定、代码文档和代码格式/风格。遵守这些标准可以简化重用，通过描述代码中不存在的内容，提高代码可读性，并确保与大多数工具的兼容性。

这些标准适用于行为级和可综合代码，以及所有其他用 Verilog 编写的代码，如 testbench 和 monitor。

**注意**: V3.2 版本的规则和指南仅对新 IP（即 V3.2 发布日期之后编码的 IP）要求合规。但如果旧 IP 没有问题，也可以用 V3.2 认证。

### 7.1.1 Deliverables

IP repository 的交付物包括：

| 标识符 | 描述 |
|--------|------|
| L1 | Synthesizable RTL Source Code |
| V1 | Testbench |
| V2 | Drivers |
| V3 | Monitors |
| V4 | Detailed Behavioral Model |
| V5 | HDL Interface Model |
| V6 | Stub Model |
| V13 | Emulation |

---

## 7.2 Reference Information

### 7.2.1 Referenced Documents

| 编号 | 文档 |
|------|------|
| [1] | IEEE Verilog Hardware Description Language, IEEE Standard 1364-1995 |
| [2] | IEEE Verilog Hardware Description Language, IEEE Standard 1364-2001, Version C |
| [3] | Verilog-AMS Language Reference Manual, Version 2.2, November 2004, Accellera |
| [4] | SystemVerilog 3.1a Language Reference Manual, Accellera's Extensions to Verilog, May 2004 |

### 7.2.2 Terminology

| 术语 | 定义 |
|------|------|
| **Base address** | SoC 地址空间中用于访问寄存器的基准地址 |
| **Deliverables** | VC 交付物是由设计组成的一组文件 |
| **Guideline** | "推荐"的做法，增强快速 SoC 设计、集成和生产 |
| **HDL** | Hardware Description Language |
| **Mask plug** | 连接到 VDD 或 VSS 的线，用于配置模块而无需重新综合 |
| **PLL** | Phase-Locked Loop |
| **Properties** | 分配值的变量，也称为 "Metadata" |
| **RTL** | Register Transfer Level |
| **Rule** | "必须"的做法，确保快速 SoC 设计、集成和生产 |
| **Text macro** | `define |
| **Top-level module** | VC 设计层次中最高级别的模块 |
| **UDP** | User-Defined Primitive |
| **VC** | Virtual Component - 预实现的可重用 IP 模块 |

---

## 7.3 Naming Conventions

### 7.3.1 File Naming

#### R 7.3.1 - 每个文件最多一个模块

**规则**: 一个文件必须最多包含一个模块。

**原因**: 简化设计修改。

**适用**: L1,V1,V2,V3,V4,V5,V6,V7,V13

#### R 7.3.2 - 文件命名约定

**规则**: 文件名必须按以下方式组成：

```
<top_level_module_name>[_<module_name_extension>][_<file_type>].<extension>
```

其中：
- `<top_level_module_name>` - 顶层模块名称
- `<module_name_extension>` - 子模块名称扩展
- `<file_type>` - 文件类型：task/func/defines
- `<extension>` - .v/.va/.vams

**示例**: spooler.v, spooler_task.v

#### R 7.3.3 - 分离模拟、数字和混合信号文件

**规则**: 文件必须只包含：数字/模拟/混合信号 Verilog 代码。

---

### 7.3.2 Naming of HDL Code Items

#### R 7.3.4 - HDL 代码项命名约定

a. 名称必须描述用途，按"做什么"命名
b. 使用英语
c. 以字母开头，字母数字或下划线
d. 不允许连续下划线
e. 多单词使用下划线分隔
f. 整个设计保持一致风格
g. RTL 与文档名称一致
h. 常量大写，非常量小写
i. 不使用 SV/VHDL 关键字

#### R 7.3.5 - 文档化缩写

**例外**: RAM 等已知缩写和循环计数器 i/n

#### R 7.3.6 - 全局 macros 包含模块名

```verilog
`define SPOOLER_ADDR_BUS_WIDTH 32
```

#### R 7.3.7 - Instance 命名

单实例：与模块名相同；多实例：编号后缀

```verilog
mag2mag_fifo mag2mag_fifo_0 (...);
mag2mag_fifo fifo_tx (...);
```

#### R 7.3.8 - Signal 后缀约定

| 后缀 | 含义 |
|------|------|
| `_pn` | Pipeline stage |
| `_async` | 异步信号 |
| `_sync` | 已同步信号 |
| `_ns` | Next state |
| `_ff` | Flip-flop output |
| `_l` | Latch output |
| `_clk` | Clock |
| `_z` | High impedance |
| `_b` | Active low |
| `_nc` | Not connected |
| `_test` | Test signal |
| `_se` | Scan enable |

#### R 7.3.9 - Signal 前缀约定

a. `<top_level>_<signal>` - 出顶层
b. `<top_level>_<submodule>_<signal>` - 出子模块
c. `<signal>` - 内部信号

#### R 7.3.11 - 名称长度 ≤ 32 字符

---

## 7.4 Comments

### 7.4.1 File Headers

**示例文件头**:
```verilog
// +FHDR------------------------------------------------------------------------
// Copyright (c) 2004 Freescale Semiconductor, Inc.
// -----------------------------------------------------------------------------
// FILE NAME : prescaler.v
// DEPARTMENT : SPS SoCDT, Austin TX
// AUTHOR : Mike Kentley
// -----------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION DATE AUTHOR DESCRIPTION
// 1.0 1998-09-12 tommyk initial version
// -----------------------------------------------------------------------------
// KEYWORDS : clock divider, divide by 16
// PURPOSE : divide input clock by 16.
// -----------------------------------------------------------------------------
// REUSE ISSUES
// Reset Strategy : Asynchronous, active low
// Clock Domains : core_32m_clk, system_clk
// Synthesizable : Y
// -FHDR------------------------------------------------------------------------
```

### 7.4.2 Construct Headers

```verilog
// +HDR ------------------------------------------------------------------------
// NAME : 
// TYPE : func/task/primitive
// PURPOSE : Short description
// -HDR ------------------------------------------------------------------------
```

### 7.4.3 Comment 约定

- 使用单行注释 `//`
- 不使用多行注释 `/*...*/`
- 旧代码删除而非注释
- 端口声明必须有注释

---

## 7.5 Code Style

#### R 7.5.1 - 表格格式

代码项对齐。

#### R 7.5.2 - 使用空格缩进

不使用 tab stops。

#### R 7.5.3 - 每行一语句

```verilog
// 正确
upper_en = (p5type && xadr1[0]);
lower_en = (p5type && !xadr1[0]);
// 错误
upper_en = ...; lower_en = ...;
```

#### R 7.5.4 - 每行一端口

```verilog
input a; // port a description
input b; // port b description
```

#### G 7.5.7 - 行长度 ≤ 80 字符

---

## 7.6 Module Partitioning

#### R 7.6.1 - 不访问范围外 nets

不使用层次引用。

**例外**: 非可综合块

#### G 7.6.2 - 避免 `include

**例外**: `define 文件

#### G 7.6.5 - Partitioning 约定

a. 模块边界匹配物理边界
b. 应用特定与通用代码分开
c. 速度关键逻辑单独模块
d. 数据路径与非数据路径分开

#### G 7.6.6 - 时钟 Partitioning

a. Gated clock 生成电路在顶层单独模块
b. 不同时钟域分开模块
c. 异步与同步逻辑分开

---

## 7.7 Modeling Practices

#### R 7.7.2 - 同步异步信号

使用双寄存避免 metastability。

#### R 7.7.4 - 无 glitch 的 gated clocks

#### R 7.7.6 - 初始化控制存储元素

所有 latches/registers 必须初始化。

#### G 7.7.8 - 使用同步设计

#### R 7.7.9 - 无组合反馈循环

**例外**: 数字 PLL 等特殊模块

---

## 7.8 General Coding Techniques

#### R 7.8.1 - 条件为 1-bit

```verilog
// 正确
if (bus > 0) bus_is_active = 1;
// 错误
if (bus) bus_is_active = 1;
```

#### R 7.8.2 - 一致 bus bit 顺序

#### G 7.8.5 - 用 parameters 而非 `define

**例外**: 全局常量

#### R 7.8.8 - Parameters 编码状态

```verilog
parameter [1:0] RESET_STATE, TX_STATE, RX_STATE;
```

#### R 7.8.18 - 按名称连接端口

```verilog
block block_1 (.signal_a(signal_a), .signal_b(signal_b));
```

#### G 7.8.21 - 避免 inout 端口

拆分为 input/output。

#### G 7.8.25 - Case 编码状态机

```verilog
always @(posedge clock)
  if (!reset_b) state <= RESET_STATE;
  else state <= state_ns;

always @(state)
  case (state)
    RESET_STATE: state_ns = INIT_STATE;
    ...
  endcase
```

#### R 7.8.26 - 无内部三态

使用 mux 替代。

---

## 7.9 Structured Test Techniques

#### R 7.9.2 - 允许 PLL bypass

#### R 7.9.4 - Gated clocks 有扫描支持

#### R 7.9.5 - 外部控制异步复位

#### R 7.9.6 - Latches 扫描期间透明

---

## 7.10 Synthesis Standards

#### R 7.10.1 - 完整 sensitivity list

包含所有输入信号。

#### R 7.10.2 - 一时钟 per always

#### R 7.10.3 - 只用可综合构造

禁止：`# delay`, `initial`, `$display`, `force`

#### R 7.10.4 - 完全指定组合逻辑

```verilog
always @(signal_name) begin
  output = 4'b0000;  // 默认值
  case (signal_name)
    3'b001: output = 4'b0000;
    ...
  endcase
end
```

#### G 7.10.5 - Case 前赋默认值

#### G 7.10.6 - 避免 full_case directive

#### R 7.10.11 - 禁止 primitives

不用 `and`, `or`, UDPs。

#### R 7.10.12 - 非阻塞赋值推断 FF/latch

```verilog
// 正确
always @(posedge clk) regb <= rega;
always @(posedge clk) rega <= data;

// 错误 - 可能前后仿真不匹配
always @(posedge clk) regb = rega;
always @(posedge clk) rega = data;
```

#### R 7.10.13 - 驱动未用输入

#### R 7.10.16 - 不用 casex

用 `case` 或 `casez`。

---

## 附录：完整示例

```verilog
module prescaler(
  core_32m_clk, system_clock,
  scan_mode_test, reset_b,
  div16_clk, div16_clk_b
);

input core_32m_clk;    // 32 MHz clock
input system_clk;      // system clock
input scan_mode_test;  // scan mode
input reset_b;         // active low reset
output div16_clk;      // clock / 16
output div16_clk_b;    // clock / 16 inverted

reg[3:0] count_ff;
reg div16_clk, div16_clk_b;
wire[3:0] count_ns;

assign count_ns = count_ff + 4'b0001;

always @(posedge core_32m_clk or negedge reset_b)
  if (!reset_b) count_ff <= 4'b0000;
  else count_ff <= count_ns;

// synopsys infer_mux "clk_mux"
always @(scan_mode_test or system_clk or count_ff)
begin: clk_mux
  if (!scan_mode_test) begin
    div16_clk = count_ff[3];
    div16_clk_b = ~count_ff[3];
  end else begin
    div16_clk = system_clk;
    div16_clk_b = system_clk;
  end
end

endmodule
```