# Common Pitfalls for ic-prd Skill

## PRD 需求模糊

### What happens
PRD 中的需求使用"约"、"大约"、"最好"等模糊词汇，导致后续架构设计无法确定具体目标。

### Why
市场需求文档往往用模糊语言描述期望，直接复制到 PRD 而未量化。

### Fix
每条需求必须量化：
- 替换"约 X GHz" → "≥ X GHz @ TT/1.0V"
- 替换"功耗较低" → "TDP ≤ N W, idle ≤ M W"
- 替换"性能好" → "吞吐量 ≥ N TOPS, 延迟 ≤ M μs"

### Prevention
Phase 12 自动执行 SMART 检查，拒绝模糊指标。

---

## Performance Target 缺少 Corner

### What happens
性能指标仅给出一个数值，未标注工艺角、温度、电压条件。

### Why
PRD 模板中指标表格未强制要求标注条件。

### Fix
所有性能指标格式：
- `{{ VALUE }} @ {{ CORNER }}/{{ VOLTAGE }}`
- 例如：`≥ 2.0 GHz @ TT/1.0V`

### Prevention
使用 `templates/chip_prd_template.md` 的标准格式，自动填充 corner 条件。

---

## Power Budget 未预留 Margin

### What happens
PRD 中各模块功耗预算总和等于 TDP，未预留设计 margin。

### Why
需求方提供的功耗预算往往乐观，未考虑实现风险。

### Fix
模块功耗预算总和 ≤ TDP × 90%
- 总预算 ≤ 0.9 × TDP
- 预留 10% 作为设计 margin

### Prevention
Phase 12 自动检查 Power budget ≤ TDP × 90%。

---

## D2D 带宽计算错误

### What happens
UCIe 带宽需求计算错误，导致后续设计无法满足。

### Why
D2D 带宽计算涉及 lane 数、GT/s、协议开销等多个因素。

### Fix
带宽计算公式：
```
BW = lanes × GT/s × 2 (双工) × payload_ratio
payload_ratio ≈ 0.8 (协议开销)
```

### Prevention
Phase 7 使用 `references/chiplet-standards.md` 的计算模板。

---

## ASIL 等级与安全机制不匹配

### What happens
声明 ASIL-D 等级，但安全机制仅配置 ECC（不足以达到 ASIL-D）。

### Why
安全机制选择需要根据等级组合，而非单一机制。

### Fix
参考 `references/functional-safety.md` 的安全机制矩阵：
- ASIL-D: Lockstep + ECC + Watchdog
- ASIL-C: DMR + ECC
- ASIL-B: ECC + Watchdog

### Prevention
Phase 9 使用安全机制矩阵自动匹配。

---

## REQ ID 冲突

### What happens
多个需求使用相同 REQ ID（如 REQ-COMPUTE-001 出现多次）。

### Why
手动编写需求时未维护 ID 唯一性。

### Fix
REQ ID 编号规则：
- 每个类别（COMPUTE/MEM/IO/PERF...）独立编号
- 格式：REQ-{{ CATEGORY }}-{{ SEQUENCE }}
- 例如：REQ-COMPUTE-001, REQ-COMPUTE-002...

### Prevention
Phase 12 自动检查 REQ ID 唯一性。

---

## Milestone 时间线不合理

### What happens
Tape-out 到 Production Release 间隔过短（如 3 个月），无法完成验证和量产准备。

### Why
PRD 编写者不了解芯片设计周期典型时间。

### Fix
参考时间线：
- RTL Freeze → Tape-out: 3-6 months
- Tape-out → Silicon In: 2-4 months
- Silicon In → Alpha Sample: 1-2 months
- Alpha Sample → Production: 3-6 months

### Prevention
Phase 11 使用标准时间模板，检查间隔合理性。

---

## IP 级 PRD 缺少集成约束

### What happens
IP 级 PRD 仅定义 IP 本身需求，缺少系统集成约束（如时钟来源、复位策略）。

### Why
IP PRD 模板未强调系统级依赖。

### Fix
IP PRD 必须包含 §12 Integration Constraints：
- 时钟源依赖
- 复位策略要求
- 电源域关系
- 总线拓扑约束

### Prevention
使用 `templates/ip_prd_template.md` 的 Integration Constraints 章节。

---

## 标准合规声明不完整

### What happens
PRD 声明符合 UCIe 标准，但未指定具体版本和合规等级。

### Why
标准版本更新频繁，合规等级影响设计要求。

### Fix
合规声明格式：
```markdown
- [ ] UCIe {{ 2.0 / 3.0 }} compliance: {{ Standard / Advanced / Bridge }}
```

### Prevention
Phase 13 使用 `references/chiplet-standards.md` 的合规模板。

---

## Traceability Matrix 缺失

### What happens
PRD 完成后未生成需求追溯矩阵，后续架构设计无法追踪需求来源。

### Why
Phase 13 Traceability Matrix 生成常被跳过。

### Fix
必须生成 `traceability_matrix.md`，关联 REQ ID 与后续文档：
```markdown
| REQ ID | ARCH Ref | MAS Ref | VPlan Ref |
|--------|----------|---------|-----------|
| REQ-COMPUTE-001 | §3.1 | M01-MAS | VP-COMP-01 |
```

### Prevention
Phase 13 作为 MANDATORY 步骤，不可跳过。