# BabelBench 执行摘要

## 一句话概述

BabelBench 是一个生产级的 LLM benchmark 框架，通过 1 个综合性复杂芯片设计问题（Expert 难度），评测 LLM 在端到端芯片设计 workflow（Architect → RTL → Verification → Synthesis → Physical Design）中的能力，产出可公开比较的排行榜。

---

## 核心价值

### 1. 首个端到端芯片设计 benchmark

**现状**：
- SWE-bench 仅评测软件工程（issue → patch）
- RTLLM/RTLBench 仅评测单步 RTL 生成（NL → Verilog）
- 无 benchmark 覆盖完整的芯片设计流程

**BabelBench**：
- 覆盖 5 个阶段：需求 → 架构 → RTL → 验证 → 综合 → 物理设计
- 每个阶段都有客观的 quality gate（schema/lint/coverage/timing/DRC）
- 产出从 design idea 到 GDSII 的完整设计

### 2. 客观可量化的评分

**现状**：
- 很多 benchmark 依赖人工评审或 test case，主观性强
- 评分标准不透明，无法复现

**BabelBench**：
- 所有评分基于 EDA 工具链的自动化检查（无主观判断）
- 评分公式公开透明，权重可配置
- 评测结果可复现（temperature=0, fixed seed, version-locked tools）

### 3. 多难度层次，覆盖真实场景

**现状**：
- 很多 benchmark 只有单一难度，无法区分 LLM 能力差异

**BabelBench**：
- 10 个问题，4 个难度级别（Easy/Medium/Hard/Expert）
- Easy：4-8 模块，单时钟域，8-12 小时人工
- Medium：10-11 模块，2-3 时钟域，24-36 小时人工
- Hard：11-13 模块，2-4 时钟域，80-160 小时人工
- Expert：13-20 模块，5-7 时钟域，240-400 小时人工

### 4. 6 维度全面评测

**现状**：
- 很多 benchmark 只关注正确性（pass/fail）

**BabelBench**：
- **Correctness**（0.25）：设计是否正确（pass rate, gate pass rate）
- **Completeness**（0.20）：设计是否完整（模块覆盖，IO 覆盖）
- **Quality**（0.20）：PPA 质量（timing, area, power）
- **Efficiency**（0.15）：效率（token 使用，tool call 效率）
- **Robustness**（0.10）：鲁棒性（修复成功率，错误恢复）
- **Cost-Effectiveness**（0.10）：成本效益（USD/pipeline, token/stage）

---

## 标准化问题定义

**问题 ID**: `complete_ai_soc_v1`

| 难度 | 模块数 | 时钟域 | 预估人工 | 关键特点 |
|------|--------|--------|---------|---------|
| Expert | 25-35 | 6 | 400h | 完整 AI SoC：16核NPU + 4核RISC-V + NoC + DDR4 + PCIe + 自定义ISA |

**核心需求**:
1. **NPU子系统**：16个NPU核心，支持Transformer推理（Attention/MatMul/RMSNorm/RoPE），16 TOPS算力
2. **CPU子系统**：4个RISC-V RV64GC核心，支持Linux
3. **IP复用**：DDR4控制器、PCIe Gen3 x4、JTAG
4. **SoC集成**：2D Mesh NoC（4x4）、分层缓存（64KB L1 + 8MB L2）、多时钟域CDC
5. **指令集实现**：自定义NPU ISA（32条指令）+ 合规测试
6. **外设接口**：DDR4/PCIe/JTAG/UART/SPI/GPIO
7. **电源管理**：DVFS（4电压域）、时钟门控、电源门控
8. **安全启动**：Secure Boot ROM、密钥管理

**工艺约束**: ASAP7 7nm，1GHz/1.5GHz，面积≤50mm²，功耗≤15W

**问题定义文件**：`testbench/problems/complete_ai_soc_v1.json`

---

## Harness 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    BabelBench Harness                        │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Problem  │───►│  LLM     │───►│ Stage    │──► score     │
│  │ Set      │    │ Adapter  │    │ Executor │              │
│  │ (10 Qs)  │    │ (API)    │    │ (Babel)  │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       │                │                │                     │
│       ▼                ▼                ▼                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Reference│    │ Cost     │    │ Metric   │              │
│  │ Artifacts│    │ Tracker  │    │ Collector│              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                        │                     │
│                                        ▼                     │
│                                 ┌──────────┐                │
│                                 │ Sandbox  │                │
│                                 │ Manager  │                │
│                                 └──────────┘                │
│                                        │                     │
│                                        ▼                     │
│                                 ┌──────────┐                │
│                                 │ Report   │                │
│                                 │ Generator│                │
│                                 └──────────┘                │
└─────────────────────────────────────────────────────────────┘
```

**核心组件**：
- **Problem Set Manager**：管理 10 个标准化问题
- **LLM Adapter**：统一 LLM API（Claude/GPT/DeepSeek/Qwen）
- **Stage Executor**：执行 5 阶段 Babel pipeline
- **Metric Collector**：收集 EDA 工具链的指标
- **Sandbox Manager**：管理评测沙箱
- **Report Generator**：生成雷达图和排行榜

---

## 实施路线图

### Phase 1: 结果收集和指标计算（2-3 周）
- Result Collector（解析 Babel 产物）
- Metric Collector（schema/lint/coverage/timing/DRC）
- Results Database（SQLite）

### Phase 2: 评分和报告（2-3 周）
- Scoring System（6 维度 + 5 阶段）
- Report Generator（雷达图+阶段对比图）
- CLI Tool（babel-bench collect/report/compare）

### Phase 3: 文档和测试（2 周，可选）
- User Manual
- Developer Documentation
- Unit Tests（80%+ coverage）
- Integration Tests

**总计**：Must Have 功能 4-6 周，完整功能 6-8 周

---

## 成功标准

### 功能验收标准

- [ ] 复杂问题有完整的 JSON 定义和参考实现
- [ ] 支持至少 3 个 LLM（Claude/GPT/DeepSeek）
- [ ] 5 阶段流水线可以完整执行
- [ ] 所有指标可以自动收集和计算
- [ ] 6 个维度的评分可以正确计算
- [ ] 5 个阶段的评分可以正确计算
- [ ] 雷达图和阶段对比图可以正确生成
- [ ] CLI 工具可以正常运行

### 非功能验收标准

- [ ] 单个 Expert 问题评测 ≤ 240 分钟（4 小时）
- [ ] 3 个 LLM 对比评测 ≤ 12 小时
- [ ] Harness 自身故障率 < 1%
- [ ] 评测结果可复现率 > 95%
- [ ] 测试覆盖率 ≥ 80%

---

## 风险和缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| LLM API 不稳定 | 评测失败 | 中 | 自动重试 3 次，保存中间结果 |
| EDA 工具崩溃 | 阶段失败 | 低 | 捕获异常，跳过当前问题 |
| 评测时间过长 | 用户体验差 | 中 | 并行评测，进度条，断点续传 |
| 评分标准不公平 | 结果不可信 | 低 | 公开评分公式，提供解释 |
| 问题定义有歧义 | 理解不一致 | 中 | 人工审查，提供参考实现 |
| 参考实现质量不高 | 基准不准确 | 低 | 经验丰富的工程师编写，code review |
| 评测结果不可复现 | 结果不可信 | 低 | temperature=0, fixed seed, version-locked |

---

## 下一步行动

1. **用户审查**：用户审查设计文档，确认方案选择和实施优先级

2. **调用 it.arch**：如果用户批准，调用 it.arch 生成详细的架构规范

3. **开始 Phase 1**：实现 Problem Set Manager + LLM Adapter + Sandbox Manager

4. **Pilot Run**：用 1 个 Easy 问题（tinystories_npu）和 1 个 LLM（Claude Sonnet 4.6）进行试点运行

5. **迭代优化**：根据 pilot run 结果调整设计，然后扩展到全部 10 个问题和 3 个 LLM

---

## 文件清单

```
testbench/
├── design_doc.md              # 完整设计文档（12 章节）
├── approach_analysis.md       # 方案分析（3 个方案对比）
├── clarifications.md          # 澄清记录
├── summary.md                 # 执行摘要（本文档）
├── README.md                  # 项目说明
└── problems/                  # 标准化问题定义
    └── complete_ai_soc_v1.json  # 完整 AI SoC 设计问题（Expert 难度）
```

---

## 联系方式

如有问题或建议，请联系 BabelBench 团队。
