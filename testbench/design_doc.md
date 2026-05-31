# BabelBench: LLM 芯片设计能力评测框架

## 执行摘要

BabelBench 是一个标准化的 LLM benchmark 框架，用于评测大语言模型在端到端芯片设计 workflow 中的能力。基于 Babel 的 5 阶段流水线（Architect → RTL → Verification → Synthesis → Physical Design），BabelBench 通过 10 个标准化的设计问题，从 6 个维度（正确性、完整性、质量、效率、鲁棒性、成本效益）对比不同 LLM 的性能。

### 核心价值

1. **首个端到端芯片设计 benchmark**：覆盖从需求描述到 GDSII 的完整流程
2. **客观可量化的评分**：基于 EDA 工具链的自动化评估，无主观判断
3. **多难度层次**：10 个问题覆盖 Easy/Medium/Hard/Expert 四个级别
4. **生产级 harness**：支持实际运行，产出可复现的评测结果

### 技术栈

- **评测框架**：Python 3.11+ (harness 实现)
- **EDA 工具链**：Yosys 0.35, OpenSTA 2.2.0, Magic 8.3.641, Verilator (latest)
- **工艺库**：ASAP7 7nm PDK
- **目标 LLM**：Claude Opus 4.7, Sonnet 4.6, GPT-4o, DeepSeek V3, Qwen Max
- **Agent 框架**：Babel bba-guru 系列 (architect/rtl/verification/synthesis/pd)

---

## 1. 问题定义与目标

### 1.1 核心目标

**G1: 建立标准化的 LLM 芯片设计评测体系**
- KPI: 10 个标准化问题，覆盖 4 个难度级别
- KPI: 每个问题有完整的 JSON 定义和参考实现
- KPI: 问题定义无歧义，可被不同 LLM 独立理解

**G2: 实现生产级评测 harness**
- KPI: 支持 5 个主流 LLM (Claude/GPT/DeepSeek/Qwen)
- KPI: 单次完整评测耗时 ≤ 4 小时 (Expert 问题除外)
- KPI: 评测结果可复现，相同 LLM 多次运行变异系数 < 5%

**G3: 定义多维度量化指标体系**
- KPI: 6 个一级指标维度 (Correctness/Completeness/Quality/Efficiency/Robustness/Cost-Effectiveness)
- KPI: 每个维度 3-5 个可计算子指标
- KPI: 综合评分公式可解释，权重可调

**G4: 产出可公开的比较报告**
- KPI: 生成可视化雷达图和排行榜
- KPI: 每个 LLM 的优劣势分析（定性+定量）
- KPI: 报告可导出为 Markdown/HTML/PDF

### 1.2 范围界定

**范围内 (In Scope)**：
- 10 个标准化设计问题的定义和参考实现
- Harness 框架的完整实现（adapter/executor/collector/reporter）
- 自动化评分系统（基于 EDA 工具链）
- 结果可视化和报告生成
- 评测结果数据库和排行榜

**范围外 (Out of Scope)**：
- LLM 模型的微调或训练
- Babel agent 的修改或优化
- EDA 工具链的定制开发
- 云端部署和 SaaS 服务
- 商业授权和盈利模式

### 1.3 约束条件

**技术约束**：
- 必须使用开源 EDA 工具链（Yosys/OpenSTA/Magic/Verilator）
- 必须基于 ASAP7 PDK（7nm 工艺）
- 必须兼容现有 Babel bba-guru agent 接口

**资源约束**：
- 单次评测 token 预算 ≤ 500K tokens/问题
- 单次评测时间预算 ≤ 4 小时/问题（Expert 除外）
- 评测环境需要 ≥ 16GB RAM, ≥ 8 CPU cores

**质量约束**：
- 所有评分必须可自动计算，无主观判断
- 所有问题必须有参考实现（known-good artifacts）
- 评测结果必须可复现（temperature=0, fixed seed）

---

## 2. 用户画像与场景

### 2.1 主要用户

**Persona 1: AI 芯片设计研究者**
- 目标：对比不同 LLM 在芯片设计任务上的能力
- 痛点：缺乏标准化评测方法，无法公平比较
- 使用场景：运行完整 benchmark，分析结果，发表论文

**Persona 2: LLM 厂商产品经理**
- 目标：评估自家模型在垂直领域（芯片设计）的表现
- 痛点：通用 benchmark 无法反映专业能力
- 使用场景：定期运行 benchmark，追踪模型迭代效果

**Persona 3: 芯片设计工程师**
- 目标：选择合适的 LLM 辅助设计工作
- 痛点：不知道哪个 LLM 最适合芯片设计任务
- 使用场景：查看排行榜，选择得分最高的 LLM

### 2.2 核心场景

**Scenario 1: 完整 Benchmark 运行**
1. 用户选择 1-3 个 LLM 模型
2. 用户选择难度级别（或全部 10 个问题）
3. Harness 自动运行所有问题，收集指标
4. 生成综合报告和可视化图表
5. 用户导出报告，分享或存档

**Scenario 2: 单问题调试**
1. 用户选择单个问题
2. Harness 运行该问题，实时显示进度
3. 用户可以查看每个阶段的中间产物
4. 用户可以对比不同 LLM 在同一问题上的表现

**Scenario 3: 历史趋势分析**
1. 用户选择某个 LLM 的多个版本
2. Harness 从数据库加载历史结果
3. 生成时间序列图，展示性能变化趋势
4. 用户分析模型迭代的效果

---

## 3. 功能需求

### 3.1 Epic 列表

**E1: 标准化问题集管理**
- F1.1: 问题定义（JSON schema）
- F1.2: 问题验证（schema validation）
- F1.3: 参考实现管理（known-good artifacts）
- F1.4: 难度分级（Easy/Medium/Hard/Expert）
- F1.5: 问题版本控制

**E2: LLM Adapter 层**
- F2.1: 多 LLM 提供商支持（Anthropic/OpenAI/DeepSeek/Qwen）
- F2.2: 统一 API 封装
- F2.3: Token 计数和成本追踪
- F2.4: 请求重试和错误处理
- F2.5: 并发控制（rate limiting）

**E3: Stage Executor**
- F3.1: 5 阶段流水线执行（Architect → RTL → Verification → Synthesis → PD）
- F3.2: 阶段间数据传递（artifact handoff）
- F3.3: 阶段超时控制
- F3.4: 阶段失败处理（retry/escalate）
- F3.5: 执行轨迹记录（trajectory logging）

**E4: Metric Collector**
- F4.1: Schema 校验（JSON schema validation）
- F4.2: Lint 检查（verible-verilog-lint）
- F4.3: 覆盖率收集（verilator --coverage）
- F4.4: 时序分析（OpenSTA）
- F4.5: DRC/LVS 检查（Magic/Netgen）
- F4.6: 成本统计（token usage + API cost）
- F4.7: 时间统计（wall clock time per stage）

**E5: Sandbox 管理**
- F5.1: 沙箱创建（clean worktree）
- F5.2: 沙箱隔离（文件系统隔离）
- F5.3: 沙箱清理（artifact archival）
- F5.4: 沙箱快照（checkpoint/restore）
- F5.5: 并行沙箱（多 LLM 并发评测）

**E6: 评分系统**
- F6.1: 子指标计算（normalize to [0, 1]）
- F6.2: 维度聚合（6 个一级维度）
- F6.3: 综合评分（weighted average）
- F6.4: 评分解释（feature importance）
- F6.5: 评分对比（LLM vs LLM）

**E7: 报告生成**
- F7.1: 雷达图（6 维度可视化）
- F7.2: 排行榜（综合评分排序）
- F7.3: 详细报告（每个问题的 breakdown）
- F7.4: 趋势图（历史对比）
- F7.5: 报告导出（Markdown/HTML/PDF）

**E8: 结果数据库**
- F8.1: 结果存储（SQLite/PostgreSQL）
- F8.2: 结果查询（filter/sort/aggregate）
- F8.3: 结果备份（JSON export）
- F8.4: 结果清理（retention policy）

**E9: CLI 和 API**
- F9.1: CLI 工具（babel-bench run/report/compare）
- F9.2: Python API（programmable interface）
- F9.3: 配置文件（YAML/JSON）
- F9.4: 日志系统（structured logging）

**E10: 文档和示例**
- F10.1: 用户手册（installation/usage）
- F10.2: 开发者文档（architecture/extension）
- F10.3: 示例脚本（quick start）
- F10.4: FAQ 和 troubleshooting

### 3.2 功能优先级

**Must Have (P0)**：
- E1: 标准化问题集管理（10 个问题）
- E2: LLM Adapter 层（至少 3 个 LLM）
- E3: Stage Executor（5 阶段流水线）
- E4: Metric Collector（核心指标）
- E6: 评分系统（6 维度）
- E7: 报告生成（雷达图+排行榜）
- E9: CLI 工具（基本命令）

**Should Have (P1)**：
- E5: Sandbox 管理（隔离和清理）
- E8: 结果数据库（SQLite）
- E10: 文档和示例（用户手册）

**Could Have (P2)**：
- E2: 扩展到 5 个 LLM
- E5: 并行沙箱
- E7: 趋势图
- E9: Python API

**Won't Have (P3)**：
- E5: 沙箱快照
- E7: PDF 导出
- E8: PostgreSQL
- E9: REST API

---

## 4. 非功能需求

### 4.1 性能需求

**NFR1: 评测耗时**
- 单个 Easy 问题：≤ 30 分钟
- 单个 Medium 问题：≤ 60 分钟
- 单个 Hard 问题：≤ 120 分钟
- 单个 Expert 问题：≤ 240 分钟
- 完整 benchmark (10 问题, 3 LLM)：≤ 24 小时

**NFR2: 资源消耗**
- 内存：≤ 16GB per sandbox
- CPU：≤ 8 cores per sandbox
- 磁盘：≤ 10GB per sandbox
- 网络：≤ 100MB per LLM call

**NFR3: 并发能力**
- 支持 3 个 LLM 并发评测
- 支持 5 个问题并发运行（同一 LLM）
- 总并发 sandbox 数：≤ 15

### 4.2 可靠性需求

**NFR4: 成功率**
- Harness 自身故障率：< 1%（排除 LLM/EDA 工具问题）
- 评测结果可复现率：> 95%（相同 LLM 多次运行）
- 数据持久化成功率：100%

**NFR5: 容错能力**
- LLM API 失败：自动重试 3 次，间隔指数退避
- EDA 工具崩溃：记录错误，跳过当前问题，继续下一个
- 磁盘空间不足：提前检测，中止评测，保存进度

**NFR6: 数据完整性**
- 所有中间产物必须保存到磁盘
- 所有评分必须有详细的计算过程
- 所有异常必须有完整的 stack trace

### 4.3 可维护性需求

**NFR7: 代码质量**
- 测试覆盖率：≥ 80%
- 代码复杂度：Cyclomatic complexity ≤ 10 per function
- 代码风格：PEP 8 (Python), ESLint (JavaScript)

**NFR8: 扩展性**
- 新增 LLM 提供商：≤ 1 天工作量
- 新增问题：≤ 1 小时工作量
- 新增指标：≤ 2 小时工作量

**NFR9: 文档质量**
- 用户手册：覆盖所有 CLI 命令和 API
- 开发者文档：覆盖架构设计和扩展点
- 代码注释：所有 public function 有 docstring

### 4.4 安全性需求

**NFR10: API Key 管理**
- API key 必须从环境变量读取，禁止硬编码
- API key 必须加密存储（如果持久化）
- API key 必须定期轮换

**NFR11: 沙箱隔离**
- 每个 sandbox 必须在独立目录
- Sandbox 之间禁止文件系统访问
- Sandbox 清理必须彻底（包括临时文件）

**NFR12: 数据隐私**
- 评测结果禁止包含敏感信息（API key, internal data）
- 公开报告必须脱敏（移除内部路径、用户信息）

---

## 5. 标准化问题定义：完整 AI SoC

### 5.1 问题概述

**问题 ID**: `complete_ai_soc_v1`
**难度**: Expert
**预估人工时间**: 400 小时

### 5.2 Design Idea

```
设计一个面向边缘AI推理的完整SoC芯片。

核心需求：
1. **NPU子系统**：16个NPU核心，每个核心支持Transformer推理（Attention、MatMul、RMSNorm、RoPE），支持INT8/FP16混合精度，算力目标16 TOPS
2. **CPU子系统**：4个RISC-V RV64GC核心，用于系统控制、任务调度、外设管理，支持Linux
3. **IP复用**：复用开源DRAM控制器（支持DDR4/LPDDR4）、PCIe Gen3 x4控制器、JTAG调试接口
4. **SoC集成**：2D Mesh NoC互联（4x4网格）、分层缓存（每NPU核心64KB L1、共享8MB L2）、多时钟域（NPU 1GHz、CPU 1.5GHz、NoC 800MHz）、完整CDC处理
5. **指令集实现**：自定义NPU ISA（32条指令），包含矩阵运算、向量运算、数据搬运、同步原语，提供ISA解码器和合规测试套件
6. **外设接口**：DDR4控制器（32-bit, 2400MT/s）、PCIe Gen3 x4、JTAG、UART、SPI、GPIO
7. **电源管理**：DVFS（4个电压域）、时钟门控、电源门控（NPU核心可独立关断）
8. **安全启动**：Secure Boot ROM、密钥管理、固件签名验证

工艺约束：ASAP7 7nm PDK，目标频率1GHz（NPU）/1.5GHz（CPU），面积≤50mm²，功耗≤15W
```

### 5.3 设计约束

```json
{
  "technology": "asap7",
  "process_node": "7nm",
  "clock_frequencies": {
    "npu_core_mhz": 1000,
    "cpu_core_mhz": 1500,
    "noc_mhz": 800,
    "dram_mhz": 1200,
    "pcie_mhz": 250
  },
  "area_budget_mm2": 50,
  "power_budget_w": 15,
  "voltage_domains": ["VDD_NPU", "VDD_CPU", "VDD_NOC", "VDD_IO"],
  "clock_domains": ["clk_npu", "clk_cpu", "clk_noc", "clk_dram", "clk_pcie", "clk_jtag"],
  "performance_targets": {
    "npu_tops": 16,
    "cpu_dhrystone_dmips": 8000,
    "memory_bandwidth_gbs": 20,
    "pcie_bandwidth_gbs": 4
  }
}
```

### 5.4 预期模块层次结构

```json
{
  "npu_subsystem": [
    "NPU_Core_Top (x16)",
    "Attention_Unit",
    "MatMul_Engine",
    "RMSNorm_Unit",
    "RoPE_Unit",
    "Vector_Processor",
    "NPU_L1_Cache (x16)",
    "NPU_ISA_Decoder (x16)",
    "NPU_Register_File (x16)"
  ],
  "cpu_subsystem": [
    "RISC_V_Core_RV64GC (x4)",
    "CPU_L1_ICache (x4)",
    "CPU_L1_DCache (x4)",
    "MMU (x4)",
    "Interrupt_Controller",
    "Timer_Unit"
  ],
  "memory_subsystem": [
    "Shared_L2_Cache_8MB",
    "L2_Cache_Controller",
    "DRAM_Controller_DDR4",
    "Memory_Phy_Interface"
  ],
  "interconnect": [
    "NoC_Router_2D_Mesh (x16)",
    "NoC_Network_Interface (x20)",
    "AXI4_Bridge",
    "Clock_Domain_Crossing_Hub"
  ],
  "io_subsystem": [
    "PCIe_Gen3_x4_Controller",
    "PCIe_Phy_Interface",
    "JTAG_Controller",
    "UART_Controller (x2)",
    "SPI_Controller",
    "GPIO_Controller"
  ],
  "power_management": [
    "DVFS_Controller",
    "Clock_Gating_Unit",
    "Power_Gating_Controller",
    "PMU_Power_Management_Unit"
  ],
  "security": [
    "Secure_Boot_ROM",
    "Key_Management_Unit",
    "Crypto_Accelerator",
    "Secure_Debug_Controller"
  ],
  "system": [
    "Reset_Controller",
    "Clock_Generator_PLL (x4)",
    "Debug_Module",
    "System_Top"
  ]
}
```

**预期模块总数**: 25-35 个模块

### 5.5 预期接口定义

```json
{
  "external_interfaces": [
    "DDR4_32bit_2400MTs",
    "PCIe_Gen3_x4",
    "JTAG_IEEE1149_1",
    "UART_115200bps (x2)",
    "SPI_50MHz",
    "GPIO_32bit"
  ],
  "internal_interfaces": [
    "AXI4_Master (x20)",
    "AXI4_Slave (x15)",
    "AXI4_Lite (x10)",
    "NoC_Link_Layer (x80)",
    "CDC_Synchronizer (x200+)"
  ]
}
```

### 5.6 预期测试场景

```json
{
  "npu_functional": [
    "矩阵乘法正确性（INT8/FP16）",
    "Attention机制端到端验证",
    "RMSNorm精度验证",
    "RoPE位置编码正确性",
    "NPU指令集全覆盖测试（32条指令）"
  ],
  "cpu_functional": [
    "RISC-V RV64GC指令集合规测试",
    "中断处理正确性",
    "MMU页表遍历",
    "Cache一致性验证",
    "Linux启动测试（可选）"
  ],
  "memory_subsystem": [
    "L1/L2 Cache命中率测试",
    "Cache一致性协议验证",
    "DRAM读写带宽测试",
    "ECC纠错功能验证"
  ],
  "interconnect": [
    "NoC路由正确性（全连接测试）",
    "NoC死锁自由验证",
    "NoC带宽利用率测试",
    "CDC路径时序验证"
  ],
  "io_interfaces": [
    "DDR4训练和校准",
    "PCIe链路训练和TLP传输",
    "JTAG调试功能",
    "UART/SPI/GPIO基本功能"
  ],
  "power_management": [
    "DVFS频率切换",
    "电源门控开关序列",
    "时钟门控有效性",
    "功耗估算准确性"
  ],
  "security": [
    "Secure Boot流程验证",
    "固件签名验证",
    "密钥存储和访问控制",
    "安全调试锁定/解锁"
  ]
}
```

**预期测试场景总数**: 30+ 个测试场景

### 5.7 设计覆盖能力

该单一问题覆盖以下芯片设计核心能力：

| 能力维度 | 覆盖内容 | 复杂度 |
|---------|---------|--------|
| **IP设计** | NPU核心（Attention/MatMul/RMSNorm/RoPE）、RISC-V CPU核心 | 极高 |
| **IP复用** | DRAM控制器、PCIe控制器、JTAG接口 | 中等 |
| **SoC集成** | NoC互联、分层缓存、多时钟域CDC、电源管理 | 极高 |
| **指令集实现** | 自定义NPU ISA（32条指令）、ISA解码器、合规测试 | 高 |
| **系统级设计** | 安全启动、调试系统、复位/时钟管理 | 高 |

### 5.8 问题定义文件

完整问题定义：`testbench/problems/complete_ai_soc_v1.json`

## 6. 量化指标体系

### 6.1 指标层次结构

```
Level 1: 一级维度 (6 个)
  ├── Correctness (正确性)
  ├── Completeness (完整性)
  ├── Quality (质量)
  ├── Efficiency (效率)
  ├── Robustness (鲁棒性)
  └── Cost-Effectiveness (成本效益)

Level 2: 二级指标 (每个维度 3-5 个)

Level 3: 三级指标 (原始测量值)
```

### 6.2 Correctness (正确性) 维度

**定义**：LLM 生成的设计是否通过所有 quality gates

**二级指标**：

| 指标 ID | 指标名称 | 计算方式 | 权重 |
|---------|---------|---------|------|
| C1 | Pipeline Success Rate (PSR) | pass@1 = 成功次数 / 总次数 | 0.30 |
| C2 | Stage Gate Pass Rate | 通过的 stage gates / 总 stage gates | 0.25 |
| C3 | Schema Validity | 通过 schema validation 的 artifacts / 总 artifacts | 0.15 |
| C4 | Lint Clean Rate | lint-clean 的 RTL 文件 / 总 RTL 文件 | 0.15 |
| C5 | DRC/LVS Clean Rate | DRC/LVS clean 的设计 / 总设计 | 0.15 |

**计算公式**：
```
Correctness = 0.30 * C1 + 0.25 * C2 + 0.15 * C3 + 0.15 * C4 + 0.15 * C5
```

**归一化**：
- C1: 直接取值 [0, 1]
- C2: 直接取值 [0, 1]
- C3: 直接取值 [0, 1]
- C4: 直接取值 [0, 1]
- C5: 直接取值 [0, 1]

---

### 6.3 Completeness (完整性) 维度

**定义**：LLM 生成的设计是否覆盖了所有预期的模块和功能

**二级指标**：

| 指标 ID | 指标名称 | 计算方式 | 权重 |
|---------|---------|---------|------|
| CP1 | Highest Completed Stage (HCS) | 最远到达的阶段 (1-5) / 5 | 0.30 |
| CP2 | Module Coverage | 生成的模块数 / 预期模块数 | 0.25 |
| CP3 | IO Coverage | 定义的 IO 数 / 预期 IO 数 | 0.20 |
| CP4 | Clock Domain Coverage | 定义的时钟域数 / 预期时钟域数 | 0.15 |
| CP5 | Feature Coverage | 实现的功能数 / 预期功能数 | 0.10 |

**计算公式**：
```
Completeness = 0.30 * CP1 + 0.25 * CP2 + 0.20 * CP3 + 0.15 * CP4 + 0.10 * CP5
```

**归一化**：
- CP1: HCS / 5，取值 [0, 1]
- CP2: min(1, actual / expected)
- CP3: min(1, actual / expected)
- CP4: min(1, actual / expected)
- CP5: min(1, actual / expected)

---

### 6.4 Quality (质量) 维度

**定义**：LLM 生成的设计的 PPA（Power, Performance, Area）质量

**二级指标**：

| 指标 ID | 指标名称 | 计算方式 | 权重 |
|---------|---------|---------|------|
| Q1 | Timing Closure | WNS ≥ 0 ? 1 : max(0, 1 + WNS/10) | 0.30 |
| Q2 | Area Efficiency | min(1, budget_area / actual_area) | 0.25 |
| Q3 | Power Efficiency | min(1, budget_power / actual_power) | 0.25 |
| Q4 | Lint Warning Count | 1 / (1 + warning_count) | 0.10 |
| Q5 | DRC Violation Count | 1 / (1 + drc_count) | 0.10 |

**计算公式**：
```
Quality = 0.30 * Q1 + 0.25 * Q2 + 0.25 * Q3 + 0.10 * Q4 + 0.10 * Q5
```

**归一化**：
- Q1: 如果 WNS ≥ 0，取值 1；否则取值 max(0, 1 + WNS/10)
- Q2: min(1, budget / actual)
- Q3: min(1, budget / actual)
- Q4: 1 / (1 + count)
- Q5: 1 / (1 + count)

---

### 6.5 Efficiency (效率) 维度

**定义**：LLM 完成任务的效率（token 使用、tool call 效率、修复迭代）

**二级指标**：

| 指标 ID | 指标名称 | 计算方式 | 权重 |
|---------|---------|---------|------|
| E1 | Token Efficiency | 1 / (1 + total_tokens / 100K) | 0.30 |
| E2 | Tool Call Efficiency | successful_calls / total_calls | 0.25 |
| E3 | Fix Iteration Count | 1 / (1 + avg_fix_iter) | 0.25 |
| E4 | Hallucination Rate | 1 - (invalid_operations / total_operations) | 0.20 |

**计算公式**：
```
Efficiency = 0.30 * E1 + 0.25 * E2 + 0.25 * E3 + 0.20 * E4
```

**归一化**：
- E1: 1 / (1 + tokens / 100K)
- E2: 直接取值 [0, 1]
- E3: 1 / (1 + count)
- E4: 1 - rate，取值 [0, 1]

---

### 6.6 Robustness (鲁棒性) 维度

**定义**：LLM 处理错误和恢复的能力

**二级指标**：

| 指标 ID | 指标名称 | 计算方式 | 权重 |
|---------|---------|---------|------|
| R1 | Fix Success Rate | successful_fixes / total_fix_attempts | 0.40 |
| R2 | Escalation Rate | 1 - (escalations / total_attempts) | 0.30 |
| R3 | Error Recovery Rate | recovered_errors / total_errors | 0.30 |

**计算公式**：
```
Robustness = 0.40 * R1 + 0.30 * R2 + 0.30 * R3
```

**归一化**：
- R1: 直接取值 [0, 1]
- R2: 1 - rate，取值 [0, 1]
- R3: 直接取值 [0, 1]

---

### 6.7 Cost-Effectiveness (成本效益) 维度

**定义**：LLM 完成任务的成本效益

**二级指标**：

| 指标 ID | 指标名称 | 计算方式 | 权重 |
|---------|---------|---------|------|
| CE1 | Cost per Successful Pipeline | 1 / (1 + cost_usd) | 0.40 |
| CE2 | Token per Stage | 1 / (1 + tokens / 50K) | 0.30 |
| CE3 | Time per Stage | 1 / (1 + time_min / 30) | 0.30 |

**计算公式**：
```
Cost-Effectiveness = 0.40 * CE1 + 0.30 * CE2 + 0.30 * CE3
```

**归一化**：
- CE1: 1 / (1 + cost)
- CE2: 1 / (1 + tokens / 50K)
- CE3: 1 / (1 + time / 30)

---

### 6.8 综合评分公式

**BabelBench Score**：
```
Score = Σ(dimension_weight × dimension_score)

其中：
  dimension_weight = {
    "Correctness": 0.25,
    "Completeness": 0.20,
    "Quality": 0.20,
    "Efficiency": 0.15,
    "Robustness": 0.10,
    "Cost-Effectiveness": 0.10
  }
```

**默认权重解释**：
- Correctness (0.25)：最重要，设计必须正确
- Completeness (0.20)：次重要，设计必须完整
- Quality (0.20)：PPA 质量很重要
- Efficiency (0.15)：效率影响成本
- Robustness (0.10)：鲁棒性影响可用性
- Cost-Effectiveness (0.10)：成本效益影响商业价值

**权重可调**：用户可以通过配置文件调整权重，适应不同的评测目标。

### 6.9 流程阶段评分（Stage-Based Scoring）

除了维度评分外，BabelBench 还提供基于流程阶段的评分，用于诊断 LLM 在哪个阶段表现优异或失败。

#### 6.9.1 阶段定义

```
Stage 1: Architecture Design (Arch/Spec)
  - 输出：PRD (Product Requirements Document)
  - 输出：ARCH (Architecture Specification)
  - 输出：MAS (Micro-Architecture Specification)
  - Quality Gate：MAS schema 验证通过

Stage 2: RTL Coding
  - 输出：SystemVerilog RTL 代码
  - 输出：Lint 报告
  - Quality Gate：Lint clean（零错误、零警告）

Stage 3: Verification
  - 输出：Testbench 代码
  - 输出：覆盖率报告（line/branch/toggle/functional）
  - 输出：仿真日志
  - Quality Gate：功能覆盖率 100%、代码覆盖率 100%

Stage 4: Synthesis
  - 输出：综合网表
  - 输出：时序报告（WNS/TNS）
  - 输出：面积和功耗报告
  - Quality Gate：WNS ≥ 0（时序收敛）

Stage 5: Physical Design (PD)
  - 输出：GDSII 版图
  - 输出：DRC 报告
  - 输出：LVS 报告
  - Quality Gate：DRC clean、LVS clean
```

#### 6.9.2 阶段评分指标

| 阶段 | 指标 ID | 指标名称 | 计算方式 | 权重 |
|------|---------|---------|---------|------|
| **Arch/Spec** | S1.1 | Schema Validity | MAS 通过 schema 验证 ? 1 : 0 | 0.40 |
| | S1.2 | Requirement Coverage | 实现的需求数 / 预期需求数 | 0.30 |
| | S1.3 | Module Definition Quality | 模块定义完整性评分 (0-1) | 0.30 |
| **RTL Coding** | S2.1 | Lint Clean | 零错误零警告 ? 1 : max(0, 1 - violations/100) | 0.40 |
| | S2.2 | Port Match | 实际端口数 / 预期端口数 | 0.30 |
| | S2.3 | Code Style | 编码规范符合度 (0-1) | 0.30 |
| **Verification** | S3.1 | Functional Coverage | 功能覆盖率 (%) / 100 | 0.35 |
| | S3.2 | Code Coverage | 代码覆盖率 (%) / 100 | 0.30 |
| | S3.3 | Test Pass Rate | 通过的测试数 / 总测试数 | 0.35 |
| **Synthesis** | S4.1 | Timing Closure | WNS ≥ 0 ? 1 : max(0, 1 + WNS/10) | 0.40 |
| | S4.2 | Area Efficiency | min(1, budget_area / actual_area) | 0.30 |
| | S4.3 | Power Efficiency | min(1, budget_power / actual_power) | 0.30 |
| **PD** | S5.1 | DRC Clean | DRC 零违规 ? 1 : max(0, 1 - violations/1000) | 0.40 |
| | S5.2 | LVS Clean | LVS 匹配 ? 1 : 0 | 0.35 |
| | S5.3 | Routing Completion | 布线完成率 (%) / 100 | 0.25 |

#### 6.9.3 阶段评分计算公式

```
Stage_Score[i] = Σ(metric_weight × metric_score)  # i = 1..5

Overall_Stage_Score = (S1 + S2 + S3 + S4 + S5) / 5
```

#### 6.9.4 阶段诊断报告

BabelBench 会生成阶段诊断报告，显示 LLM 在每个阶段的表现：

```
LLM: Claude Sonnet 4.6
Problem: complete_ai_soc_v1

Stage Performance:
  Stage 1 (Arch/Spec):    0.92 ████████████████████  (通过)
  Stage 2 (RTL Coding):   0.87 ██████████████████    (通过)
  Stage 3 (Verification): 0.75 ███████████████       (通过)
  Stage 4 (Synthesis):    0.68 █████████████         (失败 - 时序未收敛)
  Stage 5 (PD):           0.00                       (未执行)

Diagnosis:
  - LLM 在 RTL 和 Verification 阶段表现良好
  - Synthesis 阶段失败：WNS = -0.35ns，需要优化关键路径
  - 建议：检查时钟约束和组合逻辑深度
```

#### 6.9.5 阶段对比分析

对比不同 LLM 在同一问题上的阶段表现：

```
Problem: complete_ai_soc_v1

LLM Comparison by Stage:
                    Arch   RTL    Verif  Synth  PD     Overall
Claude Sonnet 4.6:  0.92   0.87   0.75   0.68   0.00   0.64
GPT-4o:             0.88   0.82   0.70   0.72   0.65   0.75
DeepSeek V3:        0.85   0.78   0.68   0.60   0.00   0.58

Insights:
  - GPT-4o 在 Synthesis 和 PD 阶段表现最好
  - Claude Sonnet 4.6 在 Arch 和 RTL 阶段表现最好
  - DeepSeek V3 需要改进 Verification 阶段
```

---

## 7. Harness 架构设计

### 7.1 总体架构（简化版）

**设计原则**：
- 问题定义为静态 JSON 文件，无需 Problem Set Manager
- 用户手动切换 LLM 运行 Babel workflow，无需 LLM Adapter
- Harness 聚焦于结果收集、指标计算和对比分析

```
┌─────────────────────────────────────────────────────────────┐
│                    BabelBench Harness（简化版）              │
│                                                             │
│  ┌──────────┐                                              │
│  │ Problem  │  (静态 JSON 文件，无需 Manager)              │
│  │ Files    │                                              │
│  │ (10 Qs)  │                                              │
│  └──────────┘                                              │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────────────────────────────────────────┐          │
│  │ 用户手动运行 Babel Workflow（手工切换 LLM）  │          │
│  │  - Claude Opus 4.7                           │          │
│  │  - Claude Sonnet 4.6                         │          │
│  │  - GPT-4o                                    │          │
│  │  - DeepSeek V3                               │          │
│  │  - Qwen Max                                  │          │
│  └──────────────────────────────────────────────┘          │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Result   │───►│ Metric   │───►│ Scoring  │              │
│  │ Collector│    │ Collector│    │ System   │              │
│  │ (解析产物)│   │ (EDA 指标)│   │ (6 维度) │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                        │                     │
│                                        ▼                     │
│                                 ┌──────────┐                │
│                                 │ Report   │                │
│                                 │ Generator│                │
│                                 │ (对比分析)│               │
│                                 └──────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 核心组件（简化版）

**说明**：移除了 Problem Set Manager 和 LLM Adapter，因为：
- 问题定义为静态 JSON 文件（`testbench/problems/*.json`），直接读取即可
- 用户手动切换 LLM 运行 Babel workflow，无需 API 抽象层

---

#### 7.2.1 Result Collector

**职责**：解析用户手动运行 Babel workflow 后产生的结果文件

**工作流程**：
1. 用户手动使用某个 LLM（如 Claude Sonnet 4.6）运行 Babel workflow
2. 用户将结果文件放到指定目录（如 `results/claude_sonnet_46/problem_001/`）
3. Result Collector 自动解析结果文件，提取关键信息

**接口**：
```python
class ResultCollector:
    def __init__(self, results_dir: str):
        """初始化结果收集器"""
        pass
    
    def collect_result(self, llm_name: str, problem_id: str) -> PipelineResult:
        """收集单个 LLM 运行单个问题的结果"""
        pass
    
    def list_results(self, llm_name: str = None) -> List[PipelineResult]:
        """列出所有结果（可按 LLM 过滤）"""
        pass
    
    def validate_result(self, result: PipelineResult) -> bool:
        """验证结果文件是否完整"""
        pass
```

**数据结构**：
```python
@dataclass
class StageResult:
    stage: str  # architect/rtl/verification/synthesis/pd
    success: bool
    artifacts: Dict[str, str]  # 生成的文件路径
    metrics: Dict[str, float]  # 原始指标
    wall_time_sec: float  # 用户手动记录的时间（可选）
    error_message: str = None

@dataclass
class PipelineResult:
    problem_id: str
    llm_model: str  # 用户手动填写（如 "claude_sonnet_46"）
    stages: Dict[str, StageResult]
    highest_completed_stage: str
    failure_stage: str = None
    failure_reason: str = None
    total_time_sec: float = None  # 可选
    timestamp: datetime
```

**结果目录结构**：
```
results/
├── claude_sonnet_46/
│   ├── problem_001_tinystories_npu/
│   │   ├── architect/
│   │   │   ├── mas.json
│   │   │   └── schema_validation.log
│   │   ├── rtl/
│   │   │   ├── *.sv
│   │   │   └── lint_report.json
│   │   ├── verification/
│   │   │   └── coverage_report.json
│   │   ├── synthesis/
│   │   │   └── timing_report.json
│   │   └── pd/
│   │       ├── drc_report.json
│   │       └── lvs_report.json
│   └── problem_002_dual_core_npu/
│       └── ...
├── gpt_4o/
│   └── problem_001_tinystories_npu/
│       └── ...
└── deepseek_v3/
    └── ...
```

---

#### 7.2.2 Metric Collector

**职责**：收集每个阶段的量化指标

**接口**：
```python
class MetricCollector:
    def __init__(self, sandbox: Sandbox):
        """初始化 metric collector"""
        pass
    
    def collect_schema_metrics(self, artifact_path: str) -> Dict[str, float]:
        """收集 schema validation 指标"""
        pass
    
    def collect_lint_metrics(self, rtl_dir: str) -> Dict[str, float]:
        """收集 lint 指标"""
        pass
    
    def collect_coverage_metrics(self, coverage_report: str) -> Dict[str, float]:
        """收集覆盖率指标"""
        pass
    
    def collect_timing_metrics(self, sta_report: str) -> Dict[str, float]:
        """收集时序指标"""
        pass
    
    def collect_pd_metrics(self, drc_report: str, lvs_report: str) -> Dict[str, float]:
        """收集 PD 指标"""
        pass
```

**指标收集流程**：
1. 每个阶段完成后，调用对应的 collector 方法
2. Collector 解析 EDA 工具的输出报告
3. 返回标准化的指标字典
4. 指标存储到结果数据库

---

#### 7.2.3 Report Generator

**职责**：生成评测报告

**接口**：
```python
class ReportGenerator:
    def __init__(self, results_db: ResultsDatabase):
        """初始化 report generator"""
        pass
    
    def generate_radar_chart(self, llm_models: List[str]) -> str:
        """生成雷达图"""
        pass
    
    def generate_leaderboard(self, difficulty: str = None) -> str:
        """生成排行榜"""
        pass
    
    def generate_detailed_report(self, llm_model: str, problem_id: str) -> str:
        """生成详细报告"""
        pass
    
    def export_markdown(self, report_id: str) -> str:
        """导出为 Markdown"""
        pass
    
    def export_html(self, report_id: str) -> str:
        """导出为 HTML"""
        pass
```

---

### 7.3 数据流（简化版）

```
1. 用户从 problems/ 目录选择问题定义（JSON 文件）
   ↓
2. 用户手动使用某个 LLM 运行 Babel workflow
   ↓
3. 用户将结果文件放到 results/<llm_name>/<problem_id>/ 目录
   ↓
4. Result Collector 解析结果文件，提取关键信息
   ↓
5. Metric Collector 解析 EDA 工具报告，收集指标
   ↓
6. Scoring System 计算 6 维度评分
   ↓
7. Report Generator 生成对比报告和可视化图表
```

---

## 8. 实施路线图（简化版）

**说明**：由于移除了 Problem Set Manager、LLM Adapter、Sandbox Manager 和 Stage Executor，实施路线图大幅简化，聚焦于结果收集、指标计算和报告生成。

### 8.1 Phase 1: 结果收集和指标计算 (Must Have)

**目标**：实现结果解析和自动化评分系统

**实施顺序**：
1. **Result Collector** - 无依赖，优先实现
   - 定义 PipelineResult 和 StageResult dataclass
   - 实现结果目录解析（results/<llm>/<problem>/）
   - 实现结果验证（检查必需文件是否存在）
   
2. **Metric Collector** - 依赖 Result Collector
   - 实现 schema validation scorer（解析 mas.json）
   - 实现 lint scorer（解析 verible lint 报告）
   - 实现 coverage scorer（解析 verilator coverage 报告）
   - 实现 timing scorer（解析 OpenSTA 报告）
   - 实现 DRC/LVS scorer（解析 Magic/Netgen 报告）

3. **Scoring System** - 依赖 Metric Collector
   - 实现子指标计算（normalize to [0, 1]）
   - 实现 6 维度聚合（Correctness/Completeness/Quality/Efficiency/Robustness/Cost-Effectiveness）
   - 实现综合评分（weighted average）
   - 支持权重配置（YAML 配置文件）

**关键依赖路径**：Result Collector → Metric Collector → Scoring System

---

### 8.2 Phase 2: 指标收集 (Must Have)

**目标**：实现自动化评分系统

**实施顺序**：
1. **Metric Collector** - 依赖 Stage Executor
   - 实现 schema validation scorer
   - 实现 lint scorer (verible)
   - 实现 coverage scorer (verilator)
   - 实现 timing scorer (OpenSTA)
   - 实现 DRC/LVS scorer (Magic/Netgen)

2. **Results Database** - 依赖 Metric Collector
   - 实现 SQLite 数据库 schema
   - 实现结果存储和查询
   - 实现结果导出

3. **Scoring System** - 依赖 Results Database
   - 实现子指标计算
   - 实现维度聚合
   - 实现综合评分

**关键依赖路径**：Result Collector → Metric Collector → Scoring System

---

### 8.3 Phase 3: 报告和 CLI (Must Have)

**目标**：实现用户界面和报告生成

**实施顺序**：
1. **Report Generator** - 依赖 Scoring System
   - 实现雷达图生成
   - 实现排行榜生成
   - 实现详细报告生成
   - 实现 Markdown/HTML 导出

2. **CLI Tool** - 依赖 Report Generator
   - 实现 `babel-bench collect` 命令（收集用户手动运行的结果）
   - 实现 `babel-bench score` 命令（计算评分）
   - 实现 `babel-bench report` 命令（生成报告）
   - 实现 `babel-bench compare` 命令（对比不同 LLM 的评分）

3. **Configuration** - 依赖 CLI Tool
   - 实现 YAML 配置文件解析
   - 实现权重自定义

**关键依赖路径**：Scoring System → Report Generator → CLI Tool

---

### 8.4 Phase 4: 扩展和优化 (Should Have)

**目标**：扩展功能和优化性能

**实施顺序**：
1. **Trend Analysis** - 实现历史趋势图（追踪同一 LLM 多次运行的变化）
2. **Python API** - 实现 programmable interface（允许用户脚本化调用 harness）
3. **Batch Processing** - 实现批量结果收集（一次性收集多个 LLM 的结果）

**并行实施可能性**：这 3 个模块可以并行实施，无互相依赖

---

### 8.5 Phase 5: 文档和测试 (Should Have)

**目标**：完善文档和测试

**实施顺序**：
1. **User Manual** - 用户手册
2. **Developer Documentation** - 开发者文档
3. **Unit Tests** - 单元测试（目标覆盖率 80%）
4. **Integration Tests** - 集成测试

**并行实施可能性**：文档和测试可以并行实施

---

## 9. 风险和缓解措施

### 9.1 技术风险

**Risk 1: LLM API 不稳定**
- 影响：评测失败或结果不完整
- 概率：中
- 缓解措施：
  - 实现自动重试（3 次，指数退避）
  - 实现请求队列和并发控制
  - 保存中间结果，支持断点续传

**Risk 2: EDA 工具崩溃**
- 影响：某些阶段无法完成
- 概率：低
- 缓解措施：
  - 捕获 EDA 工具异常，记录错误
  - 跳过当前问题，继续下一个
  - 提供详细的错误日志

**Risk 3: 评测时间过长**
- 影响：用户体验差
- 概率：中
- 缓解措施：
  - 实现并行评测（多 LLM 并发）
  - 实现进度条和实时日志
  - 支持断点续传

**Risk 4: 评分标准不公平**
- 影响：评测结果不可信
- 概率：低
- 缓解措施：
  - 所有评分必须可自动计算
  - 公开评分公式和权重
  - 提供评分解释（feature importance）

### 9.2 项目风险

**Risk 5: 问题定义有歧义**
- 影响：不同 LLM 理解不一致
- 概率：中
- 缓解措施：
  - 问题定义必须经过人工审查
  - 提供参考实现作为 ground truth
  - 实现问题验证（schema validation）

**Risk 6: 参考实现质量不高**
- 影响：评分基准不准确
- 概率：低
- 缓解措施：
  - 参考实现必须由经验丰富的工程师编写
  - 参考实现必须通过所有 quality gates
  - 定期更新参考实现

**Risk 7: 评测结果不可复现**
- 影响：评测结果不可信
- 概率：低
- 缓解措施：
  - 使用 temperature=0, fixed seed
  - 记录所有中间产物和日志
  - 实现沙箱快照（可选）

---

## 10. 成功标准

### 10.1 功能验收标准

**AC1: 10 个标准化问题**
- [ ] 10 个问题都有完整的 JSON 定义
- [ ] 10 个问题都通过 schema validation
- [ ] 10 个问题都有参考实现

**AC2: Result Collector**
- [ ] 可以正确解析 results/<llm>/<problem>/ 目录结构
- [ ] 可以正确提取各阶段的产物文件
- [ ] 可以验证结果文件的完整性

**AC3: Metric Collector**
- [ ] 所有指标都可以自动收集（schema/lint/coverage/timing/DRC/LVS）
- [ ] 指标计算正确（与手动计算一致）
- [ ] 指标存储到数据库

**AC4: Scoring System**
- [ ] 6 个维度的评分可以正确计算
- [ ] 综合评分可以正确计算
- [ ] 评分可解释（feature importance）
- [ ] 权重可以通过配置文件自定义

**AC5: Report Generator**
- [ ] 雷达图可以正确生成（6 维度可视化）
- [ ] 排行榜可以正确生成（综合评分排序）
- [ ] 详细报告可以正确生成（每个问题的 breakdown）
- [ ] 报告可以导出为 Markdown/HTML

**AC6: CLI Tool**
- [ ] `babel-bench collect` 命令可以正常收集结果
- [ ] `babel-bench score` 命令可以正常计算评分
- [ ] `babel-bench report` 命令可以正常生成报告
- [ ] `babel-bench compare` 命令可以正常对比不同 LLM

### 10.2 非功能验收标准

**AC7: 性能**
- [ ] 结果收集（collect）≤ 1 分钟/问题
- [ ] 评分计算（score）≤ 10 秒/问题
- [ ] 报告生成（report）≤ 30 秒/LLM

**AC8: 可靠性**
- [ ] Harness 自身故障率 < 1%（排除 EDA 工具问题）
- [ ] 评测结果可复现率 > 95%（相同结果多次评分）
- [ ] 数据持久化成功率 100%

**AC9: 可维护性**
- [ ] 测试覆盖率 ≥ 80%
- [ ] 代码复杂度 ≤ 10 per function
- [ ] 所有 public function 有 docstring

---

## 11. 附录

### 11.1 术语表

| 术语 | 定义 |
|------|------|
| **PSR** | Pipeline Success Rate，流水线成功率 |
| **HCS** | Highest Completed Stage，最远完成阶段 |
| **WNS** | Worst Negative Slack，最差负裕量 |
| **TNS** | Total Negative Slack，总负裕量 |
| **PPA** | Power, Performance, Area，功耗/性能/面积 |
| **CDC** | Clock Domain Crossing，跨时钟域 |
| **DRC** | Design Rule Check，设计规则检查 |
| **LVS** | Layout vs. Schematic，版图与原理图对比 |
| **pass@k** | k 次尝试中至少一次成功的概率 |

### 11.2 参考 benchmark

| Benchmark | 领域 | 关键特点 |
|-----------|------|---------|
| **SWE-bench** | 软件工程 | Issue → Patch，pass@k 指标 |
| **RTLLM** | RTL 生成 | 单步 NL → Verilog，三级评估 |
| **RTLBench** | RTL 生成 | 160 个设计案例，多维度评估 |
| **HAL Harness** | Agent 评测 | 通用框架，cost tracking，reproducibility |

### 11.3 参考实现

- **tinystories_npu**: `designs/tinystories_npu/` (Easy)
- **NPU_top**: `designs/NPU_top/` (Hard)

---

## 12. 变更记录

| 版本 | 日期 | 作者 | 变更内容 |
|------|------|------|---------|
| 1.0.0 | 2026-05-30 | BabelBench Team | 初始版本 |
