# M01_DataflowController 寄存器映射

<!-- REQ-M01-R001 ~ REQ-M01-R010 -->

**Base Address**: 由 M04_SystemBus 分配（APB 从接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| CTRL        | 0x00 | 32 | RW   | 0x0 | REQ-M01-R001 | 控制寄存器：全局使能、软复位、调度模式 |
| STATUS      | 0x04 | 32 | RO   | 0x0 | REQ-M01-R002 | 状态寄存器：IDLE/BUSY、当前 TID、流水线阶段 |
| THREAD_CFG0 | 0x08 | 32 | RW   | 0x0 | REQ-M01-R003 | 线程 0 配置：精度、算子掩码 |
| THREAD_CFG1 | 0x0C | 32 | RW   | 0x0 | REQ-M01-R004 | 线程 1 配置：同上 |
| OP_QUEUE    | 0x10 | 32 | RW   | 0x0 | REQ-M01-R005 | 操作队列：基地址高 16 位、深度 |
| PERF_CNT0   | 0x14 | 32 | RO   | 0x0 | REQ-M01-R006 | 线程 0 完成算子计数 |
| PERF_CNT1   | 0x18 | 32 | RO   | 0x0 | REQ-M01-R007 | 线程 1 完成算子计数 |
| PERF_UTIL   | 0x1C | 32 | RO   | 0x0 | REQ-M01-R008 | 流水线利用率（Q16 格式） |
| IRQ_MASK    | 0x20 | 32 | RW   | 0x0 | REQ-M01-R009 | 中断使能掩码 |
| IRQ_STATUS  | 0x24 | 32 | W1C  | 0x0 | REQ-M01-R010 | 中断状态，写 1 清零 |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略（无副作用） |
| W1C  | 写 1 清零 | 返回当前值 | 写 1 清零，写 0 无效 |

---

## 2. 寄存器详细定义

### 2.1 CTRL (0x00) - 控制寄存器

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | GLOBAL_EN | RW | 0 | 全局使能。1=使能，0=禁用 |
| [1] | SOFT_RST | RW | 0 | 软复位。写 1 触发内部复位，自清零 |
| [3:2] | SCHED_MODE | RW | 0 | 调度模式。00=顺序, 01=轮询, 10=优先级 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- SOFT_RST 为自清零位：写 1 后硬件自动清零
- 写入 RESERVED 位被忽略

---

### 2.2 STATUS (0x04) - 状态寄存器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | IDLE | RO | 0 | 空闲标志。1=模块空闲 |
| [1] | BUSY | RO | 0 | 忙标志。1=正在处理 |
| [3:2] | CUR_TID | RO | 0 | 当前线程 ID (0-1) |
| [7:4] | PIPE_STAGE | RO | 0 | 当前流水线阶段 (0-F) |
| [31:8] | RESERVED | - | 0 | 保留 |

#### 访问规则

- 只读寄存器，写操作被忽略

---

### 2.3 THREAD_CFG0 (0x08) - 线程 0 配置

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [1:0] | PRECISION | RW | 0 | 精度选择。00=INT8, 01=FP16, 10=BF16 |
| [7:2] | OP_MASK | RW | 0 | 算子掩码。bit[n]=1 启用算子 n |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

---

### 2.4 THREAD_CFG1 (0x0C) - 线程 1 配置

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R004

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [1:0] | PRECISION | RW | 0 | 精度选择。00=INT8, 01=FP16, 10=BF16 |
| [7:2] | OP_MASK | RW | 0 | 算子掩码。bit[n]=1 启用算子 n |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

---

### 2.5 OP_QUEUE (0x10) - 操作队列配置

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R005

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [15:0] | QUEUE_BASE_HI | RW | 0 | 队列基地址高 16 位 |
| [31:16] | QUEUE_DEPTH | RW | 0 | 队列深度（条目数） |

---

### 2.6 PERF_CNT0 (0x14) - 线程 0 性能计数

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R006

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | 线程 0 完成算子计数 |

#### 访问规则

- 只读。复位时清零
- 读取不影响计数值

---

### 2.7 PERF_CNT1 (0x18) - 线程 1 性能计数

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R007

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | 线程 1 完成算子计数 |

---

### 2.8 PERF_UTIL (0x1C) - 流水线利用率

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R008

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [15:0] | UTILIZATION | RO | 0 | 流水线利用率（Q0.16 定点格式，0x10000=100%） |
| [31:16] | RESERVED | - | 0 | 保留 |

---

### 2.9 IRQ_MASK (0x20) - 中断使能掩码

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R009

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | DONE_MASK | RW | 0 | 完成中断使能。1=使能 |
| [1] | ERROR_MASK | RW | 0 | 错误中断使能。1=使能 |
| [2] | QUEUE_FULL_MASK | RW | 0 | 队列满中断使能。1=使能 |
| [31:3] | RESERVED | - | 0 | 保留，必须写 0 |

---

### 2.10 IRQ_STATUS (0x24) - 中断状态

**Access**: W1C
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M01-R010

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | DONE_IRQ | W1C | 0 | 完成中断。写 1 清零 |
| [1] | ERROR_IRQ | W1C | 0 | 错误中断。写 1 清零 |
| [2] | QUEUE_FULL_IRQ | W1C | 0 | 队列满中断。写 1 清零 |
| [31:3] | RESERVED | - | 0 | 保留 |

#### 访问规则

- 读操作返回当前中断状态
- 写 1 清零对应中断位，写 0 无效
- RESERVED 位写入被忽略

---

## 3. 寄存器访问时序

### 3.1 APB 写时序

```wavedrom
{signal: [
  {name: 'pclk', wave: 'p.....'},
  {name: 'psel', wave: '01..0.'},
  {name: 'penable', wave: '0.1.0.'},
  {name: 'pwrite', wave: '1.....'},
  {name: 'paddr', wave: 'x=..x.', data: ['ADDR']},
  {name: 'pwdata', wave: 'x=..x.', data: ['DATA']}
]}
```

### 3.2 APB 读时序

```wavedrom
{signal: [
  {name: 'pclk', wave: 'p.....'},
  {name: 'psel', wave: '01..0.'},
  {name: 'penable', wave: '0.1.0.'},
  {name: 'pwrite', wave: '0.....'},
  {name: 'paddr', wave: 'x=..x.', data: ['ADDR']},
  {name: 'prdata', wave: 'x..=x.', data: ['DATA']}
]}
```

---

## 4. 中断与事件

### 4.1 中断源

| 中断名 | 触发条件 | 清除方式 | 对应 IRQ_STATUS 位 |
|--------|---------|---------|-------------------|
| DONE_IRQ | 算子操作完成 | 写 1 清零 | [0] |
| ERROR_IRQ | 发生错误（非法操作、超时） | 写 1 清零 | [1] |
| QUEUE_FULL_IRQ | 操作队列满 | 写 1 清零 | [2] |

### 4.2 中断使能

通过 IRQ_MASK 寄存器使能/禁用各中断源。IRQ_STATUS 中的中断标志不受 IRQ_MASK 影响，仅中断输出受掩码控制。

---

## 5. 编程示例

### 5.1 初始化序列

```c
// 1. 配置线程 0 精度和算子掩码
REG_WRITE(THREAD_CFG0, (0x01 << 0) | (0x3F << 2));  // FP16, 启用算子 0-5

// 2. 配置操作队列
REG_WRITE(OP_QUEUE, (0x8000 << 0) | (64 << 16));    // 基地址 0x8000_0000, 深度 64

// 3. 使能中断
REG_WRITE(IRQ_MASK, 0x07);  // 使能所有中断

// 4. 全局使能
REG_WRITE(CTRL, CTRL_GLOBAL_EN | (0x01 << 2));  // 使能 + 轮询调度
```

### 5.2 中断处理

```c
uint32_t irq = REG_READ(IRQ_STATUS);

if (irq & IRQ_STATUS_DONE) {
    // 处理完成中断
    REG_WRITE(IRQ_STATUS, IRQ_STATUS_DONE);  // W1C 清除
}

if (irq & IRQ_STATUS_ERROR) {
    // 处理错误
    uint32_t status = REG_READ(STATUS);
    REG_WRITE(IRQ_STATUS, IRQ_STATUS_ERROR);  // W1C 清除
}
```

---

## 6. 寄存器地址映射表（供综合工具使用）

```csv
Name,Offset,Width,Access,Reset,Description
CTRL,0x00,32,RW,0x00000000,Control register
STATUS,0x04,32,RO,0x00000000,Status register
THREAD_CFG0,0x08,32,RW,0x00000000,Thread 0 configuration
THREAD_CFG1,0x0C,32,RW,0x00000000,Thread 1 configuration
OP_QUEUE,0x10,32,RW,0x00000000,Operation queue configuration
PERF_CNT0,0x14,32,RO,0x00000000,Thread 0 performance counter
PERF_CNT1,0x18,32,RO,0x00000000,Thread 1 performance counter
PERF_UTIL,0x1C,32,RO,0x00000000,Pipeline utilization
IRQ_MASK,0x20,32,RW,0x00000000,Interrupt enable mask
IRQ_STATUS,0x24,32,W1C,0x00000000,Interrupt status
```
