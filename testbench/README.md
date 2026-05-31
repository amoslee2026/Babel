# BabelBench: LLM 芯片设计能力评测框架

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)

BabelBench 是一个生产级的 LLM benchmark 框架，用于评测大语言模型在端到端芯片设计 workflow 中的能力。基于 Babel 的 5 阶段流水线（Architect → RTL → Verification → Synthesis → Physical Design），BabelBench 通过 10 个标准化的设计问题，从 6 个维度（正确性、完整性、质量、效率、鲁棒性、成本效益）对比不同 LLM 的性能。

---

## 特性

### 首个端到端芯片设计 benchmark

- 覆盖 5 个阶段：需求 → 架构 → RTL → 验证 → 综合 → 物理设计
- 每个阶段都有客观的 quality gate（schema/lint/coverage/timing/DRC）
- 产出从 design idea 到 GDSII 的完整设计

### 客观可量化的评分

- 所有评分基于 EDA 工具链的自动化检查（无主观判断）
- 评分公式公开透明，权重可配置
- 评测结果可复现（temperature=0, fixed seed, version-locked tools）

### 1 个综合性复杂问题

| 难度 | 问题数 | 模块数 | 时钟域 | 预估人工 | 关键特点 |
|------|--------|--------|--------|---------|---------|
| Expert | 1 | 25-35 | 6 | 400h | 完整 AI SoC：16核NPU + 4核RISC-V + NoC + DDR4 + PCIe + 自定义ISA |

### 6 维度全面评测

- **Correctness**（0.25）：设计是否正确
- **Completeness**（0.20）：设计是否完整
- **Quality**（0.20）：PPA 质量
- **Efficiency**（0.15）：效率
- **Robustness**（0.10）：鲁棒性
- **Cost-Effectiveness**（0.10）：成本效益

---

## 快速开始

### 环境要求

- Python 3.11+
- Babel 项目（已配置 EDA 工具链）
- LLM API keys（Anthropic/OpenAI/DeepSeek/Qwen）

### 安装

```bash
# 克隆 Babel 项目
git clone https://github.com/amoslee2026/Babel.git
cd Babel

# 安装 BabelBench 依赖
cd testbench
pip install -r requirements.txt

# 配置 LLM API keys
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
export DEEPSEEK_API_KEY="your-key-here"
export QWEN_API_KEY="your-key-here"
```

### 运行评测

```bash
# 1. 使用 LLM 运行 Babel workflow（手动切换 LLM）
# 以 complete_ai_soc_v1 为输入，运行 5 阶段 Babel pipeline
/bba-architect  # 生成 MAS
/bba-guru-rtl   # 生成 RTL
/bba-guru-verification  # 验证
/bba-guru-synthesis     # 综合
/bba-guru-pd    # 物理设计

# 2. 收集结果和指标
babel-bench collect --problem complete_ai_soc_v1 --llm claude-sonnet-4.6 --output results/claude_sonnet/

# 3. 生成报告
babel-bench report --output reports/

# 4. 对比不同 LLM
babel-bench compare --llm claude-sonnet-4.6,gpt-4o,deepseek-v3
```

### 查看结果

```bash
# 查看排行榜
cat reports/leaderboard.md

# 查看雷达图
open reports/radar_chart.html

# 查看详细报告
cat reports/detailed_report.md
```

---

## 标准化问题定义

**问题 ID**: `complete_ai_soc_v1`

**难度**: Expert（预估 400 小时人工）

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

## 文档

- [设计文档](design_doc.md) - 完整的设计规范（12 章节）
- [方案分析](approach_analysis.md) - 3 个方案对比和推荐
- [澄清记录](clarifications.md) - 用户澄清和假设清单
- [执行摘要](summary.md) - 一页纸概述

---

## 架构

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

## 贡献

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 添加新的 LLM

1. 实现 `LLMAdapter` 接口
2. 在 `llm_adapters/` 目录添加新的 adapter
3. 在 `config/llm_providers.yaml` 注册
4. 运行测试验证

### 添加新的问题

1. 在 `problems/` 目录创建新的 JSON 文件
2. 遵循 problem schema（参考 `problems/tinystories_npu_v1.json`）
3. 提供参考实现（`reference_artifacts/`）
4. 运行测试验证

---

## 许可证

BabelBench 采用 [Apache 2.0 许可证](LICENSE)。

---

## 引用

如果您在研究中使用了 BabelBench，请引用：

```bibtex
@misc{babelbench2026,
  title={BabelBench: A Benchmark for LLM-based Chip Design Workflows},
  author={BabelBench Team},
  year={2026},
  publisher={GitHub},
  howpublished={\url{https://github.com/amoslee2026/Babel/testbench}}
}
```

---

## 联系方式

如有问题或建议，请提交 [GitHub Issue](https://github.com/amoslee2026/Babel/issues)。

---

## 致谢

- [SWE-bench](https://www.swebench.com/) - 软件工程 agent 评测的灵感来源
- [RTLLM](https://github.com/hkust-zhiyao/RTLLM) - RTL 生成评测的参考
- [HAL Harness](https://github.com/princeton-pli/hal-harness) - Agent 评测框架的参考
- [Babel 项目](https://github.com/amoslee2026/Babel) - 芯片设计 workflow 的基础
