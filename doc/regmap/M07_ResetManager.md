# M07_ResetManager Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:24

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | RST_CTRL | 32 | RW | 0xE | REQ-M07-R001 | 复位控制：软件复位触发、复位范围、WDT 使能 |
| 0x04 | RST_STATUS | 32 | RO | 0x1 | REQ-M07-R002 | 复位状态：复位源标志、当前复位输出状态 |
| 0x08 | WDT_CFG | 32 | RW | 0xFFFF | REQ-M07-R003 | 看门狗配置：超时周期、喂狗、锁定 |

## Register Details

### RST_CTRL (0x00) - 复位控制：软件复位触发、复位范围、WDT 使能

**Access**: RW  
**Reset Value**: 0xE  
**REQ_ID**: REQ-M07-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | SW_RST | W1S | 0 | 软件复位触发。写 1 触发复位，自动清零 |
| [2:1] | SCOPE | RW | 3 | 复位范围。00=仅 sys，01=main+sys，11=全局 |
| [3] | WDT_EN | RW | 1 | WDT 复位使能。1=使能，0=禁用 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### RST_STATUS (0x04) - 复位状态：复位源标志、当前复位输出状态

**Access**: RO  
**Reset Value**: 0x1  
**REQ_ID**: REQ-M07-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [0] | POR_FLAG | RO | 1 | 上次复位由 POR（上电复位）触发 |
| [1] | WDT_FLAG | RO | 0 | 上次复位由 WDT（看门狗）触发 |
| [2] | SW_FLAG | RO | 0 | 上次复位由软件触发 |
| [3] | RST_ACTIVE | RO | 0 | 当前复位输出状态（任一复位源有效时为 1） |
| [7:4] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |

### WDT_CFG (0x08) - 看门狗配置：超时周期、喂狗、锁定

**Access**: RW  
**Reset Value**: 0xFFFF  
**REQ_ID**: REQ-M07-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [15:0] | WDT_PERIOD | RW | 65535 | 看门狗超时周期（CLK_AON 计数值） |
| [16] | WDT_KICK | W1S | 0 | 喂狗操作。写 1 重置计数器，自动清零 |
| [17] | WDT_LOCK | RW | 0 | WDT_PERIOD 锁定。写 1 锁定，需 POR 解锁 |
| [31:18] | RESERVED | - | 0 | 保留，必须写 0 |
