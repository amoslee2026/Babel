# ic.mas 常见陷阱

此文件记录芯片微架构文档生成中的常见错误、隐藏问题和容易忽略的事项。

---

## 1. 模块树拆分过早

**What happens:** 在阶段 1 构建模块树时过早拆分，导致叶子模块过多，context 溢出。

**Why:** 芯片设计倾向于 "大模块思维"，架构师习惯把大功能块作为一个模块处理。但在 Agent 自动生成时，过于宽泛的模块会导致单个 MAS.md 内容过多。

**Fix:** 
- 单模块 MAS.md ≤ 500 行
- 超过 500 行时拆分为子模块
- 按 "职责边界" 拆分，不是按 "功能边界"

**Prevention:** 使用 `analyze_spec.sh --report` 定期检查文档长度。

---

## 2. Chiplet 特定章节遗漏

**What happens:** D2D/CDC/PWR 模块缺失必要章节，导致后续集成问题。

**Why:** 芯片设计文档模板偏向传统单芯片设计，缺少 Chiplet 特定内容。

**Fix:** 
- D2D 模块必须包含 `§8 D2D 接口` 章节
- CDC 模块必须包含 `§5.2 CDC 处理` 章节
- PWR 模块必须包含 `§7 电源管理` 章节

**Prevention:** 运行 `analyze_spec.sh` 检查 Chiplet 特定章节。

---

## 3. FSM 状态编码未定义

**What happens:** FSM.md 中状态列表缺失编码值，RTL 实现时使用默认二进制编码导致综合问题。

**Why:** 文档阶段认为 "编码后续定义"，但 Agent 实现时会填默认值。

**Fix:** 
- FSM.md 必须明确定义状态编码
- 提供编码理由（gray/one-hot/binary）
- 标注复位状态

**Prevention:** FSM 模板中 `状态编码` 为必填项。

---

## 4. 数据通路图缺失关键路径标注

**What happens:** datapath.md 中的 Mermaid 图未标注关键路径，无法指导时序优化。

**Why:** Mermaid 默认样式不支持路径标注。

**Fix:** 
- 使用 `linkStyle` 标注关键路径（红色粗线）
- 附带延迟分解表
- 提供优化建议

**Prevention:** 参考 datapath-template.md 的关键路径图示例。

---

## 5. 验证断言遗漏时序检查

**What happens:** verification.md 断言列表仅有协议检查，缺少 Cycle 延迟断言。

**Why:** 功能验证关注协议正确性，忽略延迟正确性。

**Fix:** 
- 添加 Cycle 延迟范围断言（`##[min:max]`）
- 添加精确延迟断言（`##exact_cycles`）
- 添加 CDC 路径延迟断言

**Prevention:** verification 模板 §7 时序验证为必填章节。

---

## 6. DFT 扫描链配置与 RTL 不匹配

**What happens:** DFT.md 定义扫描链配置与实际 RTL 触发器不一致。

**Why:** DFT 文档与 RTL 设计并行开发，缺乏同步机制。

**Fix:** 
- DFT.md 扫描链长度 = RTL 触发器数量
- 定期运行 RTL 综合获取实际触发器数量
- 使用 checkpoint 确保一致性

**Prevention:** Phase 4 (DFT) 在 Phase 1 (RTL) 完成后执行。

---

## 7. frontmatter 状态值不一致

**What happens:** 不同文档使用不同的状态值格式（complete、完成、Complete）。

**Why:** Agent 可能使用中英文混写或大小写不一致。

**Fix:** 
- 统一使用 `status: complete`
- 禁止使用中文 "完成"
- 禁止使用大写 "Complete"

**Prevention:** 运行 `analyze_spec.sh --fix` 自动修复格式问题。

---

## 8. 进度文件缺失导致无法恢复

**What happens:** 生成中断后无法恢复，需从头开始。

**Why:** 未创建 checkpoint 文件。

**Fix:** 
- 每阶段完成时运行 `checkpoint_manager.sh create`
- 中断后运行 `checkpoint_manager.sh restore`

**Prevention:** 在 SKILL.md 中明确 checkpoint 创建时机。

---

## 9. 模块命名不符合规范

**What happens:** 模块名使用中文或特殊字符，导致目录创建失败。

**Why:** Agent 可能直接翻译功能名称。

**Fix:** 
- L1: `M01_英文模块名/` (如 M01_ALU/)
- L2: `M01a_英文子模块名/`
- L3: `M01a1_英文原子模块名/`

**Prevention:** module_tree 生成时使用命名规则检查。

---

## 10. 子 agent 并行数量过多

**What happens:** 同时启动 10+ 子 agent 导致系统资源耗尽。

**Why:** 芯片设计模块数通常远多于软件模块数。

**Fix:** 
- 最大并行数: 6
- 使用依赖分组，避免无关模块并行
- 大模块拆分后控制并行粒度

**Prevention:** SKILL.md 中明确最大并行数限制。

---

## 11. 接口协议引用缺失

**What happens:** MAS.md 中接口定义未引用具体协议标准。

**Why:** 芯片设计大量使用标准协议（AXI/APB/PCIe），但文档中缺少标准引用。

**Fix:**
- 接口章节必须引用协议标准（如 AXI4 Protocol Spec v1.0）
- 时序参数必须符合标准定义
- 信号命名必须遵循标准命名规范

**Prevention:** 使用 references/ic-module-types.md 查询标准文档。

---

## 12. 寄存器地址空间冲突

**What happens:** 不同模块的寄存器地址重叠，导致系统级集成问题。

**Why:** 各模块独立设计时未考虑全局地址空间分配。

**Fix:**
- 使用全局地址分配表
- 模块寄存器地址按 base+offset 计算
- 父模块汇总子模块地址空间

**Prevention:** Phase 4 (父模块上卷) 检查地址空间一致性。