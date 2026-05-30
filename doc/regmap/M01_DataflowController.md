# M01_DataflowController Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:23

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | CTRL | 32 | RW | 0x0 | REQ-M01-R001 | 控制寄存器：全局使能、软复位、调度模式 |
| 0x04 | STATUS | 32 | RO | 0x0 | REQ-M01-R002 | 状态寄存器：IDLE/BUSY、当前 TID、流水线阶段 |
| 0x08 | THREAD_CFG0 | 32 | RW | 0x0 | REQ-M01-R003 | 线程 0 配置：精度、算子掩码 |
| 0x0C | THREAD_CFG1 | 32 | RW | 0x0 | REQ-M01-R004 | 线程 1 配置：同上 |
| 0x10 | OP_QUEUE | 32 | RW | 0x0 | REQ-M01-R005 | 操作队列：基地址高 16 位、深度 |
| 0x14 | PERF_CNT0 | 32 | RO | 0x0 | REQ-M01-R006 | 线程 0 完成算子计数 |
| 0x18 | PERF_CNT1 | 32 | RO | 0x0 | REQ-M01-R007 | 线程 1 完成算子计数 |
| 0x1C | PERF_UTIL | 32 | RO | 0x0 | REQ-M01-R008 | 流水线利用率（Q16 格式） |
| 0x20 | IRQ_MASK | 32 | RW | 0x0 | REQ-M01-R009 | 中断使能掩码 |
| 0x24 | IRQ_STATUS | 32 | W1C | 0x0 | REQ-M01-R010 | 中断状态，写 1 清零 |

## Register Details

### CTRL (0x00) - 控制寄存器：全局使能、软复位、调度模式

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | GLOBAL_EN | RW | 0 | 全局使能。1=使能，0=禁用 |
| [1] | SOFT_RST | RW | 0 | 软复位。写 1 触发内部复位，自清零 |
| [3:2] | SCHED_MODE | RW | 0 | 调度模式。00=顺序, 01=轮询, 10=优先级 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### STATUS (0x04) - 状态寄存器：IDLE/BUSY、当前 TID、流水线阶段

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | IDLE | RO | 0 | 空闲标志。1=模块空闲 |
| [1] | BUSY | RO | 0 | 忙标志。1=正在处理 |
| [3:2] | CUR_TID | RO | 0 | 当前线程 ID (0-1) |
| [7:4] | PIPE_STAGE | RO | 0 | 当前流水线阶段 (0-F) |
| [31:8] | RESERVED | - | 0 | 保留 |

### THREAD_CFG0 (0x08) - 线程 0 配置：精度、算子掩码

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [1:0] | PRECISION | RW | 0 | 精度选择。00=INT8, 01=FP16, 10=BF16 |
| [7:2] | OP_MASK | RW | 0 | 算子掩码。bit[n]=1 启用算子 n |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### THREAD_CFG1 (0x0C) - 线程 1 配置：同上

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R004

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [1:0] | PRECISION | RW | 0 | 精度选择。00=INT8, 01=FP16, 10=BF16 |
| [7:2] | OP_MASK | RW | 0 | 算子掩码。bit[n]=1 启用算子 n |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### OP_QUEUE (0x10) - 操作队列：基地址高 16 位、深度

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R005

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [15:0] | QUEUE_BASE_HI | RW | 0 | 队列基地址高 16 位 |
| [31:16] | QUEUE_DEPTH | RW | 0 | 队列深度（条目数） |

### PERF_CNT0 (0x14) - 线程 0 完成算子计数

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R006

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | 线程 0 完成算子计数 |

### PERF_CNT1 (0x18) - 线程 1 完成算子计数

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R007

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | 线程 1 完成算子计数 |

### PERF_UTIL (0x1C) - 流水线利用率（Q16 格式）

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R008

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [15:0] | UTILIZATION | RO | 0 | 流水线利用率（Q0.16 定点格式，0x10000=100%） |
| [31:16] | RESERVED | - | 0 | 保留 |

### IRQ_MASK (0x20) - 中断使能掩码

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R009

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | DONE_MASK | RW | 0 | 完成中断使能。1=使能 |
| [1] | ERROR_MASK | RW | 0 | 错误中断使能。1=使能 |
| [2] | QUEUE_FULL_MASK | RW | 0 | 队列满中断使能。1=使能 |
| [31:3] | RESERVED | - | 0 | 保留，必须写 0 |

### IRQ_STATUS (0x24) - 中断状态，写 1 清零

**Access**: W1C  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M01-R010

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | DONE_IRQ | W1C | 0 | 完成中断。写 1 清零 |
| [1] | ERROR_IRQ | W1C | 0 | 错误中断。写 1 清零 |
| [2] | QUEUE_FULL_IRQ | W1C | 0 | 队列满中断。写 1 清零 |
| [31:3] | RESERVED | - | 0 | 保留 |
