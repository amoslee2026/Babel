# 方案分析：BabelBench 评测框架

## 方案对比

### 方案 A：全栈自研 Harness（推荐）

**核心思路**：从零构建完整的评测 harness，包括 problem manager、LLM adapter、stage executor、metric collector、report generator

**优点**：
- 完全控制评测流程，可深度定制
- 与 Babel agent 紧密集成，性能最优
- 可复现性最强（所有组件版本锁定）
- 长期维护成本低（无外部依赖）

**缺点**：
- 开发工作量大（预估 800-1200 人时）
- 需要重复实现一些通用功能（token counting、sandbox management）
- 初期投入高

**适用场景**：生产级评测框架，需要长期运行和公开排行榜

**实施顺序建议**：
- 优先实施：Result Collector + Metric Collector（结果收集和指标计算，无依赖）
- 后续实施：Scoring System（6 维度 + 5 阶段评分，依赖指标数据）
- 最后实施：Report Generator + CLI（接口层，依赖评分系统）

**关键依赖路径**：Result Collector + Metric Collector → Scoring System → Report Generator + CLI

---

### 方案 B：基于现有框架扩展

**核心思路**：基于 SWE-bench 或 HAL Harness 框架，扩展支持 Babel 的 5 阶段流水线

**优点**：
- 开发工作量小（预估 400-600 人时）
- 可复用成熟的 sandbox management 和 token tracking
- 快速上线

**缺点**：
- 受限于现有框架的设计假设（可能不适配多阶段 pipeline）
- 定制灵活性低
- 外部依赖风险（框架停止维护）
- 可复现性受框架版本影响

**适用场景**：快速原型验证，学术研究

**实施顺序建议**：
- 优先实施：框架 fork + Babel adapter
- 后续实施：5 阶段 pipeline 扩展
- 最后实施：评分系统集成

**关键依赖路径**：框架 fork → Babel adapter → Pipeline extension → Scoring integration

---

### 方案 C：混合方案（自研核心 + 复用外围）

**核心思路**：核心评测逻辑自研（stage executor、metric collector），外围功能复用开源组件（token counting、sandbox management）

**优点**：
- 平衡开发工作量和控制力（预估 600-800 人时）
- 核心评测逻辑可完全控制
- 外围功能快速复用

**缺点**：
- 集成复杂度中等
- 需要维护多个组件的版本兼容性
- 可复现性中等

**适用场景**：中等规模项目，需要快速上线但也要长期维护

**实施顺序建议**：
- 优先实施：Problem Set Manager + 集成开源 sandbox/token 组件
- 后续实施：Stage Executor + Metric Collector（自研核心）
- 最后实施：Scoring System + Report Generator

**关键依赖路径**：开源组件集成 → Stage Executor → Metric Collector → Scoring System

---

## 推荐方案：方案 A（全栈自研）

### 推荐理由

1. **生产级需求**：用户明确选择了"生产级评测框架"，需要长期运行和公开排行榜，方案 B 和 C 的外部依赖风险不可接受

2. **深度定制需求**：Babel 的 5 阶段流水线是独特的，现有框架（SWE-bench/HAL Harness）主要面向单步或双步任务，无法直接适配

3. **可复现性要求**：方案 A 可以实现所有组件版本锁定，确保评测结果 100% 可复现

4. **长期维护成本**：虽然初期投入高，但长期维护成本低（无外部依赖变更风险）

5. **Babel 已有基础**：Babel 已经有完整的 bba-guru agent 体系和 EDA 工具链集成，harness 主要是编排层，不需要从零实现 EDA 工具调用

### 风险缓解

**风险 1：开发工作量**
- 缓解措施：分阶段实施（Phase 1-3），每阶段 2-3 周
- 优先实现 Must Have 功能（Phase 1-2），Phase 3 可选

**风险 2：指标收集复杂度**
- 缓解措施：复用 Babel 已有的 EDA 工具链输出（lint/coverage/timing/DRC 报告）
- 仅在需要时开发自定义解析器

**风险 3：测试覆盖率不足**
- 缓解措施：TDD 开发，每个模块先写测试
- 目标测试覆盖率 80%+

---

## 关键技术决策

### 决策 1：编程语言选择

**选项**：
- Python 3.11+（推荐）
- Rust
- Go

**推荐**：Python 3.11+

**理由**：
- Babel 现有代码主要是 Python 和 Shell
- LLM API 客户端库成熟（anthropic、openai、dashscope）
- EDA 工具调用主要是 Shell 脚本，Python 易于集成
- 数据处理和可视化库丰富（pandas、matplotlib）

**权衡**：性能不如 Rust/Go，但评测框架不是性能敏感型应用

---

### 决策 2：数据库选择

**选项**：
- SQLite（推荐）
- PostgreSQL
- MongoDB

**推荐**：SQLite

**理由**：
- 单机部署，无需数据库服务器
- 评测结果数据量不大（每次运行 ~1MB）
- Python 内置支持，无需额外依赖
- 易于备份和迁移（单文件）

**权衡**：不支持并发写入，但评测框架是单进程运行

---

### 决策 3：沙箱隔离方式

**选项**：
- 文件系统隔离（推荐）
- Docker 容器
- Git worktree

**推荐**：文件系统隔离

**理由**：
- 最简单，无额外依赖
- 每个评测在独立目录，互不干扰
- 易于清理（直接删除目录）
- Babel 已经使用 worktree 管理设计项目，可以复用

**权衡**：隔离性不如 Docker，但评测框架不需要强隔离（所有 LLM 调用都通过 adapter，不会执行任意代码）

---

### 决策 4：LLM API 调用策略

**选项**：
- 直接调用 LLM API（推荐）
- 通过 Babel agent 间接调用
- 混合模式

**推荐**：直接调用 LLM API，但复用 Babel agent 的 prompt 和 tool 定义

**理由**：
- 直接调用可以精确控制 token counting 和 cost tracking
- 可以记录完整的 trajectory（所有 tool calls）
- 可以灵活控制并发和重试策略

**权衡**：需要重新实现 Babel agent 的部分逻辑（prompt 组装、tool 调用），但这些逻辑不复杂

---

## 实施路线图总结

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
- Unit Tests
- Integration Tests

**总计**：Must Have 功能 4-6 周，完整功能 6-8 周

---

## 下一步行动

1. **用户审查**：用户审查本设计文档，确认方案选择和实施优先级

2. **调用 it.arch**：如果用户批准，调用 it.arch 生成详细的架构规范

3. **开始 Phase 1**：实现 Result Collector + Metric Collector + Results Database

4. **Pilot Run**：用 1 个 LLM（Claude Sonnet 4.6）运行 complete_ai_soc_v1 问题，收集结果并验证指标计算

5. **迭代优化**：根据 pilot run 结果调整设计，然后扩展到 3 个 LLM 对比评测
