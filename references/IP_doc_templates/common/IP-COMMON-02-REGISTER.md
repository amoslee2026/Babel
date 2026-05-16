---
ip_id: IP-COMMON-02-REGISTER
ip_type: common
ip_class: register
title: IP Register Specification Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-COMP-02-MAS / IP-MEM-02-MAS
derived_from: []
references: [IEEE 1685 IP-XACT, SystemRDL]
generated: 2026-04-23T23:00:00+08:00
---

# IP 寄存器规范模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 寄存器映射概述

- **基地址**: {{ BASE_ADDR }}
- **地址范围**: {{ RANGE }} ({{ SIZE }} bytes)
- **寄存器总数**: {{ NUM }}
- **地址对齐**: {{ N }}-byte aligned

---

## 2. 寄存器汇总表

| 地址偏移 | 名称 | 位宽 | 访问类型 | 复位值 | 描述 |
|----------|------|------|----------|--------|------|
| 0x000 | CTRL | 32 | RW | 0x00000000 | 控制寄存器 |
| 0x004 | STATUS | 32 | RO | 0x00000000 | 状态寄存器 |
| 0x008 | {{ REG }} | {{ W }} | {{ ACC }} | {{ RST }} | {{ DESC }} |

---

## 3. 寄存器详细定义

### 3.1 CTRL (Offset: 0x000)

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | ENABLE | RW | 0 | 模块使能 |
| [1] | RESET | RW | 0 | 软复位（self-clearing）|
| [2] | START | RW | 0 | 启动操作（self-clearing）|
| [7:3] | MODE | RW | 0 | 工作模式选择 |
| [15:8] | THRESHOLD | RW | 0x00 | 阈值配置 |
| [31:16] | Reserved | RO | 0x0000 | 保留 |

**字段说明**:
- ENABLE: 置1使能模块，置0禁用
- RESET: 置1触发软复位，自动清零
- MODE: 工作模式编码（见下表）

**MODE编码**:
| 值 | 模式 |
|----|------|
| 0x00 | Normal |
| 0x01 | Low-power |
| 0x02 | Debug |
| 0x03 | Test |

### 3.2 STATUS (Offset: 0x004)

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | READY | RO | 0 | 就绪状态 |
| [1] | BUSY | RO | 0 | 操作进行中 |
| [2] | ERROR | RO | 0 | 错误标志 |
| [3] | DONE | RO | 0 | 操作完成 |
| [7:4] | STATE | RO | 0x0 | FSM状态编码 |
| [31:8] | Reserved | RO | 0x000000 | 保留 |

**字段说明**:
- READY: 置1表示模块初始化完成
- BUSY: 置1表示正在处理请求
- ERROR: 置1表示发生错误
- DONE: 置1表示上次操作完成

### 3.3 {{ REG_NAME }} (Offset: {{ OFFSET }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| {{ BITS }} | {{ FIELD }} | {{ ACC }} | {{ RST }} | {{ DESC }} |

---

## 4. 访问类型定义

| 类型 | 缩写 | 描述 |
|------|------|------|
| Read-Write | RW | 可读可写 |
| Read-Only | RO | 只读 |
| Write-Only | WO | 只写，读返回0 |
| Read-Clear | RC | 读后自动清零 |
| Write-Clear | W1C | 写1清零，写0无效 |
| Write-Set | W1S | 写1置位，写0无效 |
| Self-Clearing | SC | 写后自动清零（脉冲）|
| {{ TYPE }} | {{ ABBR }} | {{ DESC }} |

---

## 5. 中断寄存器

### 5.1 INT_ENABLE (Offset: 0x{{ N }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | EN_ERROR | RW | 0 | 错误中断使能 |
| [1] | EN_DONE | RW | 0 | 完成中断使能 |
| [2] | EN_THRESH | RW | 0 | 阈值中断使能 |
| [31:3] | Reserved | RO | 0 | 保留 |

### 5.2 INT_STATUS (Offset: 0x{{ N }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | ST_ERROR | W1C | 0 | 错误中断状态 |
| [1] | ST_DONE | W1C | 0 | 完成中断状态 |
| [2] | ST_THRESH | W1C | 0 | 阈值中断状态 |
| [31:3] | Reserved | RO | 0 | 保留 |

---

## 6. 性能计数器寄存器

### 6.1 PERF_CNT0 (Offset: 0x{{ N }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [63:0] | COUNT | RC | 0x0000000000000000 | 性能计数器0 |

**计数器用途**: {{ 用途描述 }}

### 6.2 PERF_CNT1 (Offset: 0x{{ N }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [63:0] | COUNT | RC | 0x0000000000000000 | 性能计数器1 |

---

## 7. 错误寄存器

### 7.1 ERR_STATUS (Offset: 0x{{ N }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | ERR_TYPE0 | W1C | 0 | 错误类型0 |
| [1] | ERR_TYPE1 | W1C | 0 | 错误类型1 |
| [7:2] | ERR_CODE | RO | 0x00 | 错误编码 |
| [15:8] | ERR_ADDR | RO | 0x00 | 错误地址 |
| [31:16] | Reserved | RO | 0 | 保留 |

### 7.2 ERR_INJ (Offset: 0x{{ N }}) - Debug Only

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | INJ_ENABLE | RW | 0 | 错误注入使能 |
| [7:1] | INJ_TYPE | RW | 0x00 | 注入类型 |

---

## 8. 地址映射规则

### 8.1 地址对齐

| 寄存器位宽 | 对齐要求 |
|------------|----------|
| 8-bit | 1-byte |
| 16-bit | 2-byte |
| 32-bit | 4-byte |
| 64-bit | 8-byte |

### 8.2 地址间隔

| 配置 | 地址间隔 |
|------|----------|
| 紧凑 | 4 bytes |
| 预留扩展 | 8-16 bytes |
| Bank对齐 | {{ N }} bytes |

---

## 9. IP-XACT 元数据

### 9.1 XML Schema

```xml
<ipxact:memoryMap>
  <ipxact:name>reg_map</ipxact:name>
  <ipxact:addressBlock>
    <ipxact:name>config</ipxact:name>
    <ipxact:baseAddress>0x{{ BASE }}</ipxact:baseAddress>
    <ipxact:range>0x{{ RANGE }}</ipxact:range>
    <ipxact:register>
      <ipxact:name>CTRL</ipxact:name>
      <ipxact:addressOffset>0x000</ipxact:addressOffset>
      <ipxact:size>32</ipxact:size>
      <ipxact:access>read-write</ipxact:access>
      <ipxact:reset>
        <ipxact:value>0x00000000</ipxact:value>
      </ipxact:reset>
      <ipxact:field>
        <ipxact:name>ENABLE</ipxact:name>
        <ipxact:bitOffset>0</ipxact:bitOffset>
        <ipxact:bitWidth>1</ipxact:bitWidth>
        <ipxact:access>read-write</ipxact:access>
      </ipxact:field>
    </ipxact:register>
  </ipxact:addressBlock>
</ipxact:memoryMap>
```

---

## 10. 软件访问指南

### 10.1 初始化序列

```c
// 1. 复位模块
CTRL = 0x00000002;  // RESET bit
while (STATUS.RESET_ACTIVE) {}

// 2. 配置参数
CTRL = 0x00000008;  // MODE=Normal

// 3. 使能模块
CTRL = 0x00000001;  // ENABLE bit

// 4. 使能中断
INT_ENABLE = 0x00000003;

// 5. 等待就绪
while (!STATUS.READY) {}
```

### 10.2 常用操作

```c
// 启动操作
CTRL.START = 1;

// 等待完成（轮询）
while (!STATUS.DONE) {}

// 等待完成（中断）
// ISR中检查 STATUS.DONE

// 清除状态
STATUS.DONE = 1;  // W1C
```

---

## 11. Quality Checklist

- [ ] 所有寄存器地址明确
- [ ] 所有字段位宽明确
- [ ] 所有复位值明确
- [ ] 访问类型正确标注
- [ ] Reserved字段为RO、复位0
- [ ] Self-clearing字段标注
- [ ] 中断寄存器完整
- [ ] 性能计数器完整（如适用）
- [ ] 错误寄存器完整
- [ ] IP-XACT元数据完整
- [ ] 软件访问指南完整