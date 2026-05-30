# M00_SystolicArray Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:23

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | SA_CTRL | 32 | RW | 0x0 | REQ-M00-R001 | 控制寄存器：start、soft_rst、precision、dataflow_mode |
| 0x04 | SA_STATUS | 32 | RO | 0x0 | REQ-M00-R002 | 状态寄存器：busy、done、stall、fsm_state |
| 0x08 | SA_DIM_CFG | 32 | RW | 0x0 | REQ-M00-R003 | 矩阵维度配置：dim_m、dim_n、dim_k |
| 0x0C | SA_PERF_CNT | 32 | RO | 0x0 | REQ-M00-R004 | 计算周期计数器（每次 start 清零） |

## Register Details

### SA_CTRL (0x00) - 控制寄存器：start、soft_rst、precision、dataflow_mode

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M00-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | START | RW | 0 | 启动计算。写 1 启动，完成后自动清零 |
| [1] | SOFT_RST | RW | 0 | 软复位。写 1 触发内部复位，自清零 |
| [3:2] | PRECISION | RW | 0 | 精度选择。00=INT8, 01=FP16, 10=BF16 |
| [4] | DATAFLOW_MODE | RW | 0 | 数据流模式。0=output-stationary, 1=weight-stationary |
| [7:5] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### SA_STATUS (0x04) - 状态寄存器：busy、done、stall、fsm_state

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M00-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | BUSY | RO | 0 | 忙标志。1=正在计算 |
| [1] | DONE | RO | 0 | 完成标志。1=上次计算完成 |
| [2] | STALL | RO | 0 | 停顿标志。1=数据通路停顿 |
| [7:4] | FSM_STATE | RO | 0 | 当前 FSM 状态编码 |
| [31:8] | RESERVED | - | 0 | 保留 |

### SA_DIM_CFG (0x08) - 矩阵维度配置：dim_m、dim_n、dim_k

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M00-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [4:0] | DIM_M | RW | 0 | 矩阵 M 维度 (0-31) |
| [9:5] | DIM_N | RW | 0 | 矩阵 N 维度 (0-31) |
| [19:10] | DIM_K | RW | 0 | 矩阵 K 维度 (0-1023) |
| [31:20] | RESERVED | - | 0 | 保留，必须写 0 |

### SA_PERF_CNT (0x0C) - 计算周期计数器（每次 start 清零）

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M00-R004

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | 计算周期计数。每次 START 清零 |
