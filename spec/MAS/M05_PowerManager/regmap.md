# M05_PowerManager 寄存器映射

<!-- REQ-M05-R001 ~ REQ-M05-R003 -->

**Base Address**: 由 TOP 地址映射分配（APB 从接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| PWR_CTRL   | 0x00 | 32 | RW | 0x0000_0000 | REQ-M05-R001 | 电源控制：电源请求、睡眠使能、唤醒源选择 |
| DVFS_CFG   | 0x04 | 32 | RW | 0x0000_0810 | REQ-M05-R002 | DVFS 配置：电压/频率稳定计数、DVFS 模式 |
| PWR_STATUS | 0x08 | 32 | RO | 0x0000_0000 | REQ-M05-R003 | 电源状态：当前 FSM 状态、DVFS 工作点、PMIC PG |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |

---

## 2. 寄存器详细定义

### 2.1 PWR_CTRL (0x00) - 电源控制

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M05-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [1:0] | PWR_REQ | RW | 0 | 软件电源请求。编码同 DVFS 工作点：00=NOM, 01=LOW, 10=HIGH |
| [2] | SLEEP_EN | RW | 0 | 允许进入 SLEEP 状态。1=允许，0=禁止 |
| [3] | WAKEUP_SRC_SEL | RW | 0 | 唤醒源选择。0=外部中断，1=定时器 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- PWR_REQ 变更后需等待 FSM 状态转换完成
- SLEEP_EN=1 且系统空闲时自动进入 SLEEP

---

### 2.2 DVFS_CFG (0x04) - DVFS 配置

**Access**: RW
**Reset Value**: 0x0000_0810
**REQ_ID**: REQ-M05-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [7:0] | V_SETTLE_CNT | RW | 0x10 | 电压稳定等待计数（CLK_AON 周期） |
| [15:8] | F_SETTLE_CNT | RW | 0x08 | 频率切换等待计数（CLK_AON 周期） |
| [17:16] | DVFS_MODE | RW | 0 | DVFS 模式。00=手动，01=自动（硬件 DVFS） |
| [31:18] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- DVFS 切换进行中（DVFS_BUSY=1）时修改配置无效，下次切换生效
- V_SETTLE_CNT 和 F_SETTLE_CNT 不可设为 0

---

### 2.3 PWR_STATUS (0x08) - 电源状态

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M05-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [1:0] | CUR_STATE | RO | 0 | 当前 FSM 状态编码 |
| [3:2] | CUR_DVFS | RO | 0 | 当前 DVFS 工作点。00=NOM, 01=LOW, 10=HIGH |
| [4] | DVFS_BUSY | RO | 0 | DVFS 切换进行中标志 |
| [5] | PMIC_PG | RO | 0 | PMIC Power Good 状态。1=电源稳定 |
| [7:6] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |

---

## 3. 编程示例

```c
// 1. 配置 DVFS 为手动模式
REG_WRITE(DVFS_CFG, (0x10 << 0) | (0x08 << 8) | (0x00 << 16));

// 2. 请求切换到 LOW 工作点
REG_WRITE(PWR_CTRL, 0x01);  // PWR_REQ=01 (LOW)

// 3. 等待切换完成
while (REG_READ(PWR_STATUS) & PWR_STATUS_DVFS_BUSY);

// 4. 检查 PMIC Power Good
if (REG_READ(PWR_STATUS) & PWR_STATUS_PMIC_PG) {
    printf("Power stable\n");
}

// 5. 允许进入 SLEEP
REG_WRITE(PWR_CTRL, REG_READ(PWR_CTRL) | (1 << 2));  // SLEEP_EN=1
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
PWR_CTRL,0x00,32,RW,0x00000000,Power control register
DVFS_CFG,0x04,32,RW,0x00000810,DVFS configuration
PWR_STATUS,0x08,32,RO,0x00000000,Power status register
```
