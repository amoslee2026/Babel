---
ip_id: IP-COMP-04-EXECUNIT
ip_type: compute
ip_class: execunit
title: Compute IP Execution Unit Design Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-COMP-02-MAS
derived_from: []
generated: 2026-04-23T23:00:00+08:00
---

# 计算模块 IP 执行单元设计模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 执行单元概述

- **单元名称**: {{ UNIT_NAME }}
- **单元类型**: alu / multiplier / divider / fpu / simd / crypto
- **操作数位宽**: {{ WIDTH }} bits
- **目标延迟**: {{ N }} cycles
- **目标吞吐量**: {{ RATE }} ops/cycle

---

## 2. ALU 设计模板

### 2.1 功能列表

| 操作 | 功能 | 延迟 | 吞吐量 |
|------|------|------|--------|
| ADD | 加法 | 1 cycle | 1/cycle |
| SUB | 减法 | 1 cycle | 1/cycle |
| AND | 与 | 1 cycle | 1/cycle |
| OR | 或 | 1 cycle | 1/cycle |
| XOR | 异或 | 1 cycle | 1/cycle |
| NOT | 非 | 1 cycle | 1/cycle |
| SHL | 左移 | 1 cycle | 1/cycle |
| SHR | 右移 | 1 cycle | 1/cycle |
| CMP | 比较 | 1 cycle | 1/cycle |

### 2.2 接口定义

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| op_a | IN | {{ WIDTH }} | 操作数A |
| op_b | IN | {{ WIDTH }} | 操作数B |
| op_code | IN | {{ N }} | 操作码 |
| result | OUT | {{ WIDTH }} | 结果 |
| flags | OUT | {{ N }} | 标志位（零/负/溢出/进位）|

### 2.3 关键路径

| 路径 | 延迟 | 实现方式 |
|------|------|----------|
| 加法链 | {{ N }} ns | Carry-lookahead / Carry-select |
| 移位器 | {{ N }} ns | Barrel shifter |

---

## 3. 乘法器设计模板

### 3.1 功能列表

| 操作 | 位宽 | 延迟 | 吞吐量 |
|------|------|------|--------|
| MUL | 32-bit | 3 cycles | 1/3 cycles |
| MUL | 64-bit | {{ N }} cycles | {{ RATE }} |
| MULH | 高半部分 | {{ N }} cycles | {{ RATE }} |

### 3.2 接口定义

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| multiplicand | IN | {{ WIDTH }} | 被乘数 |
| multiplier | IN | {{ WIDTH }} | 乘数 |
| start | IN | 1 | 启动信号 |
| result | OUT | {{ 2*WIDTH }} | 结果 |
| done | OUT | 1 | 完成标志 |

### 3.3 实现方式

| 参数 | 选择 |
|------|------|
| 算法 | Booth / Wallace Tree / Dadda |
| Pipeline | {{ N }} stages |
| Radix | {{ N }} |

---

## 4. 除法器设计模板

### 4.1 功能列表

| 操作 | 位宽 | 延迟 | 吞吐量 |
|------|------|------|--------|
| DIV | 32-bit | {{ N }} cycles | 1/N cycles |
| DIV | 64-bit | {{ N }} cycles | {{ RATE }} |
| REM | 取余 | {{ N }} cycles | {{ RATE }} |

### 4.2 接口定义

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| dividend | IN | {{ WIDTH }} | 被除数 |
| divisor | IN | {{ WIDTH }} | 除数 |
| start | IN | 1 | 启动信号 |
| quotient | OUT | {{ WIDTH }} | 商 |
| remainder | OUT | {{ WIDTH }} | 余数 |
| done | OUT | 1 | 完成标志 |
| div_by_zero | OUT | 1 | 除零异常 |

### 4.3 实现方式

| 参数 | 选择 |
|------|------|
| 算法 | Restoring / Non-restoring / SRT / Newton-Raphson |
| 每周期迭代数 | {{ N }} |

---

## 5. FPU 设计模板

### 5.1 功能列表

| 操作 | 格式 | 延迟 | 吞吐量 |
|------|------|------|--------|
| FADD | IEEE 754 single | {{ N }} cycles | {{ RATE }} |
| FSUB | IEEE 754 single | {{ N }} cycles | {{ RATE }} |
| FMUL | IEEE 754 single | {{ N }} cycles | {{ RATE }} |
| FDIV | IEEE 754 single | {{ N }} cycles | {{ RATE }} |
| FSQRT | IEEE 754 single | {{ N }} cycles | {{ RATE }} |
| FADD | IEEE 754 double | {{ N }} cycles | {{ RATE }} |

### 5.2 接口定义

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| op_a | IN | {{ WIDTH }} | 操作数A |
| op_b | IN | {{ WIDTH }} | 操作数B |
| op_code | IN | {{ N }} | 操作码 |
| result | OUT | {{ WIDTH }} | 结果 |
| fpscr | OUT | {{ N }} | FP状态寄存器 |

### 5.3 IEEE 754 支持

| 特性 | 支持 |
|------|------|
| 舍入模式 | RNE / RTZ / RUP / RDN / RNA |
| 特殊值 | NaN / Inf / Zero / Denormal |
| 异常 | Invalid / Div-by-zero / Overflow / Underflow / Inexact |

---

## 6. SIMD/Vector 单元设计模板

### 6.1 功能列表

| 操作 | 向量宽度 | 延迟 | 吞吐量 |
|------|----------|------|--------|
| VADD | {{ WIDTH }}-bit | {{ N }} cycles | {{ RATE }} |
| VMUL | {{ WIDTH }}-bit | {{ N }} cycles | {{ RATE }} |
| VLOAD | {{ WIDTH }}-bit | {{ N }} cycles | {{ RATE }} |
| VSTORE | {{ WIDTH }}-bit | {{ N }} cycles | {{ RATE }} |

### 6.2 接口定义

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| vec_a | IN | {{ WIDTH }} | 向量A |
| vec_b | IN | {{ WIDTH }} | 向量B |
| lane_mask | IN | {{ N }} | Lane使能 |
| result | OUT | {{ WIDTH }} | 结果向量 |

### 6.3 Lane配置

| 参数 | 值 |
|------|---|
| Lane数 | {{ N }} |
| Lane位宽 | {{ WIDTH }} |
| 支持类型 | {{ TYPES }} |

---

## 7. 加密单元设计模板（可选）

### 7.1 功能列表

| 操作 | 算法 | 延迟 | 吞吐量 |
|------|------|------|--------|
| AES-ENC | AES-128/256 | {{ N }} cycles | {{ RATE }} |
| AES-DEC | AES-128/256 | {{ N }} cycles | {{ RATE }} |
| SHA-256 | SHA-256 | {{ N }} cycles/block | {{ RATE }} |
| {{ OP }} | {{ ALGO }} | {{ N }} cycles | {{ RATE }} |

### 7.2 接口定义

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| data_in | IN | {{ WIDTH }} | 输入数据 |
| key | IN | {{ WIDTH }} | 密钥 |
| result | OUT | {{ WIDTH }} | 输出数据 |

---

## 8. 执行单元仲裁

### 8.1 资源共享

| 单元 | 共享策略 |
|------|----------|
| {{ UNIT }} | {{ STRATEGY }} |

### 8.2 优先级

| 请求源 | 优先级 |
|--------|--------|
| {{ SOURCE }} | {{ PRI }} |

---

## 9. 时序与面积估算

### 9.1 各单元面积

| 单元 | 面积估算 |
|------|----------|
| ALU | {{ N }} kGE |
| Multiplier | {{ N }} kGE |
| Divider | {{ N }} kGE |
| FPU | {{ N }} kGE |
| SIMD | {{ N }} kGE |

### 9.2 关键路径延迟

| 单元 | 关键路径 | 延迟 |
|------|----------|------|
| {{ UNIT }} | {{ PATH }} | {{ N }} ns |

---

## 10. Quality Checklist

- [ ] 所有操作定义完整
- [ ] 接口定义完整
- [ ] 延迟/吞吐量明确
- [ ] 实现方式明确
- [ ] IEEE 754 支持明确（FPU）
- [ ] Lane配置明确（SIMD）
- [ ] 面积估算完成
- [ ] 关键路径分析完成