# 第 2 章：前置知识与环境准备

> **本章核心**：补齐"与 AI 协作"的技能树——不仅需要传统的数字电路和 Verilog 基础，还需要 AI 硬件加速知识和 Claude Code 协作能力。

## 2.1 数字电路基础回顾

本节假设你已修完数字电路课程，这里仅做快速速查。如果你对以下内容感到陌生，建议先复习教材再继续阅读。

### 组合逻辑与时序逻辑

| 概念 | 要点 | 典型电路 |
|------|------|---------|
| 组合逻辑 | 输出仅取决于当前输入，无记忆功能 | 加法器、多路选择器、解码器、编码器 |
| 时序逻辑 | 输出取决于当前输入和历史状态，有记忆功能 | 触发器（Flip-Flop）、寄存器、计数器 |

**关键区别**：组合逻辑没有时钟，时序逻辑由时钟驱动。在芯片设计中，时序逻辑是同步设计的核心——所有状态变化都发生在时钟边沿。

### 状态机（FSM）

有限状态机是数字设计的骨架，几乎所有控制逻辑都基于 FSM 实现。两种基本类型：

- **Moore 型**：输出仅取决于当前状态。输出稳定，但状态数可能较多。
- **Mealy 型**：输出取决于当前状态和当前输入。状态数较少，但输出可能在状态内变化。

在 Babel 项目中，Dataflow Controller（M01）的核心就是一个复杂的状态机，负责调度脉动阵列的数据流。它需要在 IDLE、LOAD_WEIGHT、COMPUTE、DRAIN 等状态之间正确切换，每一个状态转换都必须精确无误。

### 时钟、复位与跨时钟域

- **时钟（Clock）**：同步设计的"心跳"。Babel NPU 有三个时钟域：CLK_SYS（250-500 MHz，主计算域）、CLK_AON（1 MHz，常开域）、CLK_IO（50 MHz，IO 域）。
- **复位（Reset）**：将电路恢复到初始状态。同步复位在时钟边沿生效，异步复位立即生效但需要特殊的同步处理。
- **跨时钟域（CDC, Clock Domain Crossing）**：信号从一个时钟域传到另一个时钟域时，必须使用同步器（如两级触发器同步器、DMUX 同步器、握手同步器等），否则可能产生亚稳态。这是芯片设计中最常见的 bug 来源之一。

Babel NPU 的时钟域划分在 `spec/ARCH/block_diagram.md` 中有明确定义：

| 时钟域 | 频率范围 | 所属模块 | DVFS 支持 |
|--------|---------|---------|----------|
| CLK_SYS | 250-500 MHz | M00-M04, M08-M14 | 是 |
| CLK_AON | 1 MHz | M05-M07（电源/时钟/复位管理） | 否 |
| CLK_IO | 50 MHz | M15-M16（JTAG/ISA 接口） | 否 |

## 2.2 Verilog/SystemVerilog 基础

本节同样假设你已有 Verilog 基础，做快速回顾。

### Module 结构与端口声明

```verilog
module counter #(
    parameter WIDTH = 8           // 参数化设计
)(
    input  wire             clk,  // 时钟
    input  wire             rst_n, // 异步低有效复位
    input  wire             en,   // 使能
    output reg  [WIDTH-1:0] count // 计数输出
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= {WIDTH{1'b0}};
    else if (en)
        count <= count + 1'b1;
end

endmodule
```

关键要素回顾：
- `parameter`：参数化设计，让模块可复用
- `input wire` / `output reg`：端口方向与类型声明
- `always @(posedge clk)`：时钟边沿触发的时序逻辑
- `<=`：非阻塞赋值（时序逻辑必须使用）
- `=`：阻塞赋值（仅用于组合逻辑或 initial 块）

### 参数化设计与 generate

SystemVerilog 的 `generate` 语句是构建参数化阵列的关键工具。在 Babel 的脉动阵列设计中，PE（Processing Element）阵列就是用 `generate` 语句按参数自动展开的：

```verilog
// 参数化的 PE 阵列生成（示意）
genvar i, j;
generate
    for (i = 0; i < ROWS; i = i + 1) begin : pe_row
        for (j = 0; j < COLS; j = j + 1) begin : pe_col
            processing_element #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) u_pe (
                .clk(clk),
                .rst_n(rst_n),
                .data_in(data_in[i]),
                .weight(weight[j]),
                .partial_sum(partial_sum[i][j]),
                .data_out(data_out[i]),
                .acc_out(acc_out[i][j])
            );
        end
    end
endgenerate
```

### 可综合性注意事项

不是所有 Verilog 语法都能被综合工具（如 Yosys）转化为门级网表。以下是常见的可综合性陷阱：

| 可综合 | 不可综合（仅用于仿真） |
|--------|---------------------|
| `always @(posedge clk)` | `always #5 clk = ~clk`（时钟生成） |
| `if/else`, `case` | `initial` 块 |
| `assign` 连续赋值 | `#delay` 延迟语句 |
| `for` 在 `generate` 中 | `while`/`forever` 循环 |
| 参数化 `parameter` | `real` 类型（浮点数） |

## 2.3 AI/ML 硬件加速基础

Babel 项目的目标是设计一个 NPU（Neural Processing Unit），因此你需要了解 AI/ML 硬件加速的基础知识。

### 神经网络基本结构与算子

现代深度神经网络的核心计算可以归结为几类基本算子：

| 算子 | 数学表达 | 计算特征 | 硬件实现 |
|------|---------|---------|---------|
| 矩阵乘法（MatMul） | C = A x B | 高度并行，O(N^3) 计算量 | 脉动阵列 |
| 卷积（Conv） | Y = X * W | 可转化为矩阵乘法（im2col） | 脉动阵列 |
| 归一化（RMSNorm） | y = x / RMS(x) * gamma | 逐元素操作，带宽受限 | 专用功能单元 |
| 位置编码（RoPE） | 旋转位置嵌入 | 三角函数运算 | 专用功能单元 |
| 注意力（Attention） | softmax(QK^T/sqrt(d))V | 矩阵乘 + softmax 组合 | 多功能单元协同 |
| 前馈网络（FFN） | 两层 MatMul + 激活函数 | 矩阵乘为主 | 脉动阵列 |

Babel 项目的 NPU 支持的 Transformer 算子包括：Attention（M09）、FFN/MatMul（M10）、RMSNorm/RoPE（M11）、SoftMax（M12），对应 PRD REQ-COMPUTE-008。

### 矩阵运算与脉动阵列

脉动阵列（Systolic Array）是 NPU 的核心计算引擎。它的基本思想是将矩阵乘法映射到一个二维的 PE（Processing Element）阵列上，数据在阵列中有节奏地"脉动"流动，每个 PE 执行一次乘加（MAC）操作。

Babel 的脉动阵列（M00_SystolicArray）支持两种工作模式：

| 模式 | 描述 | 适用场景 |
|------|------|---------|
| Weight Stationary (WS) | 权重固定在 PE 中，输入数据流过阵列 | 大批量矩阵乘法，权重可复用 |
| Output Stationary (OS) | 输出结果固定在 PE 中累加，权重和输入数据流动 | 小批量推理，减少 SRAM 访问次数 |

阵列的算力取决于 PE 数量、时钟频率和数据精度。Babel NPU 的目标算力（PRD REQ-COMPUTE-001~003）：

| 精度 | 目标 TOPS | 用途 |
|------|----------|------|
| FP8 (E4M3/E5M2) | >= 2 TOPS | 低精度推理，KV cache 量化 |
| FP16 | >= 1 TOPS | 标准推理精度 |
| INT8 | >= 2 TOPS | 量化推理 |
| FP32 | 0.5 TOPS（参考） | Baseline 比较 |

### Transformer 架构与推理瓶颈

TinyStories 是一个约 15M 参数的 Transformer 语言模型。Transformer 推理分为两个阶段：

1. **Prefill 阶段**：处理输入 prompt（最多 256 tokens），是计算密集型（compute-bound），主要瓶颈是矩阵乘法的吞吐量。Babel NPU 的 TTFT（Time To First Token）目标为 <= 50 ms（PRD REQ-PERF-004）。
2. **Decode 阶段**：逐 token 生成输出，是访存密集型（memory-bound），主要瓶颈是内存带宽。Babel NPU 的 decode TPS（Tokens Per Second）目标为 >= 100 token/s（FP32）。

这就是为什么 Babel NPU 需要 3D Stacked DRAM 提供 >= 10 GB/s 的带宽（PRD REQ-MEM-002）——在 Decode 阶段，每个 token 的生成都需要从内存中读取模型权重，内存带宽直接决定了推理速度。

### 理解 NPU 的"为什么"

有了以上背景，你就能理解 Babel PRD 中的关键设计决策：

- **为什么需要 512 KB SRAM？**（REQ-MEM-004）——片上 SRAM 作为 scratchpad，缓存当前正在计算的矩阵块，减少对 DRAM 的访问
- **为什么需要 ECC？**（REQ-MEM-005）——边缘环境中软错误率较高，ECC（SECDED）保护数据完整性
- **为什么需要 DVFS？**（REQ-PWR-003）——边缘设备功耗受限（TDP <= 2W），需要根据工作负载动态调整频率和电压
- **为什么需要 FP8？**（REQ-COMPUTE-001）——低精度推理可以在几乎不损失精度的情况下将吞吐量翻倍
- **为什么需要多线程？**（REQ-COMPUTE-006）——线程数 >= 2，允许在等待内存数据时切换到其他计算任务，提高流水线利用率

## 2.4 与 AI Agent 协作的基本能力

AI 原生设计流程要求你掌握与 AI Agent 协作的能力。这不是传统的"使用软件工具"，而是一种新的人机交互范式。

### Claude Code 安装与配置

Claude Code 是 Anthropic 提供的 CLI 工具，是 Babel 项目的核心协作界面。安装步骤：

```bash
# 安装 Claude Code（需要 Node.js >= 18）
npm install -g @anthropic-ai/claude-code

# 进入 Babel 项目目录
cd ~/wrk/Babel

# 启动 Claude Code
claude
```

Claude Code 启动后会自动读取项目目录下的 `CLAUDE.md` 文件，获取项目上下文信息。这就是为什么 Babel 项目的 `CLAUDE.md` 中包含了详细的目录结构、工具链信息和可用 Skill 列表。

### 自然语言描述设计意图（Prompt Engineering for IC）

与 Agent 协作的核心技能是**用自然语言准确描述设计意图**。在芯片设计场景下，这意味着：

**好的 Prompt**：
```
请根据 spec/ARCH/block_diagram.md 中 M01_DataflowController 的定义，
生成一个支持 WS 和 OS 双模式的 dataflow 控制器。
状态机需要包含 IDLE、LOAD_WEIGHT、COMPUTE、DRAIN 四个状态。
握手协议使用 valid/ready。时钟域为 CLK_SYS（500 MHz）。
```

**差的 Prompt**：
```
帮我写一个数据流控制器。
```

差异在于：好的 Prompt 给出了**规范引用**（哪个文档）、**功能要求**（双模式、四状态）、**接口约定**（valid/ready）和**约束条件**（时钟域）。这些信息让 Agent 能够准确理解你的意图。

### 如何审查 Agent 生成的输出

审查 Agent 输出是你的核心职责。审查的层次包括：

1. **功能正确性**：Agent 生成的代码/文档是否实现了规范中定义的功能？
2. **设计合理性**：设计方案是否遵循了最佳实践？是否有明显的效率问题？
3. **一致性检查**：与上游文档（PRD、ARCH、MAS）是否一致？REQ ID 是否正确引用？
4. **边界条件**：是否处理了复位、空操作、溢出等边界情况？

### 如何给 Agent 有效的反馈

当 Agent 的输出不符合预期时，有效的反馈应包含：

1. **具体问题**：不要说"这不对"，而要说"M01 的状态机缺少 DRAIN 状态，当计算完成后应该先进入 DRAIN 状态清空流水线再回到 IDLE"
2. **引用规范**：指出对应的 spec 章节或 REQ ID
3. **修正方向**：给出你期望的行为或结构
4. **验证标准**：告诉 Agent 如何判断修复是否成功

## 2.5 开发环境准备

### Linux 基础命令

Babel 项目运行在 Linux 环境下。你需要熟悉以下基础命令：

```bash
# 文件与目录操作
ls -la          # 列出文件详情
find . -name "*.v"  # 搜索 Verilog 文件
grep -r "module" rtl/  # 搜索模块定义

# 环境变量
echo $PATH      # 查看 PATH
export VAR=value  # 设置环境变量
source script.sh  # 执行脚本（在当前 shell 中）

# 进程管理
top             # 查看系统资源
ps aux | grep yosys  # 查找进程
```

### Git 版本控制

Babel 项目使用 Git 进行版本管理。基本操作：

```bash
# 克隆项目
git clone <repo-url> Babel
cd Babel

# 查看状态和变更
git status          # 查看工作区状态
git diff            # 查看未暂存的变更
git log --oneline   # 查看提交历史

# 提交变更
git add <file>      # 暂存文件
git commit -m "描述性提交信息"  # 提交
```

在 AI 原生流程中，Git 的重要性更高而非更低——Agent 每次生成的重要输出都应该提交到 Git，这样可以追踪设计的演化过程，也可以在 Agent 输出有问题时回退到之前的版本。

### 项目克隆与初始化

```bash
# 克隆 Babel 项目
git clone https://gitlink.org.cn/amoslee2011/Babel.git
cd Babel

# 加载 EDA 工具环境
source ~/wrk/eda_opensources/eda_env.sh

# 验证工具链可用
yosys --version       # 应输出 Yosys 0.35
verilator --version   # 应输出版本信息
sta -version          # 应输出 OpenSTA 版本

# 启动 Claude Code
claude
```

### 验证环境完整性

环境初始化完成后，建议做以下验证：

```bash
# 检查 ASAP7 工艺库
ls libs/asap7/         # 应看到 asap7sc6t_26, asap7sc7p5t_27 等目录

# 检查规范文档完整
ls spec/PRD/PRD.md     # PRD 文档
ls spec/ARCH/          # 架构文档（chip_overview.md, block_diagram.md 等）
ls spec/MAS/           # 微架构文档（module_tree.md, plan.md 等）

# 检查 Claude Code 能识别 Skill
# 在 Claude Code 中输入：/bb-invoke-yosys --help
```

如果以上检查全部通过，你的开发环境已经准备就绪，可以开始后续章节的实践了。

## 本章小结

1. **数字电路与 Verilog 是基础中的基础**：组合逻辑、时序逻辑、状态机、跨时钟域处理——这些概念你应该已经掌握，本章仅作速查。Babel NPU 的三个时钟域（CLK_SYS、CLK_AON、CLK_IO）之间的 CDC 处理是设计中的关键难点。

2. **AI/ML 硬件加速是领域知识**：理解脉动阵列的 WS/OS 双模式、Transformer 推理的 compute-bound 和 memory-bound 特性，是理解 Babel NPU 设计决策的前提。

3. **Prompt Engineering 是新核心技能**：在 AI 原生模式下，用自然语言准确描述设计意图的能力，等同于传统模式下编写 RTL 的能力。给出规范引用、功能要求和验证标准，是高效协作的基础。

4. **审查能力比编码能力更重要**：在 AI 原生模式下，你的核心价值不在于能多快写出代码，而在于能多准确地判断 Agent 输出的质量。

5. **环境准备是一切的前提**：Linux、Git、Claude Code、开源 EDA 工具链——确保你的开发环境完整可用，才能顺利进入后续章节的实践环节。
