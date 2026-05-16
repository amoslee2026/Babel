---
ip_id: IP-MEM-04-CACHE
ip_type: memory
ip_class: cache
title: Memory IP Cache Design Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-MEM-02-MAS
derived_from: []
generated: 2026-04-23T23:00:00+08:00
---

# 访存模块 IP Cache 设计模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. Cache 概述

- **Cache名称**: {{ CACHE_NAME }}
- **Cache层级**: L1 / L2 / L3 / LLC
- **容量**: {{ CAPACITY }} KB/MB
- **Line Size**: {{ SIZE }} Bytes
- **Associativity**: {{ WAY }}-way set-associative
- **替换策略**: {{ POLICY }}
- **写策略**: Write-back / Write-through

---

## 2. Cache 组织

### 2.1 地址分解

```mermaid
graph LR
    ADDR[地址 {{ WIDTH }} bits]
    ADDR --> TAG[Tag {{ TAG_BITS }} bits]
    ADDR --> SET[Set Index {{ SET_BITS }} bits]
    ADDR --> OFFSET[Offset {{ OFFSET_BITS }} bits]
```

| 字段 | 位宽 | 用途 |
|------|------|------|
| Tag | {{ N }} bits | 标签匹配 |
| Set Index | {{ N }} bits | Set选择 |
| Byte Offset | {{ N }} bits | Line内偏移 |

### 2.2 Set 结构

| 参数 | 值 |
|------|---|
| Set总数 | {{ N }} |
| 每Set Way数 | {{ N }} |
| 每Line数据位宽 | {{ N }} bits |

---

## 3. Tag RAM 设计

### 3.1 Tag 存储参数

| 参数 | 值 |
|------|---|
| 容量 | {{ N }} entries |
| 每Entry位宽 | {{ N }} bits |
| 端口配置 | {{ N }}R {{ M }}W |
| 类型 | SRAM / Register File |
| Bank数 | {{ N }} |

### 3.2 Tag Entry 结构

| 字段 | 位宽 | 功能 |
|------|------|------|
| tag | {{ N }} | 地址标签 |
| valid | 1 | 有效位 |
| dirty | 1 | 脏位（Write-back）|
| coherence_state | {{ N }} | 一致性状态（如适用）|
| {{ FIELD }} | {{ WIDTH }} | {{ FUNC }} |

### 3.3 Tag 匹配逻辑

```
Tag Match Process:
1. 使用 Set Index 选择 Set
2. 读取所有 Way 的 Tag
3. 比较每个 Tag 与请求 Tag
4. 检查 Valid 位
5. 输出命中 Way (hit_way) 或 miss
```

---

## 4. Data RAM 设计

### 4.1 Data 存储参数

| 参数 | 值 |
|------|---|
| 容量 | {{ CAPACITY }} KB |
| Line Size | {{ SIZE }} Bytes |
| Bank数 | {{ N }} |
| 端口配置 | {{ N }}R {{ M }}W |
| 类型 | SRAM |

### 4.2 Data 访问流程

```
Data Read:
1. Tag匹配确定 hit_way
2. 使用 Set Index + hit_way 选择 Line
3. 使用 Byte Offset 选择数据
4. 输出数据

Data Write:
1. 确定 target_way (hit or replacement)
2. 使用 Set Index + target_way 选择 Line
3. 使用 Byte Offset + Byte Mask 写入
4. 更新 Dirty 位
```

---

## 5. 替换策略

### 5.1 替换算法

| 算法 | 描述 |
|------|------|
| {{ POLICY }} | {{ DESC }} |

### 5.2 替换状态维护

| Way | 状态 | 用途 |
|-----|------|------|
| {{ WAY }} | {{ STATE }} | {{ PURPOSE }} |

### 5.3 替换流程

```
Replacement Process:
1. Tag匹配结果为 miss
2. 查找替换候选 Way
3. 如果候选 Way 为 Dirty，触发 Write-back
4. 发起 Refill 请求
5. 数据返回后填充候选 Way
6. 更新 Tag + Valid + Dirty
```

---

## 6. 写策略

### 6.1 Write-back 流程

| 步骤 | 动作 |
|------|------|
| Write Hit | 更新 Data RAM + 设置 Dirty |
| Write Miss | 可能 Write-allocate 或 No-write-allocate |
| Write-back | Dirty Line驱逐时写回下一级 |

### 6.2 Write-through 流程

| 步骤 | 动作 |
|------|------|
| Write Hit | 更新 Data RAM + 立即写下一级 |
| Write Miss | 直接写下一级（不分配）|

---

## 7. Refill 流程

### 7.1 Refill 请求生成

| 字段 | 来源 |
|------|------|
| 地址 | 请求地址 |
| 类型 | Read / Write-back |

### 7.2 Refill 数据处理

```
Refill Data Handling:
1. 接收返回数据
2. 填充 Data RAM
3. 更新 Tag RAM
4. 设置 Valid 位
5. 清除 Dirty 位（新数据）
6. 返回数据给请求者
```

---

## 8. 命中/缺失处理

### 8.1 Hit 处理时序

```wavejson
{
  signal: [
    {name: 'clk', wave: 'p.....'},
    {name: 'req_valid', wave: '01.0..'},
    {name: 'tag_match', wave: '0..10.'},
    {name: 'data_rd', wave: '0..10.'},
    {name: 'rsp_valid', wave: '0...10'},
  ]
}
```

### 8.2 Miss 处理时序

```wavejson
{
  signal: [
    {name: 'clk', wave: 'p........'},
    {name: 'req_valid', wave: '01.0.....'},
    {name: 'tag_match', wave: '0..0.....'},
    {name: 'miss_detect', wave: '0..10....'},
    {name: 'refill_req', wave: '0...10...'},
    {name: 'refill_rsp', wave: '0.....10.'},
    {name: 'fill_done', wave: '0......10'},
    {name: 'rsp_valid', wave: '0.......1'},
  ]
}
```

---

## 9. 一致性集成（如适用）

### 9.1 状态维护

| Way | 状态位 | 用途 |
|-----|--------|------|
| {{ WAY }} | MESI/MOESI | 一致性协议 |

### 9.2 协议交互

| 事件 | 响应 |
|------|------|
| Read Hit (S/E/M) | 直接返回数据 |
| Read Miss | 发起 Read 请求 |
| Write Hit (M) | 更新数据 |
| Write Hit (S/E) | 发起 Upgrade |
| Eviction (M) | Write-back |

---

## 10. ECC 设计

### 10.1 ECC 覆盖

| 对象 | ECC类型 | 粒度 |
|------|---------|------|
| Data RAM | SEC-DED | Per Line |
| Tag RAM | Parity | Per Entry |

### 10.2 错误处理

| 错误类型 | 检测 | 响应 |
|----------|------|------|
| Single-bit Data | ECC纠正 | 硬件纠正，计数 |
| Multi-bit Data | ECC检测 | 中断，软件处理 |
| Tag Parity | 检测 | 重读或中断 |

---

## 11. 性能参数

### 11.1 延迟与带宽

| 操作 | 延迟 | 带宽 |
|------|------|------|
| Read Hit | {{ N }} cycles | {{ BW }} GB/s |
| Write Hit | {{ N }} cycles | {{ BW }} GB/s |
| Miss penalty | {{ N }} cycles | — |

### 11.2 命中率预估

| 工作负载 | 命中率 |
|----------|--------|
| {{ WORKLOAD }} | {{ RATE }} |

---

## 12. Quality Checklist

- [ ] Cache参数完整（容量、Line Size、Associativity）
- [ ] 地址分解正确（Tag/Set/Offset）
- [ ] Tag RAM参数明确
- [ ] Data RAM参数明确
- [ ] 替换策略明确
- [ ] 写策略明确
- [ ] Refill流程完整
- [ ] 命中/缺失时序图完整
- [ ] 一致性状态维护明确（如适用）
- [ ] ECC配置明确
- [ ] 性能参数明确