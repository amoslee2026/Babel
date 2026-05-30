# M07_ResetManager 寄存器映射

<!-- REQ-M07-R001 ~ REQ-M07-R003 -->

**Base Address**: 由 SoC 地址映射分配（APB 从接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| RST_CTRL   | 0x00 | 32 | RW | 0x0000_000E | REQ-M07-R001 | 复位控制：软件复位触发、复位范围、WDT 使能 |
| RST_STATUS | 0x04 | 32 | RO | 0x0000_0001 | REQ-M07-R002 | 复位状态：复位源标志、当前复位输出状态 |
| WDT_CFG    | 0x08 | 32 | RW | 0x0000_FFFF | REQ-M07-R003 | 看门狗配置：超时周期、喂狗、锁定 |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |
| W1S  | 写 1 置位 | 返回当前值 | 写 1 触发，自动清零 |

---

## 2. 寄存器详细定义

### 2.1 RST_CTRL (0x00) - 复位控制

**Access**: RW
**Reset Value**: 0x0000_000E
**REQ_ID**: REQ-M07-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | SW_RST | W1S | 0 | 软件复位触发。写 1 触发复位，自动清零 |
| [2:1] | SCOPE | RW | 3 | 复位范围。00=仅 sys，01=main+sys，11=全局 |
| [3] | WDT_EN | RW | 1 | WDT 复位使能。1=使能，0=禁用 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- SW_RST 为 W1S：写 1 触发复位，硬件自动清零
- 写 SW_RST=1 同时清除 RST_STATUS 中的标志位
- SCOPE 仅在 SW_RST 触发时生效

---

### 2.2 RST_STATUS (0x04) - 复位状态

**Access**: RO
**Reset Value**: 0x0000_0001
**REQ_ID**: REQ-M07-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | POR_FLAG | RO | 1 | 上次复位由 POR（上电复位）触发 |
| [1] | WDT_FLAG | RO | 0 | 上次复位由 WDT（看门狗）触发 |
| [2] | SW_FLAG | RO | 0 | 上次复位由软件触发 |
| [3] | RST_ACTIVE | RO | 0 | 当前复位输出状态（任一复位源有效时为 1） |
| [7:4] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |

#### 访问规则

- POR_FLAG/WDT_FLAG/SW_FLAG 互斥，仅一个为 1
- 写 RST_CTRL[SW_RST]=1 清除所有标志位

---

### 2.3 WDT_CFG (0x08) - 看门狗配置

**Access**: RW
**Reset Value**: 0x0000_FFFF
**REQ_ID**: REQ-M07-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [15:0] | WDT_PERIOD | RW | 0xFFFF | 看门狗超时周期（CLK_AON 计数值） |
| [16] | WDT_KICK | W1S | 0 | 喂狗操作。写 1 重置计数器，自动清零 |
| [17] | WDT_LOCK | RW | 0 | WDT_PERIOD 锁定。写 1 锁定，需 POR 解锁 |
| [31:18] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- WDT_KICK 为 W1S：写 1 重置看门狗计数器
- WDT_LOCK=1 后 WDT_PERIOD 不可修改，仅 POR 可解锁
- WDT_PERIOD=0 禁用看门狗（不推荐）

---

## 3. 编程示例

```c
// 1. 检查复位源
uint32_t status = REG_READ(RST_STATUS);
if (status & RST_STATUS_POR_FLAG) {
    printf("Power-on reset\n");
} else if (status & RST_STATUS_WDT_FLAG) {
    printf("Watchdog reset\n");
} else if (status & RST_STATUS_SW_FLAG) {
    printf("Software reset\n");
}

// 2. 配置看门狗超时周期
REG_WRITE(WDT_CFG, 0x8000);  // 超时周期 32768 CLK_AON cycles

// 3. 周期性喂狗
void watchdog_kick(void) {
    REG_WRITE(WDT_CFG, REG_READ(WDT_CFG) | (1 << 16));  // WDT_KICK=1
}

// 4. 锁定看门狗配置（防止软件误操作）
REG_WRITE(WDT_CFG, REG_READ(WDT_CFG) | (1 << 17));  // WDT_LOCK=1

// 5. 触发软件复位（全局）
REG_WRITE(RST_CTRL, (0x3 << 1) | 0x1);  // SCOPE=全局, SW_RST=1
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
RST_CTRL,0x00,32,RW,0x0000000E,Reset control register
RST_STATUS,0x04,32,RO,0x00000001,Reset status register
WDT_CFG,0x08,32,RW,0x0000FFFF,Watchdog configuration
```
