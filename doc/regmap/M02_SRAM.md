# M02_SRAM Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:23

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | SRAM_CTRL | 32 | RW | 0x3 | REQ-M02-R001 | 控制寄存器：使能、ECC、Bank 模式 |
| 0x04 | ECC_STATUS | 32 | RO | 0x0 | REQ-M02-R002 | ECC 错误统计：SEC/DED 计数 |
| 0x08 | ECC_ADDR | 32 | RO | 0x0 | REQ-M02-R003 | 最近 ECC 错误地址 |

## Register Details

### SRAM_CTRL (0x00) - 控制寄存器：使能、ECC、Bank 模式

**Access**: RW  
**Reset Value**: 0x3  
**REQ_ID**: REQ-M02-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | EN | RW | 1 | SRAM 使能。1=使能，0=禁用 |
| [1] | ECC_EN | RW | 1 | ECC 使能。1=使能，0=禁用 |
| [3:2] | BANK_MODE | RW | 0 | Bank 模式。00=独立，01=交织 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### ECC_STATUS (0x04) - ECC 错误统计：SEC/DED 计数

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M02-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [15:0] | SEC_CNT | RO | 0 | 单比特纠正累计计数 |
| [31:16] | DED_CNT | RO | 0 | 双比特检测累计计数 |

### ECC_ADDR (0x08) - 最近 ECC 错误地址

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M02-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [18:0] | ERR_ADDR | RO | 0 | 最近 ECC 错误地址（19-bit 字地址） |
| [31:19] | RESERVED | - | 0 | 保留 |
