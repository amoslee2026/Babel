# 第 16 章：延伸阅读与参考资料

> 本章汇总了 Babel 项目相关的工具、论文、书籍、社区和在线课程的索引。读者可根据当前学习阶段选择性阅读，无需全部掌握。

---

## 16.1 开源 EDA 资源

### 核心工具官方文档

Babel 项目依赖以下 7 个开源 EDA 工具完成从 RTL 到 GDSII 的完整设计流程。

| 工具 | 版本 | 官方文档 | 源码仓库 |
|------|------|---------|---------|
| **Yosys** | 0.35 | [yosyshq.net/yosys/](https://yosyshq.net/yosys/) | [github.com/YosysHQ/yosys](https://github.com/YosysHQ/yosys) |
| **OpenSTA** | 2.5.0 | [OpenSTA User Guide (PDF)](https://github.com/The-OpenROAD-Project/OpenSTA/blob/master/doc/OpenSTA.pdf) | [github.com/The-OpenROAD-Project/OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA) |
| **Verilator** | 5.012 | [verilator.org/guide/latest/](https://verilator.org/guide/latest/) | [github.com/verilator/verilator](https://github.com/verilator/verilator) |
| **Magic** | 8.3.641 | [opencircuitdesign.com/magic/](http://opencircuitdesign.com/magic/) | [github.com/RTimothyEdwards/magic](https://github.com/RTimothyEdwards/magic) |
| **Netgen** | 1.5.275 | [opencircuitdesign.com/netgen/](http://opencircuitdesign.com/netgen/) | [github.com/RTimothyEdwards/netgen](https://github.com/RTimothyEdwards/netgen) |
| **QRouter** | 1.4 | [opencircuitdesign.com/qrouter/](http://opencircuitdesign.com/qrouter/) | [github.com/RTimothyEdwards/qrouter](https://github.com/RTimothyEdwards/qrouter) |
| **KLayout** | 0.30.8 | [klayout.de/doc.html](https://www.klayout.de/doc.html) | [github.com/KLayout/klayout](https://github.com/KLayout/klayout) |

### 辅助工具

| 工具 | 说明 | 链接 |
|------|------|------|
| **ABC** | 逻辑优化引擎，被 Yosys 内部调用 | [github.com/berkeley-abc/abc](https://github.com/berkeley-abc/abc) |
| **Icarus Verilog** | 轻量级 Verilog 仿真器，适合快速验证小模块 | [iverilog.icarus.com](http://iverilog.icarus.com/) |
| **GTKWave** | 波形查看工具，配合 Verilator 的 VCD 输出使用 | [gtkwave.sourceforge.net](http://gtkwave.sourceforge.net/) |
| **Graywolf** | 单元放置工具（Magic 的替代/补充选项） | [github.com/rubberduck203/graywolf](https://github.com/rubberduck203/graywolf) |

### 完整流程平台

| 项目 | 说明 | 链接 |
|------|------|------|
| **OpenROAD** | 开源 RTL-to-GDSII 完整设计平台，集成 Yosys、OpenSTA 等 | [theopenroadproject.org](https://theopenroadproject.org/) |
| **OpenLane** | 基于 OpenROAD 的自动化设计流程，Docker 化部署 | [github.com/The-OpenROAD-Project/OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) |

### 开源 PDK

| PDK | 工艺 | 说明 | 链接 |
|-----|------|------|------|
| **ASAP7** | 7nm | 亚利桑那州立大学开发的预测性 PDK，Babel 项目使用 | [asap.asu.edu](https://asap.asu.edu/) |
| **SkyWater 130nm** | 130nm | Google/SkyWater 开源 PDK，可用于实际流片 | [github.com/google/skywater-pdk](https://github.com/google/skywater-pdk) |
| **Nangate 45nm** | 45nm | 开源 45nm 标准单元库，教学和原型验证常用 | [freepdk.ncsu.edu](https://freepdk.ncsu.edu/) |

---

## 16.2 芯片设计教材推荐

### 数字电路设计

| 书名 | 作者 | 适用阶段 | 说明 |
|------|------|---------|------|
| 《数字集成电路：电路、系统与设计》 | Jan Rabaey | 本科/研究生 | 数字 IC 设计经典教材，从晶体管到系统级 |
| 《CMOS VLSI Design: A Circuits and Systems Perspective》 | Weste & Harris | 本科/研究生 | CMOS 电路设计权威参考，强调实际设计技巧 |
| 《Digital Design and Computer Architecture》 | Harris & Harris | 本科入门 | 从数字逻辑到计算机架构，适合初学者 |

### Verilog / SystemVerilog

| 书名 | 作者 | 适用阶段 | 说明 |
|------|------|---------|------|
| 《Verilog and SystemVerilog Gotchas》 | Salemi | 有经验的工程师 | 常见错误和最佳实践 |
| 《SystemVerilog for Verification》 | Spear & Tumbush | 验证工程师 | 验证方法学系统讲解，涵盖 testbench 和 coverage |
| 《Writing Testbenches with SystemVerilog》 | Wilson | 验证工程师 | testbench 编写实战指南 |

### 物理设计

| 书名 | 作者 | 适用阶段 | 说明 |
|------|------|---------|------|
| 《VLSI Physical Design: From Graph Partitioning to Timing Closure》 | Kahng et al. | 研究生/从业者 | 物理设计前沿研究 |
| 《Algorithms for VLSI Physical Design Automation》 | Sherwani | 研究生 | 物理设计算法经典参考 |
| 《Electronic Design Automation: Synthesis, RTL to GDSII》 | Laung-Terng Wang | 研究生 | EDA 算法综合介绍 |

---

## 16.3 AI 硬件加速器论文

### 脉动阵列与矩阵计算

| 论文 | 会议/期刊 | 年份 | 说明 |
|------|----------|------|------|
| Kung et al., "Why Systolic Architectures?" | IEEE Computer | 1982 | 脉动阵列的奠基性论文，Babel NPU 计算核心的理论基础 |
| Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit" | ISCA | 2017 | TPU v1 架构论文，奠定现代 AI 加速器设计范式 |
| Jouppi et al., "A Domain-Specific Architecture for Deep Neural Networks" | IEEE Micro | 2020 | TPU v2/v3 演进，引入 bfloat16 和多芯片互联 |
| Jouppi et al., "Ten Future Challenges for AI Hardware" | IEEE Micro | 2023 | TPU v4 及未来 AI 硬件的挑战与方向 |

### Transformer 架构

| 论文 | 会议/期刊 | 年份 | 说明 |
|------|----------|------|------|
| Vaswani et al., "Attention Is All You Need" | NeurIPS | 2017 | Transformer 架构的开创性论文，Babel NPU 的目标工作负载 |
| Su et al., "RoFormer: Enhanced Transformer with Rotary Position Embedding" | Neurocomputing | 2024 | RoPE 位置编码的原始论文，NPU 算子 M11 的理论基础 |
| Zhang et al., "Root Mean Square Layer Normalization" | NeurIPS | 2019 | RMSNorm 论文，NPU 算子 M11 的另一理论基础 |

### NPU/加速器架构

| 论文 | 会议/期刊 | 年份 | 说明 |
|------|----------|------|------|
| Chen et al., "DaDianNao: A Machine-Learning Supercomputer" | MICRO | 2014 | 面向大规模神经网络的加速器 |
| Du et al., "ShiDianNao: Shifting Vision Processing Closer to the Sensor" | ISCA | 2015 | 边缘端 AI 加速器设计 |
| Liu et al., "Cambricon: An Instruction-Set Architecture for Neural Networks" | ISCA | 2016 | 神经网络指令集架构的系统性研究 |
| Shao et al., "Avenir: Understanding and Predicting the Co-evolution of DNN Models and Hardware Accelerators" | ISCA | 2024 | DNN 与硬件协同演化的最新研究 |

### 开源硬件项目

| 项目 | 说明 | 链接 |
|------|------|------|
| **OpenPiton** | Princeton 开源多核处理器平台 | [github.com/PrincetonUniversity/openpiton](https://github.com/PrincetonUniversity/openpiton) |
| **VeeR (RISC-V)** | CHIPS Alliance 开源 RISC-V 处理器核 | [github.com/chipsalliance/Cores-VeeR-EL2](https://github.com/chipsalliance/Cores-VeeR-EL2) |
| **PULP Platform** | ETH Zurich 并行超低功耗计算平台 | [pulp-platform.org](https://pulp-platform.org/) |
| **CVA6 (Ariane)** | ETH Zurich 开源 64-bit RISC-V 处理器 | [github.com/openhwgroup/cva6](https://github.com/openhwgroup/cva6) |

---

## 16.4 AI Coding Agent 资源

### Claude Code 文档

| 资源 | 链接 | 说明 |
|------|------|------|
| Claude Code 官方文档 | [docs.anthropic.com/claude-code](https://docs.anthropic.com/claude-code) | 安装、配置、使用指南 |
| Claude Code 最佳实践 | [docs.anthropic.com (best-practices)](https://docs.anthropic.com/claude/docs/claude-code-best-practices) | 高效与 AI Agent 协作的方法 |
| Prompt Engineering 指南 | [docs.anthropic.com (prompt-engineering)](https://docs.anthropic.com/claude/docs/prompt-engineering) | 提升 Agent 输出质量的 prompt 设计技巧 |

### Agentic Coding 方法论

| 资源 | 作者/来源 | 说明 |
|------|----------|------|
| "Vibe Coding" | Andrej Karpathy | 提出"氛围编程"概念，强调与 AI 的自然交互方式 |
| "How to Use AI to Write Code" | Andrej Karpathy | AI 辅助编程的经验分享 |
| 《AI-Assisted Programming》 | Tom Taulli (O'Reilly) | AI 辅助编程工具、方法和最佳实践的系统介绍 |

### 相关工具

| 工具 | 链接 | 说明 |
|------|------|------|
| **Cursor** | [cursor.sh](https://cursor.sh/) | AI-native IDE，深度集成 Claude 和 GPT |
| **GitHub Copilot** | [github.com/features/copilot](https://github.com/features/copilot) | GitHub 官方 AI 编程助手 |
| **Continue** | [continue.dev](https://continue.dev/) | 开源 AI 编程助手，支持自定义模型 |
| **llama2.c** | [github.com/karpathy/llama2.c](https://github.com/karpathy/llama2.c) | C 语言 LLM 推理实现，Babel NPU 的参考模型 |

---

## 16.5 Babel 项目内部文档索引

### 项目根目录

| 文件/目录 | 说明 |
|----------|------|
| `README.md` | 项目概述、安装指南、快速开始 |
| `CLAUDE.md` | Claude Code 的项目级指令配置 |
| `CONTRIBUTING.md` | 代码规范、PR 流程、review 标准 |

### 规范文档（spec/）

| 路径 | 说明 |
|------|------|
| `spec/PRD/PRD.md` | NPU 产品需求文档，包含 ~40 条 REQ 编号的需求 |
| `spec/ARCH/chip_overview.md` | 芯片总体概述，Key Features 表 |
| `spec/ARCH/block_diagram.md` | 模块框图（17 个模块的互联关系） |
| `spec/ARCH/io_pinout.md` | IO 引脚定义 |
| `spec/ARCH/memory_map.md` | 地址空间映射 |
| `spec/ARCH/clock_reset_spec.md` | 时钟与复位规划 |
| `spec/MAS/module_tree.md` | 模块层次树（M00-M16 及依赖关系） |
| `spec/MAS/plan.md` | MAS 实现计划（Phase 1-5、验证里程碑） |

### 技术文档（doc/）

| 路径 | 说明 |
|------|------|
| `doc/operators/README.md` | Transformer 算子详细文档（MatMul、Attention、RMSNorm 等） |
| `doc/isa/overview.md` | NPU 自定义指令集（32 条指令、寄存器文件、内存模型） |
| `doc/eda/open-source-eda-toolchain.md` | 开源 EDA 工具链概述 |
| `doc/eda/open-source-eda-user-guide.md` | 各 EDA 工具的使用指南和工作示例 |

### 设计与输出

| 路径 | 说明 |
|------|------|
| `rtl/designs/` | RTL 设计源码（NPU_top、tinystories_npu） |
| `designs/` | 设计输出（综合报告、GDSII 版图、PD 报告） |
| `libs/asap7/` | ASAP7 7nm PDK（标准单元库、LEF、Liberty 文件） |

### 知识库（wiki/）

| 路径 | 说明 |
|------|------|
| `wiki/cbb/` | Common Building Blocks——可复用的通用 RTL 模块 |
| `wiki/codingstyle/` | 编码规范文档 |
| `wiki/protocols/` | 协议文档（AXI、TileLink 等） |

### 教程（tutorial/）

| 文件 | 说明 |
|------|------|
| `outline.md` | 教程总提纲 |
| `ai-native-paradigm.md` | 第 1 章：AI 原生芯片设计范式 |
| `prerequisites.md` | 第 2 章：前置知识与环境准备 |
| `ai-research-learn.md` | 第 3 章：用 Claude Code 学习/研究/搜索 |
| `collaboration-patterns.md` | 第 4 章：人机协作模式 |
| `prd.md` | 第 5 章：用 AI 编写产品需求 |
| `architecture.md` | 第 6 章：Agent 驱动的架构设计 |
| `mas.md` | 第 7 章：Agent 生成微架构规范 |
| `rtl-generation.md` | 第 8 章：Agent 生成 RTL 代码 |
| `ai-verification.md` | 第 9 章：Agent 驱动的验证闭环 |
| `ai-synthesis.md` | 第 10 章：Agent 驱动的逻辑综合 |
| `ai-physical-design.md` | 第 11 章：Agent 驱动的物理设计 |
| `eda-toolchain-setup.md` | 第 12 章：用 Claude Code 搭建 EDA 工具链 |
| `hands-on-npu.md` | 第 13 章：实战——NPU 设计全流程走读 |
| `ai-debugging.md` | 第 14 章：与 AI 协同调试 |
| `glossary.md` | 第 15 章：术语表 |
| `references.md` | 第 16 章：延伸阅读与参考资料（本文件） |

---

## 16.6 社区与论坛

### 开源 EDA 社区

| 社区 | 链接 | 说明 |
|------|------|------|
| OpenROAD Slack | [openroad.slack.com](https://openroad.slack.com/) | OpenROAD 项目讨论社区，活跃度高 |
| Yosys Discord | [discord.gg/yosyshq](https://discord.gg/yosyshq) | Yosys 用户实时交流平台 |
| efabless Community | [community.efabless.com](https://community.efabless.com/) | 开源芯片设计社区，提供 MPW 流片机会 |

### 芯片设计社区

| 社区 | 链接 | 说明 |
|------|------|------|
| Reddit r/FPGA | [reddit.com/r/FPGA](https://www.reddit.com/r/FPGA/) | FPGA 开发者讨论社区 |
| Reddit r/ASIC | [reddit.com/r/ASIC](https://www.reddit.com/r/ASIC/) | ASIC 设计专业社区 |
| EEVblog Forum | [eevblog.com/forum](https://www.eevblog.com/forum/) | 电子工程综合论坛 |

### AI 硬件社区

| 社区 | 链接 | 说明 |
|------|------|------|
| TinyML | [tinyml.org](https://www.tinyml.org/) | 边缘 AI 和 TinyML 开发者社区 |
| MLPerf | [mlcommons.org](https://mlcommons.org/en/groups/mlperf/) | ML 性能基准测试组织 |

---

## 16.7 在线课程与教程

### 芯片设计课程

| 课程 | 学校 | 链接 | 说明 |
|------|------|------|------|
| MIT 6.375: Complex Digital Design | MIT | [csg.csail.mit.edu/6.375](https://csg.csail.mit.edu/6.375/) | 高级数字设计，使用 Bluespec 和 Verilog |
| Stanford EE183: Digital System Design | Stanford | [ee183.stanford.edu](https://ee183.stanford.edu/) | 数字系统设计入门 |
| UC Berkeley EECS151 | UC Berkeley | [inst.eecs.berkeley.edu/~eecs151](https://inst.eecs.berkeley.edu/~eecs151/) | 数字设计基础 |

### 验证方法学

| 课程 | 来源 | 链接 | 说明 |
|------|------|------|------|
| Verification Academy | Siemens EDA | [verificationacademy.com](https://verificationacademy.com/) | 免费 SV/UVM 验证课程 |
| Doulos UVM Tutorial | Doulos | [doulos.com/knowhow/systemverilog/uvm](https://www.doulos.com/knowhow/systemverilog/uvm/) | UVM 方法学系统教程 |

### AI 硬件课程

| 课程 | 学校 | 说明 |
|------|------|------|
| CS231n: Deep Learning for Computer Vision | Stanford | 深度学习基础，理解 NPU 目标工作负载 |
| TinyML Specialization | edX/Harvard | 边缘 AI 系列课程，模型压缩和硬件部署 |
| Hardware for Deep Learning (6.S965) | MIT | AI 硬件专题，加速器架构设计 |

---

建议根据当前学习阶段选择性阅读：

- **初学者**：从 16.2 的入门教材和 16.7 的在线课程开始，同时阅读教程 Part I
- **实践者**：重点阅读 16.1 的工具文档和 16.5 的项目内部文档，边做边学
- **研究者**：深入 16.3 的论文和 16.6 的社区讨论，探索前沿方向
