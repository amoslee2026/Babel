---
ip_id: IP-COMMON-05-DFT
ip_type: common
ip_class: dft
title: IP DFT Specification Template
version: 0.1-template
status: template
tier: 0
domain: Test
owner: TBD
parent_doc: IP-COMP-02-MAS / IP-MEM-02-MAS
derived_from: []
references: [IEEE 1149.1 JTAG, IEEE 1687 IJTAG, IEEE 1838 Die Wrapper]
generated: 2026-04-23T23:00:00+08:00
---

# IP DFT 规范模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. DFT 概述

- **IP名称**: {{ IP_NAME }}
- **DFT策略**: {{ Scan + BIST + JTAG }}
- **故障覆盖率目标**: ≥ {{ N }} % (Stuck-at)
- **测试时间目标**: ≤ {{ N }} ms

---

## 2. Scan 设计

### 2.1 Scan 链配置

| Scan Chain | 长度 | 覆盖模块 | 端口 |
|------------|------|----------|------|
| SCAN_CHAIN0 | {{ N }} cells | {{ MODULE }} | scan_in0 → scan_out0 |
| SCAN_CHAIN1 | {{ N }} cells | {{ MODULE }} | scan_in1 → scan_out1 |
| {{ CHAIN }} | {{ LEN }} | {{ MODULE }} | {{ PORT }} |

### 2.2 Scan 控制信号

| 信号 | 方向 | 功能 |
|------|------|------|
| scan_enable | IN | Scan模式使能 |
| scan_in[N] | IN | Scan输入 |
| scan_out[N] | OUT | Scan输出 |
| scan_clock | IN | Scan时钟 |

### 2.3 Scan 插入策略

| 策略 | 说明 |
|------|------|
| Lock-up Latch | {{ 说明 }} |
| Scan Compression | {{ 说明（如采用）}} |
| {{ STRATEGY }} | {{ DESC }} |

---

## 3. JTAG 接口

### 3.1 TAP Controller

| 信号 | 方向 | 功能 |
|------|------|------|
| tck | IN | Test Clock |
| tms | IN | Test Mode Select |
| tdi | IN | Test Data In |
| tdo | OUT | Test Data Out |
| trst_n | IN | Test Reset |

### 3.2 JTAG 指令集

| 指令 | 编码 | 功能 |
|------|------|------|
| EXTEST | 0x00 | 外部测试 |
| SAMPLE/PRELOAD | 0x01 |采样/预载 |
| BYPASS | 0xFF | 直通 |
| INTEST | {{ CODE }} | 内部测试 |
| USER0 | {{ CODE }} | 用户定义0 |
| {{ INST }} | {{ CODE }} | {{ FUNC }} |

### 3.3 JTAG 状态机

```mermaid
stateDiagram-v2
    [*] --> Test-Logic-Reset
    Test-Logic-Reset --> Run-Test/Idle
    Run-Test/Idle --> Select-DR
    Select-DR --> Capture-DR
    Capture-DR --> Shift-DR
    Shift-DR --> Exit1-DR
    Exit1-DR --> Pause-DR
    Pause-DR --> Exit2-DR
    Exit2-DR --> Update-DR
    Update-DR --> Run-Test/Idle
```

---

## 4. IJTAG (IEEE 1687)

### 4.1 SIB (Segment Insertion Bit) 配置

| SIB | 覆盖模块 | 描述 |
|-----|----------|------|
| SIB0 | {{ MODULE }} | {{ DESC }} |
| SIB1 | {{ MODULE }} | {{ DESC }} |
| {{ SIB }} | {{ MODULE }} | {{ DESC }} |

### 4.2 Instrument 网络

| Instrument | 类型 | 地址 | 功能 |
|------------|------|------|------|
| {{ INSTR }} | {{ TYPE }} | {{ ADDR }} | {{ FUNC }} |

---

## 5. BIST 设计

### 5.1 Memory BIST

| Memory | BIST类型 | 测试算法 | 测试时间 |
|--------|----------|----------|----------|
| {{ MEM }} | March C | {{ ALGO }} | {{ N }} ms |
| {{ MEM }} | Checkerboard | {{ ALGO }} | {{ N }} ms |

### 5.2 Logic BIST (LBIST)

| 参数 | 值 |
|------|---|
| Pattern数 | {{ N }} |
| 测试时间 | {{ N }} ms |
| MISR宽度 | {{ N }} |

### 5.3 BIST 控制寄存器

| 寄存器 | 地址 | 功能 |
|--------|------|------|
| BIST_CTRL | {{ ADDR }} | BIST控制 |
| BIST_STATUS | {{ ADDR }} | BIST状态 |
| BIST_RESULT | {{ ADDR }} | BIST结果 |

---

## 6. IEEE 1838 Die Wrapper（Chiplet 适用）

### 6.1 Wrapper 配置

| 参数 | 值 |
|------|---|
| Wrapper类型 | {{ TYPE }} |
| 端口数 | {{ N }} |
| Wrapper Instruction Set | {{ SET }} |

### 6.2 Wrapper 测试模式

| 模式 | 描述 |
|------|------|
| Intra-die test | Die内部测试 |
| Inter-die test | Die间互连测试 |
| {{ MODE }} | {{ DESC }} |

---

## 7. 测试覆盖率目标

### 7.1 ATPG 目标

| 故障类型 | 目标覆盖率 |
|----------|------------|
| Stuck-at | ≥ {{ N }} % |
| Transition | ≥ {{ N }} % |
| Path Delay | ≥ {{ N }} % |
| {{ TYPE }} | ≥ {{ N }} % |

### 7.2 Memory 测试覆盖率

| Memory | 目标覆盖率 |
|--------|------------|
| {{ MEM }} | ≥ {{ N }} % |

---

## 8. 测试序列

### 8.1 生产测试流程

```
Production Test Sequence:
1. Pre-silicon validation
2. Wafer sort:
   - Scan ATPG
   - Memory BIST
   - Parametric tests
3. Die preparation
4. Package assembly
5. Final test:
   - Full scan
   - Functional test
   - Speed test
```

### 8.2 测试时间预算

| 测试项 | 时间 |
|--------|------|
| Scan ATPG | {{ N }} ms |
| Memory BIST | {{ N }} ms |
| Functional | {{ N }} ms |
| 总计 | ≤ {{ N }} ms |

---

## 9. DFT 寄存器

### 9.1 TEST_CTRL (Offset: 0x{{ N }})

| Bit | Field | Access | Reset | 描述 |
|-----|-------|--------|-------|------|
| [0] | SCAN_EN | RW | 0 | Scan使能 |
| [1] | BIST_EN | RW | 0 | BIST使能 |
| [2] | TEST_MODE | RW | 0 | 测试模式 |
| {{ BITS }} | {{ FIELD }} | {{ ACC }} | {{ RST }} | {{ DESC }} |

---

## 10. Quality Checklist

- [ ] Scan链配置完整
- [ ] JTAG指令集定义
- [ ] IJTAG网络定义（如适用）
- [ ] Memory BIST定义
- [ ] Logic BIST定义（如适用）
- [ ] IEEE 1838 Wrapper定义（Chiplet适用）
- [ ] 覆盖率目标明确
- [ ] 测试序列完整
- [ ] 测试时间预算
- [ ] DFT寄存器定义