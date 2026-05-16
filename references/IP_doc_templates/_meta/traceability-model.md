# IP 文档追溯模型

**Version**: 1.0  
**Generated**: 2026-04-23

## 1. 追溯链架构

### 1.1 四向追溯链

```
PRD Requirement ──► Arch Decision (ADR) ──► MAS Section ──► VPlan Testpoint ──► Test Case ──► Coverage
      │                   │                     │                  │               │
      └───────────────────┴─────────────────────┴──────────────────┴───────────────┘
                           双向可追溯
```

### 1.2 IP 文档追溯位置

IP 文档位于 MAS → VPlan 的中间层：

```
DOC-D3-01-MAS (模块级)
      │
      ▼
IP-COMP-XX-* 或 IP-MEM-XX-* (IP级)
      │
      ▼
Block/Sub-block 级文档
```

## 2. Frontmatter 追溯字段

### 2.1 向上追溯

```yaml
derived_from:              # 上游来源
  - REQ-<ID>               # PRD 需求ID
  - ADR-<ID>               # 架构决策ID
parent_doc: <Doc_ID>       # 父文档ID
```

### 2.2 向下追溯

```yaml
children:                  # 下派文档
  - IP-<ID>-BLK-<Name>     # Block级文档
testpoints:                # 关联验证点
  - TP-<ID>                # Testpoint ID列表
```

## 3. 追溯矩阵 (RTM)

### 3.1 矩阵结构

| PRD Req | ADR | MAS Section | IP Doc | Testpoint | Test Case | Coverage |
|---------|-----|-------------|--------|-----------|-----------|----------|
| REQ-001 | ADR-01 | §2.1 | IP-COMP-02-§3 | TP-001 | TC-001 | 100% |

### 3.2 矩阵维护要求

- 覆盖率目标：≥ 95%
- 自动化工具：DOORS / Jama / Polarion
- 检查频率：每个 milestone

## 4. IP 级追溯示例

### 4.1 计算IP追溯链

```
REQ-PERF-001 (IPC ≥ 2.0)
    └──► ADR-ARCH-01 (超标量设计)
          └──► MAS §3.2 (流水线设计)
                └──► IP-COMP-03-PIPELINE §4 (5-stage pipeline)
                      └──► TP-PIPE-001 (流水线吞吐测试)
                            └──► TC-PERF-001
                                  └──► Coverage: IPC=2.1
```

### 4.2 访存IP追溯链

```
REQ-MEM-001 (L2延迟 ≤ 10 cycles)
    └──► ADR-ARCH-02 (Write-back策略)
          └──► MAS §4.3 (Cache设计)
                └──► IP-MEM-04-CACHE §5 (L2 Cache实现)
                      └──► TP-CACHE-001 (访问延迟测试)
                            └──► TC-LAT-001
                                  └──► Coverage: Lat=8 cycles
```

## 5. 追溯状态定义

| 状态 | 符号 | 说明 |
|------|------|------|
| Linked | ✓ | 已建立追溯 |
| Pending | ○ | 待建立 |
| Broken | ✗ | 链接断开 |
| Waived | W | 已豁免（有正当理由）|

## 6. 追溯完整性检查

### 6.1 检查点

- [ ] 每条 PRD 需求有 MAS 章节
- [ ] 每个 MAS 章节有 IP 文档细化
- [ ] 每个 IP 功能点有 Testpoint
- [ ] 每个 Testpoint 有 Test Case
- [ ] 每个 Test Case 有 Coverage 结果

### 6.2 断链处理

| 断链类型 | 处理方式 |
|----------|----------|
| PRD→MAS缺失 | 新增MAS章节或标记Waived |
| MAS→Testpoint缺失 | 新增Testpoint |
| Testpoint→TestCase缺失 | 标记Pending，分配Owner |
| TestCase→Coverage缺失 | 运行测试获取结果 |

## 7. 变更影响分析

### 7.1 变更传播规则

```
变更源 ──► 影响范围
PRD变更 ──► Arch → MAS → IP → VPlan
IP变更 ──► MAS → VPlan → Test Case
Testpoint变更 ──► Test Case → Coverage
```

### 7.2 影响评估表

| 变更类型 | 影响评估模板 |
|----------|--------------|
| 功能新增 | 新增追溯链 |
| 功能修改 | 更新所有下游 |
| 功能删除 | 标记deprecated，更新RTM |
| 参数调整 | 更新验证边界 |

## 8. 工具集成

### 8.1 推荐工具

| 工具 | 用途 |
|------|------|
| DOORS | 需求管理 |
| Jama Connect | 追溯矩阵 |
| Polarion | ALM集成 |
| Git + YAML | 文档版本控制 |

### 8.2 自动化脚本

```bash
# 检查追溯完整性
check_traceability.py --ip-id IP-COMP-02

# 生成RTM报告
generate_rtm.py --project MyChip --output rtm.csv

# 变更影响分析
impact_analysis.py --change REQ-PERF-001
```