# M04_SystemBus Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:24

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | BUS_CTRL | 32 | RW | 0x1 | REQ-M04-R001 | 总线控制：使能、仲裁模式 |
| 0x04 | ARB_CFG | 32 | RW | 0x3210 | REQ-M04-R002 | 仲裁优先级配置 |
| 0x08 | BUS_STATUS | 32 | RO | 0x0 | REQ-M04-R003 | 总线状态：当前 master、busy、deadlock |
| 0x0C | BW_COUNTER_M00 | 32 | RO | 0x0 | REQ-M04-R004 | M00 带宽计数器 (bytes/ms) |
| 0x10 | BW_COUNTER_M01 | 32 | RO | 0x0 | REQ-M04-R005 | M01 带宽计数器 |
| 0x14 | BW_COUNTER_M02 | 32 | RO | 0x0 | REQ-M04-R006 | M02 带宽计数器 |
| 0x18 | BW_COUNTER_M03 | 32 | RO | 0x0 | REQ-M04-R007 | M03 带宽计数器 |

## Register Details

### BUS_CTRL (0x00) - 总线控制：使能、仲裁模式

**Access**: RW  
**Reset Value**: 0x1  
**REQ_ID**: REQ-M04-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | BUS_ENABLE | RW | 1 | 总线使能。1=使能，0=禁用 |
| [1] | ARB_MODE | RW | 0 | 仲裁模式。0=Round-Robin，1=Priority |
| [7:2] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### ARB_CFG (0x04) - 仲裁优先级配置

**Access**: RW  
**Reset Value**: 0x3210  
**REQ_ID**: REQ-M04-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [3:0] | M00_PRI | RW | 0 | M00 (Systolic) 优先级 (0=最高) |
| [7:4] | M01_PRI | RW | 1 | M01 (Dataflow) 优先级 |
| [11:8] | M02_PRI | RW | 2 | M02 (SRAM) 优先级 |
| [15:12] | M03_PRI | RW | 3 | M03 (DRAM) 优先级 |
| [31:16] | RESERVED | - | 0 | 保留，必须写 0 |

### BUS_STATUS (0x08) - 总线状态：当前 master、busy、deadlock

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M04-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [3:0] | CURRENT_MASTER | RO | 0 | 当前占用总线的 Master ID |
| [4] | BUS_BUSY | RO | 0 | 总线忙标志 |
| [5] | DEADLOCK_DETECT | RO | 0 | 死锁检测标志 |
| [7:6] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |

### BW_COUNTER_M00 (0x0C) - M00 带宽计数器 (bytes/ms)

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M04-R004

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | M00 带宽计数 (bytes/ms) |

### BW_COUNTER_M01 (0x10) - M01 带宽计数器

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M04-R005

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | M01 带宽计数 (bytes/ms) |

### BW_COUNTER_M02 (0x14) - M02 带宽计数器

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M04-R006

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | M02 带宽计数 (bytes/ms) |

### BW_COUNTER_M03 (0x18) - M03 带宽计数器

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M04-R007

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | M03 带宽计数 (bytes/ms) |
