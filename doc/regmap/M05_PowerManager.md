# M05_PowerManager Register Map

**Base Address**: 0x0000_0000  
**Spec Version**: 1.0  
**Generated**: 2026-05-30 16:28:24

## Register Summary

| Offset | Name | Width | Access | Reset | REQ_ID | Description |
|--------|------|-------|--------|-------|--------|-------------|
| 0x00 | PWR_CTRL | 32 | RW | 0x0 | REQ-M05-R001 | 电源控制：电源请求、睡眠使能、唤醒源选择 |
| 0x04 | DVFS_CFG | 32 | RW | 0x810 | REQ-M05-R002 | DVFS 配置：电压/频率稳定计数、DVFS 模式 |
| 0x08 | PWR_STATUS | 32 | RO | 0x0 | REQ-M05-R003 | 电源状态：当前 FSM 状态、DVFS 工作点、PMIC PG |

## Register Details

### PWR_CTRL (0x00) - 电源控制：电源请求、睡眠使能、唤醒源选择

**Access**: RW  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M05-R001

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [1:0] | PWR_REQ | RW | 0 | 软件电源请求。编码同 DVFS 工作点：00=NOM, 01=LOW, 10=HIGH |
| [2] | SLEEP_EN | RW | 0 | 允许进入 SLEEP 状态。1=允许，0=禁止 |
| [3] | WAKEUP_SRC_SEL | RW | 0 | 唤醒源选择。0=外部中断，1=定时器 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

### DVFS_CFG (0x04) - DVFS 配置：电压/频率稳定计数、DVFS 模式

**Access**: RW  
**Reset Value**: 0x810  
**REQ_ID**: REQ-M05-R002

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [7:0] | V_SETTLE_CNT | RW | 16 | 电压稳定等待计数（CLK_AON 周期） |
| [15:8] | F_SETTLE_CNT | RW | 8 | 频率切换等待计数（CLK_AON 周期） |
| [17:16] | DVFS_MODE | RW | 0 | DVFS 模式。00=手动，01=自动（硬件 DVFS） |
| [31:18] | RESERVED | - | 0 | 保留，必须写 0 |

### PWR_STATUS (0x08) - 电源状态：当前 FSM 状态、DVFS 工作点、PMIC PG

**Access**: RO  
**Reset Value**: 0x0  
**REQ_ID**: REQ-M05-R003

#### Bit Fields

| Bit | Name | Access | Reset | Description |
|-----|------|--------|-------|-------------|
| [1:0] | CUR_STATE | RO | 0 | 当前 FSM 状态编码 |
| [3:2] | CUR_DVFS | RO | 0 | 当前 DVFS 工作点。00=NOM, 01=LOW, 10=HIGH |
| [4] | DVFS_BUSY | RO | 0 | DVFS 切换进行中标志 |
| [5] | PMIC_PG | RO | 0 | PMIC Power Good 状态。1=电源稳定 |
| [7:6] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |
