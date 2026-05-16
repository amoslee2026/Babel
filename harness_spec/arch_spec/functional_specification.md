---
name: babel-functional-specification
description: Babel 系统功能规格书 — 由 idea/design_doc.md v1.1.1 派生
type: arch_spec
version: 1.0.0
created: 2026-05-16
upstream: harness_spec/idea/design_doc.md
downstream: harness_spec/impl_spec/
---

# Babel 功能规格书

> 本文档定义 Babel 系统的功能需求清单，每条需求附唯一 ID（F00X）、优先级、验收标准。
> 派生自 `harness_spec/idea/design_doc.md` v1.1.1。

---

## 1. 优先级语义

| 标签 | 含义 |
|------|------|
| P0 | MVP（Phase 1-2）必交付 |
| P1 | Phase 3 交付 |
| P2 | Phase 4+ 交付 |

---

## 2. 核心功能需求 (P0)

### F001 — Specification 生成
| 字段 | 内容 |
|------|------|
| ID | F001 |
| 优先级 | P0 |
| 描述 | 用户用自然语言描述芯粒设计需求，系统生成 PRD + 结构化 spec.json + 架构 ADR 模板 |
| 拥有者模块 | M001 (babel-spec) |
| 输入 | 用户 prompt（自然语言）+ wiki/protocols/* 检索结果 |
| 输出 | `PRD.md`、`spec.json` (符合 `schemas/spec.schema.json`)、`ADR-*.md` |
| 验收标准 | (1) spec.json 通过 jsonschema 校验；(2) PRD 含 ≥3 个量化目标；(3) 至少识别 1 个核心 CBB 引用 |

### F002 — RTL 生成
| 字段 | 内容 |
|------|------|
| ID | F002 |
| 优先级 | P0 |
| 描述 | 基于 spec.json 生成 SystemVerilog/Verilog RTL + SDC 草稿 |
| 拥有者模块 | M002 (babel-rtl) |
| 输入 | `spec.json` (符合 spec schema) |
| 输出 | `rtl/*.sv`、`rtl/*.v`、`constraints/*.sdc` (草稿)，整体符合 `rtl_artifact.schema.json` |
| 验收标准 | (1) 通过 verible-verilog-lint 0 error；(2) 实例化的 CBB 全部存在于 wiki/cbb/；(3) SDC 含 clock 定义与基础 I/O 约束 |

### F003 — RTL 语法 lint
| 字段 | 内容 |
|------|------|
| ID | F003 |
| 优先级 | P0 |
| 描述 | 对 RTL 执行语法 / 编码规则 lint，不做 CDC（区分于 F004） |
| 拥有者模块 | M002 (babel-rtl) 调用 skill babel-check-lint |
| 输入 | `rtl/*.sv` |
| 输出 | `lint_report.json` |
| 验收标准 | 0 error；warning 数 ≤ 10 / 1000 行 |

### F004 — CDC / RDC 检查
| 字段 | 内容 |
|------|------|
| ID | F004 |
| 优先级 | P0 |
| 描述 | 检测 RTL 中的跨时钟域 / 跨复位域路径，验证同步器布局正确性 |
| 拥有者模块 | M006 (babel-cdc，原 clock-domain-guard) |
| 输入 | `rtl/*.sv` (rtl_artifact) |
| 输出 | `cdc_report.json` (符合 `cdc_report.schema.json`) |
| 验收标准 | (1) 报告含所有跨域路径列表；(2) 无 unwaived violation；(3) 每个同步器有命名 trace |

### F005 — 综合 (Synthesis)
| 字段 | 内容 |
|------|------|
| ID | F005 |
| 优先级 | P0 |
| 描述 | Yosys 综合 → 网表，QoR 分析（WNS、Area、Power 估算） |
| 拥有者模块 | M005 (babel-synth，原 yosys-synth-planner) |
| 输入 | rtl_artifact + cdc_report（gating）→ composite schema `synth_input.schema.json` |
| 输出 | `synth/netlist.v`、`synth/qor.json` (符合 `synth_report.schema.json`)、`constraints/*.sdc` (final) |
| 验收标准 | (1) WNS > -0.5ns @ ASAP7 1GHz；(2) Area < 120% hand-coded baseline；(3) 综合无 error |

### F006 — 动态验证
| 字段 | 内容 |
|------|------|
| ID | F006 |
| 优先级 | P0 |
| 描述 | cocotb / UVM 测试台生成与执行，覆盖率收集 |
| 拥有者模块 | M003 (babel-test) |
| 输入 | rtl_artifact + synth_report (netlist) |
| 输出 | `tb/*.sv`、`sim_results/*.log`、`coverage.json` (符合 `test_report.schema.json`) |
| 验收标准 | (1) Functional coverage ≥ 95%；(2) Code coverage ≥ 95%；(3) 0 sim failure |

### F007 — 跨域协调与状态管理
| 字段 | 内容 |
|------|------|
| ID | F007 |
| 优先级 | P0 |
| 描述 | 单写者模式管理 `design_state.json`，合并多 agent 事件 |
| 拥有者模块 | M004 (babel-coord，原 cross-domain-coordinator) + M301 (state_manager) |
| 输入 | `events/*.jsonl` (各 agent append-only) |
| 输出 | `design_state.json` (符合 `design_state.schema.json`) |
| 验收标准 | (1) 写入序列化（无并发冲突）；(2) 事件全部合并；(3) state.json 始终 schema-valid |

### F008 — fix_request 闭环
| 字段 | 内容 |
|------|------|
| ID | F008 |
| 优先级 | P0 |
| 描述 | agent 检测到下游失败 → 创建 fix_request → coordinator 重排 → 上游 agent 重做 |
| 拥有者模块 | M004 (babel-coord) |
| 输入 | fix_request (符合 `fix_request.schema.json`) |
| 输出 | 更新后的 todo 图 + 重派发的 subagent 调用 |
| 验收标准 | (1) UART 端到端至少完成 1 次 fix_request 闭环；(2) 平均迭代次数 ≤ 5 |

### F009 — Schema-validated IO 契约
| 字段 | 内容 |
|------|------|
| ID | F009 |
| 优先级 | P0 |
| 描述 | agent 启动前由 hook 校验上游输出符合 JSON Schema；不通过则阻断 |
| 拥有者模块 | M201 (schema_validator) + M401 (hooks) |
| 输入 | upstream artifact + schema 路径 |
| 输出 | pass / fail + violation detail (写入 stderr + fix_request) |
| 验收标准 | (1) 7 个 schema 全部 jsonschema-CLI 校验通过；(2) 模拟错误输入触发阻断 |

### F010 — max-iter 升级
| 字段 | 内容 |
|------|------|
| ID | F010 |
| 优先级 | P0 |
| 描述 | 超 `max_cross_domain_iterations` 时按配置触发 halt / escalate_user / force_signoff |
| 拥有者模块 | M004 (babel-coord) |
| 输入 | iteration count > threshold 事件 |
| 输出 | (a) halt: 写 halt_report.md；(b) escalate_user: state.pending_approval + stderr 横幅；(c) force_signoff: 强 sign-off + 警告 |
| 验收标准 | 三种 enum 行为各有单元测试覆盖 |

---

## 3. P1 功能（Phase 3 交付）

### F011 — claude-mem 集成
| 字段 | 内容 |
|------|------|
| ID | F011 |
| 优先级 | P1 |
| 描述 | 跨会话记忆委托给 claude-mem 插件；不维护 babel 自定义结构 |
| 拥有者模块 | M304 (claude-mem adapter) |
| 输入 | agent 经历事件 |
| 输出 | claude-mem 自身存储格式 |
| 验收标准 | (1) smoke test 通过；(2) 插件 disable 时 babel 降级 stateless 模式 + 警告 |
| 关联 ADR | ADR-007 (复用)、ADR-A04 (fallback) |

### F012 — Wiki 知识库 (MVP 范围)
| 字段 | 内容 |
|------|------|
| ID | F012 |
| 优先级 | P1 |
| 描述 | wiki/protocols/{uart,axi4-lite,ucie}.md + wiki/cbb/{sync-fifo,2ff-sync,clock-gate}.md |
| 拥有者模块 | M501 (wiki_kb) |
| 输入 | rg pattern 检索 |
| 输出 | wiki 条目内容 |
| 验收标准 | (1) 每条 wiki 含 frontmatter schema_version + content_hash；(2) babel-search-protocol skill 可检索 |

### F013 — Hooks
| 字段 | 内容 |
|------|------|
| ID | F013 |
| 优先级 | P1 |
| 描述 | PreToolUse / PostToolUse / Session hook 完整集合 |
| 拥有者模块 | M401 (hooks) |
| 输入 | tool call event |
| 输出 | 校验结果 / log / state 同步 |
| 验收标准 | 10 个 hook 全部触发并通过 unit test |

---

## 4. P2 功能（Phase 4+ 交付）

### F014 — Multi-session 全局锁
| 字段 | 内容 |
|------|------|
| ID | F014 |
| 优先级 | P2 |
| 描述 | 防止两个 babel 进程同时操作同一 design_id |
| 拥有者模块 | M303 (session_lock) |
| 验收标准 | 第二实例启动检测到活跃 lock → abort + 友好错误 |
| 关联 ADR | ADR-A06 |

### F015 — 权限边界软声明
| 字段 | 内容 |
|------|------|
| ID | F015 |
| 优先级 | P2 |
| 描述 | agent yaml 中 tools/write_paths/read_denylist 三字段；本项目内不作为安全边界（详见 ADR-010） |
| 拥有者模块 | M601 (bash_linter, 可选 developer-error guard) |
| 验收标准 | (1) yaml schema 校验三字段非空；(2) bash_linter 警告明显越界命令（不阻断） |
| 关联 ADR | ADR-010、ADR-A09 |

### F016 — User 手动 override
| 字段 | 内容 |
|------|------|
| ID | F016 |
| 优先级 | P2 |
| 描述 | 用户中途修改 RTL → coordinator 检测变更 → 决定是否重跑下游 |
| 拥有者模块 | M004 (babel-coord) |
| 输入 | 文件 mtime / SHA256 改变 |
| 输出 | (a) 同 hash → 跳过；(b) 不同 hash → 触发下游重跑或写 pending_approval |
| 验收标准 | E2E 场景：用户手工 vim 改 rtl/uart_tx.sv 后 coord 正确感知 |

---

## 5. 不在范围 (Out of Scope)

| 功能 | 理由 |
|------|------|
| 波形分析 | 由 VSCode 扩展承担（ADR-008） |
| 形式验证 | Phase 4+ 引入 babel-property-prover，MVP 不交付 |
| 物理设计 (PR) | Phase 4+ 引入 babel-layout-planner |
| DFT 扫描链 | Phase 4+ 引入 babel-scan-chain-planner |
| 功耗优化（ICG/UPF） | Phase 4+ 引入 babel-power-optimizer |
| 多设计并发 | MVP 单实例单设计；多设计 Phase 4+ |
| 公网 SaaS 部署 | 威胁模型 = 用户本机（ADR-010）；不防御恶意 agent |

---

## 6. 关联文档

| 路径 | 用途 |
|------|------|
| `architecture_specification.md` | 模块（M00X）定义；本文档 F00X 与之交叉引用 |
| `schemas_seed.md` | 所有 schema 的字段骨架 |
| `user_manual.md` | F001-F016 的用户视角操作 |
| `ADR/` | 关键决策记录 |
| `../idea/design_doc.md` | 上游 idea 文档 |
| `../idea/decisions.md` | 上游 ADR 日志（ADR-001~010） |
