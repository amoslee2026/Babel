# 第 15 章：术语表

> 本章汇总了教程中出现的所有专业术语、缩写和概念。分为芯片设计术语、AI/Agent 术语和 Babel 特有术语三大类，供读者随时查阅。

---

## 15.1 芯片设计术语

### 设计流程与文档

| 术语 | 全称 | 含义 |
|------|------|------|
| PRD | Product Requirements Document | 产品需求文档，定义芯片的功能、性能、功耗、面积等目标指标，是人机协作的起点 |
| ARCH | Architecture Specification | 架构规范文档，定义芯片的模块划分、互联关系、时钟域和功耗域 |
| MAS | Micro-Architecture Specification | 微架构规范文档，定义各模块的详细端口、参数、行为、时序，是 ARCH 到 RTL 的桥梁 |
| RTL | Register Transfer Level | 寄存器传输级，数字电路的硬件描述语言层次，用 Verilog/SystemVerilog 编写 |
| PD | Physical Design | 物理设计，将门级网表转化为物理版图的全过程（Floorplan → Placement → Routing） |
| GDSII | Graphic Database System II | 版图数据格式标准，芯片制造的最终交付文件 |
| Netlist | Netlist | 网表，电路的连接关系描述。综合输出门级网表，LVS 输出版图提取网表 |
| SDC | Synopsys Design Constraints | 时序约束文件格式，定义时钟、输入/输出延迟、false path 等约束 |
| LEF | Library Exchange Format | 库交换格式，描述标准单元的物理信息（尺寸、Pin 位置、Metal 层） |
| Liberty (.lib) | Liberty Library Format | 标准单元库的时序、功能、功耗描述文件，综合和 STA 的核心输入 |
| PDK | Process Design Kit | 工艺设计套件，代工厂提供的器件模型、设计规则和标准单元库 |

### 验证与检查

| 术语 | 全称 | 含义 |
|------|------|------|
| DRC | Design Rule Check | 设计规则检查，验证版图是否满足制造工艺的几何规则（间距、宽度、包围等） |
| LVS | Layout vs Schematic | 版图与原理图对比，验证版图提取的电路是否与设计的网表功能一致 |
| STA | Static Timing Analysis | 静态时序分析，不依赖仿真激励的时序验证方法，分析所有路径的建立/保持时间 |
| CDC | Clock Domain Crossing | 跨时钟域信号传输，需要特殊处理（同步器、握手协议）以避免亚稳态 |
| Lint | Lint Check | 代码静态检查，发现可综合性问题、编码规范违规、潜在功能错误 |
| DFT | Design for Testability | 可测试性设计，插入扫描链等结构以支持制造后的芯片测试 |
| MBIST | Memory Built-In Self-Test | 存储器内建自测试，用于制造后的 SRAM/DRAM 功能测试 |
| TB | Testbench | 测试平台，为 DUT（待测设计）提供激励并检查响应的验证环境 |
| DUT | Design Under Test | 待测设计，当前正在验证的目标模块或芯片 |

### 时序相关

| 术语 | 全称 | 含义 |
|------|------|------|
| WNS | Worst Negative Slack | 最差负裕量，所有路径中最小的 slack 值。WNS >= 0 表示时序收敛 |
| TNS | Total Negative Slack | 总负裕量，所有违例路径的 slack 之和。TNS 越接近 0 越好 |
| Slack | Slack | 时序裕量 = Required Time - Arrival Time。正值表示满足，负值表示违例 |
| Setup Time | Setup Time | 建立时间，数据必须在时钟有效沿到来之前保持稳定的最小时间 |
| Hold Time | Hold Time | 保持时间，数据必须在时钟有效沿到来之后继续保持稳定的最小时间 |
| Critical Path | Critical Path | 关键路径，设计中延迟最长的组合逻辑路径，决定了芯片的最高工作频率 |
| Fanout | Fanout | 扇出，一个信号驱动负载的数量。扇出过大会增加延迟和功耗 |
| False Path | False Path | 假路径，功能上不会传播数据的路径（如复位信号），STA 中可忽略 |
| Multicycle Path | Multicycle Path | 多周期路径，允许多个时钟周期完成数据传输的路径 |

### 物理设计

| 术语 | 全称 | 含义 |
|------|------|------|
| Floorplan | Floorplan | 布局规划，确定 Die/Core 尺寸、模块摆放位置、Pin 分配、Blockage 设置 |
| Placement | Placement | 单元放置，将标准单元放置到芯片版图的合适位置 |
| Routing | Routing | 布线，用金属线连接放置好的单元，分为全局布线和详细布线 |
| Die | Die | 芯片裸片，从晶圆上切割下来的单个芯片 |
| Core | Core | 核心区域，Die 内部用于放置标准单元的区域（Die 减去 IO ring 后的部分） |
| Standard Cell | Standard Cell | 标准单元，预定义的逻辑门物理实现（如 NAND2、DFF、BUF），是数字 IC 的基本构建块 |
| CTS | Clock Tree Synthesis | 时钟树综合，构建低偏斜的时钟分配网络 |
| Utilization | Utilization | 面积利用率，标准单元面积占 Core 面积的比例，通常 60-80% 为合理范围 |
| TSV | Through-Silicon Via | 硅通孔，3D 封装中连接不同层芯片的垂直导电通道 |

### 硬件架构

| 术语 | 全称 | 含义 |
|------|------|------|
| Systolic Array | Systolic Array | 脉动阵列，规则排列的 PE 阵列，数据像脉搏一样在 PE 间流动，高效执行矩阵乘法 |
| PE | Processing Element | 处理单元，脉动阵列中的基本计算节点，通常包含乘法器和累加器（MAC） |
| WS | Weight Stationary | 权重固定模式，权重驻留在 PE 中，输入数据流过，适合大批量矩阵乘法 |
| OS | Output Stationary | 输出固定模式，部分和驻留在 PE 中，权重和输入数据流过，减少 SRAM 访问 |
| Spatial Dataflow | Spatial Dataflow | 空间数据流，多个算子在物理上串联形成流水线，数据在算子间流动无需写回 SRAM |
| FSM | Finite State Machine | 有限状态机，数字电路中的控制逻辑基本结构 |
| DVFS | Dynamic Voltage and Frequency Scaling | 动态电压频率调节，根据负载调整工作电压和频率以降低功耗 |
| ECC | Error Correction Code | 纠错码，用于检测和修正存储器中的数据错误 |
| SECDED | Single Error Correction, Double Error Detection | 单比特纠错、双比特检错，常用的 ECC 保护方案 |
| MAC | Multiply-Accumulate | 乘法累加运算，神经网络推理的核心运算（y = sum(w_i * x_i)） |

### 性能指标

| 术语 | 全称 | 含义 |
|------|------|------|
| TOPS | Tera Operations Per Second | 每秒万亿次运算，衡量 AI 加速器计算吞吐量的标准单位 |
| TOPS/W | TOPS per Watt | 能效比，每瓦功耗可提供的算力，衡量设计的效率 |
| TPS | Tokens Per Second | 每秒生成的 token 数，衡量 LLM 推理速度 |
| TTFT | Time To First Token | 首个 token 生成时间，衡量 LLM 推理的响应延迟 |
| TDP | Thermal Design Power | 热设计功耗，芯片的最大持续散热功耗 |
| Fmax | Maximum Frequency | 最大工作频率，芯片能正常工作的最高时钟频率 |
| MTTF | Mean Time To Failure | 平均无故障时间，衡量可靠性的指标（单位：小时） |
| FIT | Failures In Time | 每 10^9 小时的故障次数，衡量软错误率的单位 |
| SER | Soft Error Rate | 软错误率，由宇宙射线等导致的随机比特翻转率 |
| PPA | Power, Performance, Area | 功耗、性能、面积——芯片设计的三个核心优化维度 |

---

## 15.2 AI/Agent 术语

| 术语 | 全称 | 含义 |
|------|------|------|
| Agent | AI Agent | AI 代理，能够自主规划、执行多步任务的 AI 系统 |
| Skill | Skill / Slash Command | 技能命令，Agent 可调用的预定义工作流，通过 `/` 命令触发 |
| Prompt | Prompt | 提示词，人给 Agent 的自然语言指令或输入 |
| Prompt Engineering | Prompt Engineering | 提示工程，设计有效 Prompt 以提高 Agent 输出质量的方法论 |
| LLM | Large Language Model | 大语言模型，如 Claude、GPT 等，是 Agent 的推理引擎 |
| Quality Gate | Quality Gate | 质量门控，每个阶段的自动化检查标准，不通过则不能进入下一阶段 |
| Coverage | Coverage | 覆盖率，测试对设计功能的覆盖程度。Babel 要求 100% |
| Handoff | Handoff | 交付物/交接，一个阶段的输出传递给下一阶段的过程 |
| Signoff | Signoff | 签核，正式确认某个阶段的所有质量检查已通过 |
| Artifact | Signoff Artifact | 签核产物，每个阶段通过 Quality Gate 后输出的正式文件 |
| Iteration | Iteration | 迭代，Agent 重复执行某个过程直到满足条件 |
| Convergence | Convergence | 收敛，迭代过程中指标（时序、覆盖率等）逐步接近目标 |
| CDV | Coverage-Driven Verification | 覆盖率驱动验证，以覆盖率为目标自动生成和补充测试用例 |
| SHA256 | SHA256 Hash | 安全哈希算法，Agent 用于校验 handoff 文档的完整性 |
| Context Window | Context Window | 上下文窗口，LLM 单次交互能处理的最大 token 数 |

---

## 15.3 Babel 特有术语

### 流程 Agent（bba-* 系列）

| 术语 | 全称 | 含义 |
|------|------|------|
| `/bba-architect` | Babel Architect Agent | 架构设计 Agent，从 PRD 生成 ARCH + MAS 文档集 |
| `/bba-guru-rtl` | Babel Guru RTL Agent | RTL 生成 Agent，从 MAS 生成 Lint-clean 的 SystemVerilog 代码 |
| `/bba-guru-verification` | Babel Guru Verification Agent | 验证 Agent，生成 TB、运行仿真、驱动覆盖率收敛到 100% |
| `/bba-guru-synthesis` | Babel Guru Synthesis Agent | 综合 Agent，生成 SDC、运行 Yosys+OpenSTA、迭代到时序收敛 |
| `/bba-guru-pd` | Babel Guru PD Agent | 物理设计 Agent，执行 Floorplan → Routing → DRC/LVS → GDSII |

### 工具调用 Skill（bb-invoke-* 系列）

| 术语 | 调用工具 | 功能 |
|------|---------|------|
| `/bb-invoke-yosys` | Yosys 0.35 | 调用 Yosys 执行 RTL 综合 |
| `/bb-invoke-verilator` | Verilator | 调用 Verilator 执行仿真，支持 VCD 波形和覆盖率 |
| `/bb-invoke-opensta` | OpenSTA 2.2.0 | 调用 OpenSTA 执行静态时序分析 |
| `/bb-invoke-magic` | Magic 8.3.641 | 调用 Magic 执行版图编辑/DRC |
| `/bb-invoke-netgen` | Netgen 1.5 | 调用 Netgen 执行 LVS 网表比对 |
| `/bb-invoke-qrouter` | QRouter 1.4 | 调用 QRouter 执行详细布线 |
| `/bb-invoke-klayout` | KLayout 0.30.8 | 调用 KLayout 查看 GDSII / 执行 DRC |
| `/bb-invoke-abc` | ABC | 调用 ABC 执行逻辑优化（Yosys 内部使用） |

### 辅助 Skill

| 术语 | 功能 |
|------|------|
| `/bb-check-lint` | 运行 Lint 检查，报告 RTL 编码规范违规 |
| `/bb-check-cdc` | 运行 CDC 检查，报告跨时钟域处理问题 |
| `/bb-create-sdc` | 根据 MAS 时序约束自动生成 SDC 文件 |
| `/bb-create-floorplan` | 根据综合面积估算生成 Floorplan 脚本 |
| `/bb-generate-tb` | 根据验证计划生成 Testbench |
| `/bb-create-verif-plan` | 根据 MAS 生成验证计划文档 |
| `/bb-collect-coverage` | 采集并分析覆盖率数据 |
| `/bb-gate-rtl-quality` | RTL 质量门控检查 |
| `/bb-gate-test-quality` | 测试质量门控检查（覆盖率是否达标） |
| `/bb-gate-synth-quality` | 综合质量门控检查（时序是否收敛） |
| `/bb-gate-pd-quality` | 物理设计质量门控检查（DRC/LVS 是否通过） |

### Issue 管理

| 术语 | 功能 |
|------|------|
| `/bb-create-issue` | 创建 Issue，记录问题的模块、类型、严重度（CRITICAL/HIGH/MEDIUM/LOW）和描述 |
| `/bb-list-issues` | 列出 Issue，支持按状态（OPEN/CLOSED）、严重度、模块筛选 |
| `/bb-close-issue` | 关闭 Issue，记录修复方案和验证结果 |

### Babel 项目概念

| 术语 | 含义 |
|------|------|
| Spec-Driven Development | 规范驱动开发，Babel 的核心方法论：规范文档是唯一真相源，Agent 从 spec 生成一切 |
| Agent Pipeline | Agent 流水线：PRD → ARCH → MAS → RTL → VER → SYN → PD |
| Module ID (M00-M16) | NPU 模块编号，每个模块有唯一的 ID 和名称（如 M00_SystolicArray） |
| REQ ID | PRD 中的需求编号（如 REQ-COMPUTE-001），用于追踪需求在设计中的实现状态 |
| Signoff Artifact | 签核产物，每个阶段通过 Quality Gate 后输出的正式文件（如 synth_report、test_report） |
| ASAP7 | Arizona State University 7nm Predictive PDK，Babel 使用的 7nm 教学工艺库 |
| TinyStories | 小型 Transformer 语言模型（~15M 参数），Babel NPU 的目标推理工作负载 |
| llama2.c | Andrej Karpathy 的 C 语言 LLM 推理实现，Babel NPU 的参考模型和 ISA 设计依据 |

### Transformer 算子术语

| 术语 | 全称 | 含义 |
|------|------|------|
| Attention | Self-Attention | 自注意力机制，计算序列中各 token 之间的关联权重 |
| FFN | Feed-Forward Network | 前馈网络，Transformer 中注意力层之后的全连接网络 |
| MatMul | Matrix Multiplication | 矩阵乘法，NPU 计算的核心运算，占推理计算量的 ~90% |
| RMSNorm | Root Mean Square Normalization | 均方根归一化，比 LayerNorm 更轻量的归一化方法 |
| RoPE | Rotary Position Embedding | 旋转位置编码，通过旋转矩阵注入序列位置信息 |
| Softmax | Softmax Function | 归一化指数函数，将注意力分数转换为概率分布 |
| SwiGLU | Swish-Gated Linear Unit | Swish 门控线性单元，一种 FFN 激活函数变体 |
| KV Cache | Key-Value Cache | 键值缓存，存储历史 token 的 K/V 向量以加速自回归推理 |
| Embedding | Token Embedding | 词嵌入，将离散 token ID 映射为连续向量的查表操作 |
