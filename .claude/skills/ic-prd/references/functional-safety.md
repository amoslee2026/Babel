# 功能安全规范参考

## ISO 26262 概述

ISO 26262 是汽车功能安全标准，定义 ASIL（Automotive Safety Integrity Level）等级。

### ASIL 等级定义

| ASIL | 描述 | 安全要求 |
|------|------|----------|
| QM | Quality Management | 无特殊安全要求 |
| ASIL-A | 最低安全等级 | 基础安全措施 |
| ASIL-B | 中低等级 | 适度安全措施 |
| ASIL-C | 中高等级 | 较高安全措施 |
| ASIL-D | 最高等级 | 最严格安全措施 |

### ASIL-D 关键指标

| Metric | 目标值 | 描述 |
|--------|--------|------|
| SPFM | ≥ 99% | 单点故障度量 |
| LFM | ≥ 90% | 潜在故障度量 |
| PMHF | ≤ 10 FIT | 硬件故障概率 |

## Safety Mechanisms

### 常见安全机制

| Mechanism | 适用等级 | 描述 |
|-----------|----------|------|
| Lockstep | ASIL-D | 双核锁步运行 |
| ECC | ASIL-B/C/D | 错误检测与纠正码 |
| DMR | ASIL-B/C | 双模冗余 |
| TMR | ASIL-C/D | 三模冗余 |
| Watchdog | ASIL-A/B | 程序执行监控 |
| CRC | ASIL-A/B | 数据完整性检查 |
| Safe State | 所有等级 | 安全状态机 |

### 安全机制选择矩阵

| 功能类型 | ASIL-A | ASIL-B | ASIL-C | ASIL-D |
|----------|--------|--------|--------|--------|
| 计算 | ECC | ECC + Watchdog | DMR | Lockstep |
| 存储 | ECC | ECC | ECC + 备份 | ECC + DMR |
| 通信 | CRC | CRC | CRC + ACK | CRC + 双通道 |
| 控制 | Watchdog | Watchdog | TMR | TMR + Lockstep |

## 软错误率指标

| Metric | 描述 | 典型目标 |
|--------|------|----------|
| FIT | 时间故障率 | ≤ 10 FIT (ASIL-D) |
| MTTF | 平均故障时间 | ≥ 10^6 hours |

## PRD 中功能安全章节模板

```markdown
## 11. Functional Safety

| REQ ID | Statement |
|---|---|
| REQ-FS-001 | ASIL level: {{ A / B / C / D / QM }} |
| REQ-FS-002 | Standard: ISO 26262 : 2018 |
| REQ-FS-003 | SPFM ≥ {{ 99 }}%, LFM ≥ {{ 90 }}%, PMHF ≤ {{ 10 }} FIT |
| REQ-FS-004 | Safety mechanisms: {{ lockstep, ECC, dual-modular redundancy }} |
| REQ-FS-005 | 跨 die 级联故障分析已完成 → DOC-D7-01-SEC §N |
```

## IEC 61508 参考

工业应用的功能安全标准，定义 SIL 等级：

| SIL | 对应 ASIL | 描述 |
|-----|-----------|------|
| SIL-1 | ASIL-A | 最低等级 |
| SIL-2 | ASIL-B | 中等等级 |
| SIL-3 | ASIL-C/D | 高等级 |
| SIL-4 | - | 最高等级（汽车无对应） |

## 安全生命周期

```
概念阶段 → 系统设计 → 硬件设计 → 软件设计 → 生产 → 运行 → 维修 → 退役
```

每个阶段有相应的安全活动和文档要求。