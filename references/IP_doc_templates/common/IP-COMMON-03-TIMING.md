---
ip_id: IP-COMMON-03-TIMING
ip_type: common
ip_class: timing
title: IP Timing Specification Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-COMP-02-MAS / IP-MEM-02-MAS
derived_from: []
generated: 2026-04-23T23:00:00+08:00
---

# IP 时序规范模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 时序概述

- **目标频率**: {{ FREQ }} MHz
- **工艺节点**: {{ PROCESS_NODE }}
- **工作电压**: {{ V }} V
- **温度范围**: {{ MIN }}°C to {{ MAX }}°C

---

## 2. 时钟域定义

### 2.1 时钟域列表

| 时钟域 | 频率 | 相位关系 | 来源 |
|--------|------|----------|------|
| clk_main | {{ FREQ }} | 0° | PLL |
| clk_mem | {{ FREQ }} | {{ PHASE }} | {{ SOURCE }} |
| clk_slow | {{ FREQ }} | Independent | Oscillator |
| {{ DOMAIN }} | {{ FREQ }} | {{ PHASE }} | {{ SOURCE }} |

### 2.2 时钟规格

| 参数 | 值 |
|------|---|
| Period | {{ N }} ns |
| Duty cycle | 50% (typ) |
| Jitter | {{ N }} ps |
| Skew (intra-domain) | {{ N }} ps |

---

## 3. 输入时序要求

### 3.1 Setup/Hold 时间

| 信号 | 时钟域 | Setup | Hold | 说明 |
|------|--------|-------|------|------|
| req_valid | clk_main | {{ N }} ps | {{ N }} ps | {{ 说明 }} |
| req_addr | clk_main | {{ N }} ps | {{ N }} ps | {{ 说明 }} |
| req_data | clk_main | {{ N }} ps | {{ N }} ps | {{ 说明 }} |
| {{ SIGNAL }} | {{ DOMAIN }} | {{ SETUP }} | {{ HOLD }} | {{ DESC }} |

### 3.2 时序图

```wavejson
{
  signal: [
    {name: 'clk', wave: 'p.....'},
    {name: 'data_in', wave: 'x.=.x', data: ['D']},
    {name: 'setup', wave: '0.1..0', node: '.s'},
    {name: 'hold', wave: '0..10.', node: '..h'},
  ],
  edge: ['s<->h Setup+Hold'],
  head: {text: 'Input Timing'}
}
```

---

## 4. 输出时序规格

### 4.1 输出延迟

| 信号 | 时钟域 | Valid延迟 | 说明 |
|------|--------|-----------|------|
| rsp_valid | clk_main | {{ N }} ps | 从时钟上升沿 |
| rsp_data | clk_main | {{ N }} ps | 从时钟上升沿 |
| {{ SIGNAL }} | {{ DOMAIN }} | {{ DELAY }} | {{ DESC }} |

### 4.2 输出时序图

```wavejson
{
  signal: [
    {name: 'clk', wave: 'p.....'},
    {name: 'data_out', wave: 'x.=.x', data: ['D']},
    {name: 'valid_delay', wave: '0.1..0', node: '.v'},
  ],
  head: {text: 'Output Timing'}
}
```

---

## 5. CDC 时序规范

### 5.1 CDC 路径列表

| 路径ID | 源域 | 目标域 | 同步方式 | MTBF目标 |
|--------|------|--------|----------|----------|
| CDC001 | clk_slow | clk_main | 2-FF | {{ N }} years |
| CDC002 | clk_mem | clk_main | Async FIFO | {{ N }} years |
| {{ CDC }} | {{ SRC }} | {{ DST }} | {{ METHOD }} | {{ MTBF }} |

### 5.2 同步器规格

| 类型 | 参数 | 值 |
|------|------|---|
| 2-FF Synchronizer | FF数 | 2 |
| | MTBF公式 | {{ FORMULA }} |
| Async FIFO | 深度 | {{ N }} |
| | 计算方式 | {{ METHOD }} |
| Handshake | 延迟 | {{ N }} cycles |

### 5.3 CDC 约束 (SDC)

```sdc
# False path for CDC
set_false_path -from [get_clocks clk_slow] -to [get_clocks clk_main]

# Multi-cycle path for synchronizer
set_multicycle_path 2 -setup -from [get_cells sync_ff1] -to [get_cells sync_ff2]

# Async FIFO constraint
set_max_delay {{ N }} -from [get_cells fifo_wr_ptr] -to [get_cells fifo_rd_ptr_sync]
```

---

## 6. 关键路径分析

### 6.1 关键路径列表

| 路径 | 起点 | 终点 | 延迟 | Slack |
|------|------|------|------|-------|
| PATH001 | {{ START }} | {{ END }} | {{ N }} ns | {{ N }} ps |
| PATH002 | {{ START }} | {{ END }} | {{ N }} ns | {{ N }} ps |
| {{ PATH }} | {{ START }} | {{ END }} | {{ DELAY }} | {{ SLACK }} |

### 6.2 延迟分解

| 路径 | Logic | Wire | Cell delay | Total |
|------|--------|------|------------|-------|
| PATH001 | {{ N }} ns | {{ N }} ns | {{ N }} ns | {{ N }} ns |

---

## 7. Pipeline 平衡

### 7.1 各Stage延迟

| Stage | Logic延迟 | Register延迟 | 总延迟 |
|-------|-----------|--------------|--------|
| Stage1 | {{ N }} ns | {{ N }} ns | {{ N }} ns |
| Stage2 | {{ N }} ns | {{ N }} ns | {{ N }} ns |
| Stage3 | {{ N }} ns | {{ N }} ns | {{ N }} ns |

### 7.2 平衡策略

| 策略 | 说明 |
|------|------|
| {{ STRATEGY }} | {{ DESC }} |

---

## 8. PVT 角点分析

### 8.1 角点定义

| 角点 | 电压 | 温度 | Process |
|------|------|------|---------|
| SS | {{ V }} V | {{ T }}°C | Slow |
| TT | {{ V }} V | {{ T }}°C | Typical |
| FF | {{ V }} V | {{ T }}°C | Fast |
| {{ CORNER }} | {{ V }} | {{ T }} | {{ PROC }} |

### 8.2 各角点频率

| 角点 | 最大频率 |
|------|----------|
| SS | {{ FREQ }} MHz |
| TT | {{ FREQ }} MHz |
| FF | {{ FREQ }} MHz |

---

## 9. 时序约束文件 (SDC)

```sdc
# Clock definitions
create_clock -period {{ N }} [get_ports clk]
create_generated_clock -divide_by {{ N }} [get_pins pll/div] -source [get_ports clk_ref]

# Input/Output delays
set_input_delay -max {{ N }} [get_ports req_*]
set_input_delay -min {{ N }} [get_ports req_*]
set_output_delay -max {{ N }} [get_ports rsp_*]
set_output_delay -min {{ N }} [get_ports rsp_*]

# Clock uncertainty
set_clock_uncertainty {{ N }} [get_clocks clk]

# False paths
set_false_path -from [get_ports rst_n]

# Multi-cycle paths
set_multicycle_path {{ N }} -setup -through [get_cells *slow*]
```

---

## 10. Quality Checklist

- [ ] 时钟域定义完整
- [ ] 输入时序要求明确
- [ ] 输出时序规格明确
- [ ] CDC路径识别完整
- [ ] 同步器规格明确
- [ ] 关键路径分析完成
- [ ] Pipeline平衡完成
- [ ] PVT角点分析完成
- [ ] SDC约束完整