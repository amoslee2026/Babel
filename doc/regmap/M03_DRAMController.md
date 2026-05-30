# M03_DRAMController Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:23

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | DRAM_CTRL | 32 | RW | 0x1 | REQ-M03-R001 | 控制寄存器：使能、自刷新、ECC |
| 0x04 | TIMING_CFG | 32 | RW | 0x24121218 | REQ-M03-R002 | 时序参数：tRCD、tCL、tRP、tRAS |
| 0x08 | ECC_STATUS | 32 | W1C | 0x0 | REQ-M03-R003 | ECC 状态：SBE/DBE 标志、错误地址 |
| 0x0C | PERF_CNT | 32 | RO | 0x0 | REQ-M03-R004 | 性能计数器 |

## Register Details

### DRAM_CTRL (0x00) - 控制寄存器：使能、自刷新、ECC

**Access**: RW  
**Reset Value**: 0x1  
**REQ_ID**: REQ-M03-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | EN | RW | 1 | 控制器使能。1=使能，0=禁用 |
| [1] | SELF_REFRESH | RW | 0 | 自刷新模式。1=进入自刷新 |
| [2] | ECC_EN | RW | 0 | ECC 使能。1=使能 |
| [3] | ECC_IRQ_EN | RW | 0 | ECC 双比特错误中断使能 |
| [7:4] | BURST_LEN | RW | 8 | 突发长度配置（默认 BL8） |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### TIMING_CFG (0x04) - 时序参数：tRCD、tCL、tRP、tRAS

**Access**: RW  
**Reset Value**: 0x24121218  
**REQ_ID**: REQ-M03-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [7:0] | tRCD | RW | 24 | 行到列延迟（单位 CLK_SYS） |
| [15:8] | tCL | RW | 18 | CAS 延迟 |
| [23:16] | tRP | RW | 18 | 预充电时间 |
| [31:24] | tRAS | RW | 36 | 行激活时间 |

### ECC_STATUS (0x08) - ECC 状态：SBE/DBE 标志、错误地址

**Access**: W1C  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M03-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | SBE | W1C | 0 | 单比特错误标志。写 1 清零 |
| [1] | DBE | W1C | 0 | 双比特错误标志。写 1 清零 |
| [15:2] | RESERVED | - | 0 | 保留 |
| [31:16] | ERR_ADDR | RO | 0 | 最近错误地址高 16 位 |

### PERF_CNT (0x0C) - 性能计数器

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M03-R004

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [31:0] | COUNT | RO | 0 | 内存访问周期计数 |
