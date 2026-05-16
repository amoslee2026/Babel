---
ip_id: IP-MEM-05-ARBITER
ip_type: memory
ip_class: arbiter
title: Memory IP Arbiter Design Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-MEM-02-MAS
derived_from: []
generated: 2026-04-23T23:00:00+08:00
---

# 访存模块 IP 仲裁器设计模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 仲裁器概述

- **仲裁器名称**: {{ ARBITER_NAME }}
- **输入端口数**: {{ N }} ports
- **输出端口数**: {{ M }} ports
- **仲裁策略**: {{ 固定优先级/轮询/加权轮询 }}
- **QoS支持**: {{ 是/否 }}

---

## 2. 输入端口定义

### 2.1 端口列表

| Port | 来源 | 类型 | 优先级 |
|------|------|------|--------|
| Port0 | {{ SOURCE }} | {{ TYPE }} | {{ PRI }} |
| Port1 | {{ SOURCE }} | {{ TYPE }} | {{ PRI }} |
| Port2 | {{ SOURCE }} | {{ TYPE }} | {{ PRI }} |
| {{ PORT }} | {{ SOURCE }} | {{ TYPE }} | {{ PRI }} |

### 2.2 输入接口信号

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| req_valid | IN | {{ N }} | 请求有效（每port）|
| req_addr | IN | {{ WIDTH }} | 请求地址 |
| req_cmd | IN | {{ N }} | 命令类型 |
| req_data | IN | {{ WIDTH }} | 数据 |
| req_qos | IN | {{ N }} | QoS标记（可选）|
| grant | OUT | {{ N }} | 仲裁授权 |

---

## 3. 仲裁策略

### 3.1 固定优先级

| Port | 优先级 | 说明 |
|------|--------|------|
| Port0 | 最高 | {{ 说明 }} |
| Port1 | 中 | {{ 说明 }} |
| Port2 | 低 | {{ 说明 }} |

**优先级编码逻辑**:
```
Fixed Priority Arbitration:
  if (req_valid[0]) grant = 0
  elif (req_valid[1]) grant = 1
  elif (req_valid[2]) grant = 2
  ...
  else grant = none
```

### 3.2 轮询

**轮询逻辑**:
```
Round-Robin Arbitration:
  last_grant = previous_winner
  search from (last_grant + 1) mod N
  find first valid request
  grant = found_port
```

### 3.3 加权轮询

| Port | 权重 | 说明 |
|------|------|------|
| Port0 | {{ W0 }} | {{ 说明 }} |
| Port1 | {{ W1 }} | {{ 说明 }} |
| Port2 | {{ W2 }} | {{ 说明 }} |

**加权轮询逻辑**:
```
Weighted Round-Robin:
  credit[N] = weight[N]
  each_cycle:
    for each port:
      if (credit[port] > 0 && req_valid[port])
        grant = port
        credit[port] -= 1
        break
    if no grant:
      reset all credits to weights
```

### 3.4 Age-based仲裁

| 参数 | 值 |
|------|---|
| Age位宽 | {{ N }} bits |
| Age更新策略 | {{ 策略 }} |

---

## 4. QoS 支持（如适用）

### 4.1 QoS参数

| 参数 | 值 |
|------|---|
| QoS级别数 | {{ N }} |
| QoS位宽 | {{ N }} bits |

### 4.2 QoS策略

| 级别 | 处理 |
|------|------|
| High | {{ 处理方式 }} |
| Medium | {{ 处理方式 }} |
| Low | {{ 处理方式 }} |

### 4.3 带宽保证

| Port | 最小带宽 | 最大带宽 |
|------|----------|----------|
| {{ PORT }} | {{ BW }} | {{ BW }} |

---

## 5. 请求队列

### 5.1 队列配置

| 参数 | 值 |
|------|---|
| 队列深度 | {{ N }} |
| 队列类型 | FIFO / Priority Queue |
| 超流处理 | {{ 处理方式 }} |

### 5.2 队列管理

| 状态 | 条件 |
|------|------|
| Empty | depth == 0 |
| Almost Full | depth > {{ N }} |
| Full | depth == {{ MAX }} |

---

## 6. 输出调度

### 6.1 输出接口信号

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| out_valid | OUT | 1 | 输出有效 |
| out_addr | OUT | {{ WIDTH }} | 输出地址 |
| out_cmd | OUT | {{ N }} | 输出命令 |
| out_data | OUT | {{ WIDTH }} | 输出数据 |
| out_port_id | OUT | {{ N }} | 来源Port ID |
| out_ready | IN | 1 | 下级就绪 |

### 6.2 调度逻辑

```
Output Scheduling:
  if (queue_not_empty && out_ready)
    pop from queue
    drive output signals
    assert out_valid
```

---

## 7. 死锁防护

### 7.1 死锁检测

| 条件 | 检测方法 |
|------|----------|
| 长时间等待 | {{ TIMEOUT }} cycles |
| 优先级反转 | {{ 检测方法 }} |

### 7.2 死锁预防

| 策略 | 描述 |
|------|------|
| Timeout | {{ 策略描述 }} |
| Priority boost | {{ 策略描述 }} |
| {{ STRATEGY }} | {{ DESC }} |

---

## 8. 性能分析

### 8.1 延迟分析

| 操作 | 延迟 |
|------|------|
| 仲裁决策 | {{ N }} cycles |
| 队队入队 | {{ N }} cycles |
| 队队出队 | {{ N }} cycles |
| 总延迟 | {{ N }} cycles |

### 8.2 吞吐量分析

| 场景 | 吞吐量 |
|------|--------|
| 单Port活跃 | {{ N }} req/cycle |
| 所有Port活跃 | {{ N }} req/cycle |
| {{ SCENARIO }} | {{ RATE }} |

---

## 9. 时序图

### 9.1 仲裁时序

```wavejson
{
  signal: [
    {name: 'clk', wave: 'p.....'},
    {name: 'req0_valid', wave: '01.0..'},
    {name: 'req1_valid', wave: '0.1.0.'},
    {name: 'req2_valid', wave: '01.0..'},
    {name: 'grant', wave: 'x.=.x.', data: ['G0', 'G1']},
    {name: 'out_valid', wave: '0..10.'},
  ],
  head: {text: 'Arbitration Timing'}
}
```

---

## 10. Quality Checklist

- [ ] 输入端口数明确
- [ ] 输出端口数明确
- [ ] 仲裁策略明确
- [ ] 优先级定义明确
- [ ] QoS支持明确（如适用）
- [ ] 队列配置明确
- [ ] 死锁防护策略明确
- [ ] 延迟分析完成
- [ ] 吞吐量分析完成
- [ ] 时序图完整