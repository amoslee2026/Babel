# BabelBench 执行手册

> 本文档定义如何实际运行一次 benchmark 评测：从启动 Claude Code 到产出评分报告。

---

## 1. 总体流程

```
┌──────────────────────────────────────────────────────────────┐
│  对每个 LLM，重复以下步骤：                                  │
│                                                              │
│  Step 0: 创建沙箱（隔离的工作目录）                          │
│  Step 1: 启动 Claude Code，输入 design idea                  │
│  Step 2: 依次运行 5 个 Babel skill                           │
│  Step 3: 收集产物和报告                                      │
│  Step 4: 运行评分脚本                                        │
│                                                              │
│  最后：运行对比脚本，生成排行榜                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. 各阶段产物与可提取指标

Babel 每个阶段自然产出结构化报告（JSON），harness 只需解析这些文件即可提取所有指标。

### Stage 1: Architecture (Arch/Spec)

**运行方式**：在 Claude Code 中输入 design idea，调用 `/bba-architect`

**产物路径**（相对于沙箱根目录）：
```
spec/
├── PRD/PRD.md                    # 产品需求文档
├── ARCH/                         # 架构规范
│   ├── chip_overview.md
│   ├── block_diagram.md
│   ├── clock_reset_spec.md
│   ├── memory_map.md
│   ├── power_spec.md
│   ├── io_pinout.md
│   └── verification_plan.md
└── MAS/                          # 微架构规范
    ├── module_tree.md            # 模块依赖树
    ├── plan.md                   # 实施计划
    ├── requirements_registry.md  # 需求追踪矩阵
    └── M*/MAS.md                 # 各模块微架构
```

**可提取指标**：

| 指标 | 提取方式 | 评分用途 |
|------|---------|---------|
| 模块数量 | `grep -c "^## M" spec/MAS/module_tree.md` | Completeness (CP2) |
| 时钟域数量 | `grep -c "clk_" spec/ARCH/clock_reset_spec.md` | Completeness (CP4) |
| IO 数量 | `grep -c "signal" spec/ARCH/io_pinout.md` | Completeness (CP3) |
| MAS schema 是否完整 | 检查所有 M*/MAS.md 存在 | Correctness (C3) |
| 需求覆盖率 | `spec/MAS/requirements_registry.md` 中 REQ 数 / 预期数 | Completeness (CP5) |

### Stage 2: RTL Coding

**运行方式**：调用 `/bba-guru-rtl`

**产物路径**：
```
rtl/designs/<design_name>/
├── M*/src/M*.sv                  # SystemVerilog RTL 源码
└── synth/modules_simple/         # 简单综合验证产物（可选）
```

`rtl_artifact.json` 格式：
```json
{
  "rtl_files": ["rtl/M00/src/M00_*.sv", ...],
  "hashes": {"rtl/M00/src/M00_*.sv": "sha256...", ...},
  "generated": "ISO8601"
}
```

**可提取指标**：

| 指标 | 提取方式 | 评分用途 |
|------|---------|---------|
| RTL 文件数量 | `rtl_artifact.json` 中 `rtl_files` 数组长度 | Completeness (CP2) |
| 端口匹配率 | 对比 MAS 接口定义 vs RTL 实际端口 | Completeness (CP3) |
| Lint 结果 | 运行 `verilator --lint-only` 统计 error/warning | Correctness (C4), Quality (Q4) |
| 代码行数 | `wc -l rtl/M*/src/*.sv` | Efficiency 参考 |

### Stage 3: Verification

**运行方式**：调用 `/bba-guru-verification`

**产物路径**：
```
designs/<design_name>/
├── verif/verification_plan.md    # 验证计划
├── tb/tb_M*.sv                   # Testbench 文件
├── test_report.json              # 验证报告（中间）
├── test_report_final.json        # 最终验证报告
├── coverage.dat                  # 覆盖率原始数据
└── coverage_final.info           # lcov 格式覆盖率
```

`test_report_final.json` 关键结构：
```json
{
  "functional_coverage": 25.47,
  "code_coverage": {
    "line": 16.1,
    "branch": 25.88,
    "toggle": 9.25
  },
  "tests": [
    {"name": "tb_M00_*", "status": "pass", "log": "..."},
    {"name": "tb_M01_*", "status": "fail", "log": "..."}
  ],
  "iteration_count": 3
}
```

**可提取指标**：

| 指标 | 提取方式 | 评分用途 |
|------|---------|---------|
| 功能覆盖率 | `test_report_final.json → functional_coverage` | Correctness (C2), Stage Score (S3.1) |
| 行覆盖率 | `test_report_final.json → code_coverage.line` | Correctness (C2), Stage Score (S3.2) |
| 分支覆盖率 | `test_report_final.json → code_coverage.branch` | Stage Score (S3.2) |
| 测试通过率 | `tests` 中 status=pass 的数量 / 总数 | Correctness (C1), Stage Score (S3.3) |
| 迭代次数 | `iteration_count` | Robustness (R3) |

### Stage 4: Synthesis

**运行方式**：调用 `/bba-guru-synthesis`

**产物路径**：
```
rtl/designs/<design_name>/synth/
├── netlist_*.v                   # 综合网表
├── modules_simple/               # 模块级综合产物
└── ...

designs/<design_name>/
└── synth_report.json             # 综合报告
```

`synth_report.json` 关键结构：
```json
{
  "design_name": "...",
  "status": "first_run_acceptable",
  "target_frequency_mhz": 500,
  "modules_total": 17,
  "modules_passed": 15,
  "modules_failed": 2,
  "modules": {
    "M00_*": {
      "status": "pass|timeout|fail",
      "cell_count": 5000,
      "wire_count": 10000,
      "area_estimate_um2": 50000
    }
  }
}
```

**可提取指标**：

| 指标 | 提取方式 | 评分用途 |
|------|---------|---------|
| 模块通过率 | `modules_passed / modules_total` | Correctness (C2) |
| WNS | 后续 PD 阶段 OpenSTA 报告提取 | Quality (Q1), Stage Score (S4.1) |
| 面积估算 | `area_estimate_um2` 汇总 | Quality (Q2), Stage Score (S4.2) |
| 综合失败模块数 | `modules_failed` | Robustness (R1) |

### Stage 5: Physical Design (PD)

**运行方式**：调用 `/bba-guru-pd`

**产物路径**：
```
designs/<design_name>/
├── pd/
│   ├── floorplan*.tcl            # Floorplan 脚本
│   ├── placed*.def               # 布局 DEF
│   ├── routed*.def               # 布线 DEF
│   ├── drc_*                     # DRC 报告
│   ├── lvs_*                     # LVS 报告
│   └── sta_*.log                 # STA 报告
├── gdsii/
│   └── <design_name>.gds         # GDSII 版图
└── pd_report_final.json          # 最终 PD 报告
```

`pd_report_final.json` 关键结构：
```json
{
  "design_name": "...",
  "status": "pd_flow_complete",
  "floorplan_status": {"success": true, "die_width_um": 53600, ...},
  "placement_status": {"cells_placed": 6939, "success": true, ...},
  "routing_status": {"success": true, ...},
  "drc_status": {"violations": 0, "clean": true, ...},
  "lvs_status": {"match": true, ...},
  "timing_status": {"wns_ns": 0.0, "tns_ns": 0.0, "timing_met": true, ...},
  "gds_status": {"gds_path": "...", "gds_size_bytes": 2041856, "success": true}
}
```

**可提取指标**：

| 指标 | 提取方式 | 评分用途 |
|------|---------|---------|
| DRC violations | `drc_status.violations` | Correctness (C5), Quality (Q5) |
| LVS match | `lvs_status.match` | Correctness (C5) |
| WNS | `timing_status.wns_ns` | Quality (Q1), Stage Score (S4.1/S5) |
| GDSII 是否生成 | `gds_status.success` | Completeness (CP1) |
| 面积 | `floorplan_status.die_width_um × die_height_um` | Quality (Q2) |

---

## 3. 执行步骤

### Step 0: 创建沙箱

```bash
# 为每个 LLM 创建隔离的工作目录
LLM_ID="claude_sonnet_46"   # 或 gpt_4o, deepseek_v3 等
RUN_ID="${LLM_ID}_$(date +%Y%m%d_%H%M%S)"
SANDBOX="testbench/runs/${RUN_ID}"

mkdir -p "${SANDBOX}"

# 复制问题定义
cp testbench/problems/complete_ai_soc_v1.json "${SANDBOX}/problem.json"

# 记录开始时间
echo "{\"llm\": \"${LLM_ID}\", \"started\": \"$(date -Iseconds)\"}" > "${SANDBOX}/run_metadata.json"
```

### Step 1: 启动 Claude Code，输入 design idea

```bash
cd "${SANDBOX}"

# 方式 A：直接启动 Claude Code（手工切换 LLM）
claude

# 在 Claude Code 中输入：
# 读取 problem.json 中的 design_idea 字段作为输入
# 然后依次调用 5 个 Babel skill
```

### Step 2: 依次运行 5 个 Babel skill

在 Claude Code 会话中：

```
# Stage 1: 架构设计
/bba-architect

# Stage 2: RTL 生成
/bba-guru-rtl

# Stage 3: 验证
/bba-guru-verification

# Stage 4: 综合
/bba-guru-synthesis

# Stage 5: 物理设计
/bba-guru-pd
```

**每个阶段结束后**，Claude Code 会自然产出对应的报告文件（见第 2 节）。

### Step 3: 收集产物

所有阶段完成后（或任何阶段失败后），运行收集脚本：

```bash
bash testbench/scripts/collect_results.sh "${SANDBOX}"
```

### Step 4: 评分

```bash
python3 testbench/scripts/score.py "${SANDBOX}"
```

### Step 5: 对比

```bash
python3 testbench/scripts/compare.py testbench/runs/claude_sonnet_46_*/ testbench/runs/gpt_4o_*/
```

---

## 4. 评分计算

### 4.1 六维度评分

从各阶段报告中提取指标，按 design_doc.md §6 的公式计算：

```
Score = 0.25 × Correctness + 0.20 × Completeness + 0.20 × Quality
      + 0.15 × Efficiency + 0.10 × Robustness + 0.10 × Cost-Effectiveness
```

### 4.2 五阶段评分

```
Stage_Score[i] = Σ(metric_weight × metric_score)   i = 1..5
Overall_Stage_Score = (S1 + S2 + S3 + S4 + S5) / 5
```

---

## 5. 数据记录规范

### 5.1 每次运行的目录结构

```
testbench/runs/
└── ${LLM_ID}_${TIMESTAMP}/
    ├── run_metadata.json         # 运行元数据（LLM、时间、状态）
    ├── problem.json              # 问题定义副本
    ├── spec/                     # Stage 1 产物
    │   ├── PRD/
    │   ├── ARCH/
    │   └── MAS/
    ├── rtl/                      # Stage 2 产物
    │   └── designs/<name>/*.sv
    ├── rtl_artifact.json         # Stage 2 报告
    ├── designs/<name>/           # Stage 3-5 产物
    │   ├── verif/
    │   ├── tb/
    │   ├── test_report_final.json
    │   ├── synth_report.json
    │   ├── pd/
    │   ├── pd_report_final.json
    │   └── gdsii/
    └── results/                  # 评分结果
        ├── metrics.json          # 提取的原始指标
        ├── scores.json           # 计算的评分
        └── report.md             # 可读报告
```

### 5.2 run_metadata.json 格式

```json
{
  "llm": "claude-sonnet-4.6",
  "llm_version": "claude-sonnet-4-6-20250514",
  "problem_id": "complete_ai_soc_v1",
  "started": "2026-05-30T23:00:00+08:00",
  "completed": "2026-05-31T03:00:00+08:00",
  "duration_hours": 4.0,
  "stages_completed": ["arch", "rtl", "verification", "synthesis"],
  "stage_failed": "pd",
  "failure_reason": "OpenSTA timeout",
  "total_tool_calls": 342,
  "estimated_tokens": 1250000,
  "estimated_cost_usd": 15.0
}
```

### 5.3 results/metrics.json 格式

```json
{
  "stage_metrics": {
    "arch": {
      "module_count": 28,
      "clock_domain_count": 6,
      "io_count": 45,
      "mas_files_count": 28
    },
    "rtl": {
      "file_count": 28,
      "total_lines": 15420,
      "lint_errors": 0,
      "lint_warnings": 3
    },
    "verification": {
      "functional_coverage": 85.0,
      "line_coverage": 92.3,
      "branch_coverage": 88.1,
      "toggle_coverage": 75.0,
      "test_count": 35,
      "test_pass_count": 33,
      "test_fail_count": 2,
      "iteration_count": 5
    },
    "synthesis": {
      "modules_total": 28,
      "modules_passed": 25,
      "modules_failed": 3,
      "total_area_um2": 45000000,
      "target_freq_mhz": 1000
    },
    "pd": {
      "floorplan_success": true,
      "placement_success": true,
      "routing_success": true,
      "drc_violations": 0,
      "lvs_match": true,
      "wns_ns": 0.0,
      "gds_success": true,
      "gds_size_bytes": 2041856
    }
  },
  "efficiency_metrics": {
    "total_duration_hours": 4.0,
    "total_tool_calls": 342,
    "total_tokens": 1250000,
    "estimated_cost_usd": 15.0,
    "stages_completed": 4,
    "stages_total": 5
  }
}
```

### 5.4 results/scores.json 格式

```json
{
  "dimensions": {
    "correctness": {
      "score": 0.82,
      "sub_scores": {
        "C1_pipeline_success": 0.80,
        "C2_stage_gate_pass": 0.85,
        "C3_schema_valid": 0.90,
        "C4_lint_clean": 0.97,
        "C5_drc_lvs_clean": 1.00
      }
    },
    "completeness": {
      "score": 0.78,
      "sub_scores": {
        "CP1_highest_stage": 1.00,
        "CP2_module_coverage": 0.80,
        "CP3_io_coverage": 0.85,
        "CP4_clock_domain_coverage": 1.00,
        "CP5_feature_coverage": 0.70
      }
    },
    "quality": {"score": 0.75, "sub_scores": {}},
    "efficiency": {"score": 0.65, "sub_scores": {}},
    "robustness": {"score": 0.70, "sub_scores": {}},
    "cost_effectiveness": {"score": 0.60, "sub_scores": {}}
  },
  "stages": {
    "S1_arch": 0.92,
    "S2_rtl": 0.87,
    "S3_verification": 0.75,
    "S4_synthesis": 0.68,
    "S5_pd": 0.00
  },
  "final_score": 0.75
}
```

---

## 6. 效率指标采集

效率指标需要额外记录，Babel 的报告文件不直接包含这些数据。

### 6.1 时间记录

在每个阶段开始和结束时记录时间戳：

```bash
# 在 run_metadata.json 中追加阶段时间
# 可以在每个 skill 调用前后手动记录，或通过 hook 自动记录
```

### 6.2 Token 和成本记录

Claude Code 的 token 使用可以通过以下方式获取：

```bash
# Claude Code 会话结束后，查看 usage 信息
# 方法 1：从 Claude Code 的 session log 中提取
cat ~/.claude/projects/*/sessions/*/usage.json 2>/dev/null

# 方法 2：通过 API 查询（如果使用 API 直接调用）
# 方法 3：手动记录 Claude Code 显示的 token 用量
```

### 6.3 Tool Call 计数

```bash
# 从 Claude Code session transcript 中统计 tool calls
grep -c '"tool_use"' ~/.claude/projects/*/sessions/*/transcript.jsonl 2>/dev/null
```

---

## 7. 对比报告格式

对比多个 LLM 的结果时，生成如下格式的报告：

### 7.1 排行榜（Markdown）

```markdown
# BabelBench Leaderboard

Generated: 2026-06-01T10:00:00+08:00
Problem: complete_ai_soc_v1

| Rank | LLM | Final Score | Correctness | Completeness | Quality | Efficiency | Robustness | Cost |
|------|-----|-------------|-------------|-------------|---------|------------|------------|------|
| 1 | GPT-4o | 0.78 | 0.85 | 0.80 | 0.72 | 0.70 | 0.75 | 0.65 |
| 2 | Claude Sonnet 4.6 | 0.75 | 0.82 | 0.78 | 0.75 | 0.65 | 0.70 | 0.60 |
| 3 | DeepSeek V3 | 0.68 | 0.72 | 0.70 | 0.68 | 0.60 | 0.65 | 0.55 |
```

### 7.2 阶段对比

```markdown
## Stage-by-Stage Comparison

| LLM | Arch | RTL | Verification | Synthesis | PD | Completed |
|-----|------|-----|-------------|-----------|-----|-----------|
| GPT-4o | 0.88 | 0.82 | 0.72 | 0.75 | 0.68 | 5/5 |
| Claude Sonnet 4.6 | 0.92 | 0.87 | 0.78 | 0.68 | 0.00 | 4/5 |
| DeepSeek V3 | 0.85 | 0.75 | 0.65 | 0.60 | 0.00 | 4/5 |
```

### 7.3 雷达图数据

```json
{
  "claude_sonnet_46": {
    "correctness": 0.82,
    "completeness": 0.78,
    "quality": 0.75,
    "efficiency": 0.65,
    "robustness": 0.70,
    "cost_effectiveness": 0.60
  }
}
```

---

## 8. 快速开始（最小可行方案）

如果暂时不写自动化脚本，可以手动执行以下步骤：

### 8.1 对每个 LLM

```bash
# 1. 创建沙箱
LLM="claude_sonnet_46"
mkdir -p testbench/runs/${LLM}_$(date +%Y%m%d)
cd testbench/runs/${LLM}_$(date +%Y%m%d)
cp ../../problems/complete_ai_soc_v1.json problem.json

# 2. 启动 Claude Code，手动运行 5 个 skill
claude
# 输入 design idea → /bba-architect → /bba-guru-rtl → ... → /bba-guru-pd

# 3. 手动收集关键指标到 results/metrics.json
# 从各 report JSON 文件中提取数据

# 4. 手动计算评分到 results/scores.json
# 按 design_doc.md §6 的公式计算
```

### 8.2 对比

```bash
# 手动创建对比表格，或运行对比脚本
python3 testbench/scripts/compare.py testbench/runs/*/
```

---

## 9. 自动化脚本清单

| 脚本 | 功能 | 优先级 |
|------|------|--------|
| `scripts/collect_results.sh` | 从沙箱中提取所有报告文件，生成 metrics.json | P0 |
| `scripts/score.py` | 从 metrics.json 计算 6 维度 + 5 阶段评分，生成 scores.json | P0 |
| `scripts/compare.py` | 对比多个 runs 目录，生成排行榜和阶段对比表 | P0 |
| `scripts/radar_chart.py` | 从 scores.json 生成雷达图（HTML/SVG） | P1 |
| `scripts/record_timestamps.sh` | 记录每个阶段的开始/结束时间 | P1 |
| `scripts/extract_tokens.py` | 从 Claude Code session log 提取 token 用量 | P1 |
