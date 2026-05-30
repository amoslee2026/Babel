# M06_ClockManager Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:24

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | CLK_CTRL | 32 | RW | 0x0 | REQ-M06-R001 | 时钟控制：PLL 使能、时钟门控 |
| 0x04 | PLL_CFG | 32 | RW | 0x103D09 | REQ-M06-R002 | PLL 配置：倍频系数、环路带宽 |
| 0x08 | CLK_STATUS | 32 | RO | 0x0 | REQ-M06-R003 | 时钟状态：PLL 锁定、时钟稳定 |

## Register Details

### CLK_CTRL (0x00) - 时钟控制：PLL 使能、时钟门控

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M06-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | PLL_EN | RW | 0 | PLL 使能。1=使能，0=禁用 |
| [1] | CLK_GATE_EN | RW | 0 | 时钟门控使能。1=使能，0=禁用 |
| [7:2] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### PLL_CFG (0x04) - PLL 配置：倍频系数、环路带宽

**Access**: RW  
**Reset Value**: 0x103D09  
**REQ_ID**: REQ-M06-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [15:0] | DIV_RATIO | RW | 15625 | PLL 倍频系数（15625 = 500MHz/32kHz） |
| [23:16] | BW_CFG | RW | 16 | 环路带宽配置 |
| [31:24] | RESERVED | - | 0 | 保留，必须写 0 |

### CLK_STATUS (0x08) - 时钟状态：PLL 锁定、时钟稳定

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M06-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | PLL_LOCK | RO | 0 | PLL 锁定状态。1=已锁定 |
| [1] | CLK_STABLE | RO | 0 | 时钟稳定指示。1=时钟输出稳定 |
| [7:2] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |
