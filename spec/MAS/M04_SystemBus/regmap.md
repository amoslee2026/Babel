# M04_SystemBus 寄存器映射

<!-- REQ-M04-R001 ~ REQ-M04-R007 -->

**Base Address**: 由 SoC 地址映射分配（APB 从接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| BUS_CTRL      | 0x00 | 32 | RW | 0x0001 | REQ-M04-R001 | 总线控制：使能、仲裁模式 |
| ARB_CFG       | 0x04 | 32 | RW | 0x3210 | REQ-M04-R002 | 仲裁优先级配置 |
| BUS_STATUS    | 0x08 | 32 | RO | 0x0000 | REQ-M04-R003 | 总线状态：当前 master、busy、deadlock |
| BW_COUNTER_M00 | 0x0C | 32 | RO | 0x0000 | REQ-M04-R004 | M00 带宽计数器 (bytes/ms) |
| BW_COUNTER_M01 | 0x10 | 32 | RO | 0x0000 | REQ-M04-R005 | M01 带宽计数器 |
| BW_COUNTER_M02 | 0x14 | 32 | RO | 0x0000 | REQ-M04-R006 | M02 带宽计数器 |
| BW_COUNTER_M03 | 0x18 | 32 | RO | 0x0000 | REQ-M04-R007 | M03 带宽计数器 |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |

---

## 2. 寄存器详细定义

### 2.1 BUS_CTRL (0x00) - 总线控制

**Access**: RW
**Reset Value**: 0x0000_0001
**REQ_ID**: REQ-M04-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | BUS_ENABLE | RW | 1 | 总线使能。1=使能，0=禁用 |
| [1] | ARB_MODE | RW | 0 | 仲裁模式。0=Round-Robin，1=Priority |
| [7:2] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- 切换 ARB_MODE 需等待当前传输完成

---

### 2.2 ARB_CFG (0x04) - 仲裁优先级配置

**Access**: RW
**Reset Value**: 0x0000_3210
**REQ_ID**: REQ-M04-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [3:0] | M00_PRI | RW | 0 | M00 (Systolic) 优先级 (0=最高) |
| [7:4] | M01_PRI | RW | 1 | M01 (Dataflow) 优先级 |
| [11:8] | M02_PRI | RW | 2 | M02 (SRAM) 优先级 |
| [15:12] | M03_PRI | RW | 3 | M03 (DRAM) 优先级 |
| [31:16] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- 仅在 ARB_MODE=1 (Priority) 时生效
- 优先级值越小优先级越高

---

### 2.3 BUS_STATUS (0x08) - 总线状态

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M04-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [3:0] | CURRENT_MASTER | RO | 0 | 当前占用总线的 Master ID |
| [4] | BUS_BUSY | RO | 0 | 总线忙标志 |
| [5] | DEADLOCK_DETECT | RO | 0 | 死锁检测标志 |
| [7:6] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |

---

### 2.4 BW_COUNTER_M00 (0x0C) - M00 带宽计数器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M04-R004

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | M00 带宽计数 (bytes/ms) |

---

### 2.5 BW_COUNTER_M01 (0x10) - M01 带宽计数器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M04-R005

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | M01 带宽计数 (bytes/ms) |

---

### 2.6 BW_COUNTER_M02 (0x14) - M02 带宽计数器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M04-R006

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | M02 带宽计数 (bytes/ms) |

---

### 2.7 BW_COUNTER_M03 (0x18) - M03 带宽计数器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M04-R007

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | M03 带宽计数 (bytes/ms) |

---

## 3. 编程示例

```c
// 1. 配置优先级仲裁模式
REG_WRITE(ARB_CFG, (0 << 0) | (1 << 4) | (2 << 8) | (3 << 12));
REG_WRITE(BUS_CTRL, BUS_CTRL_ENABLE | BUS_CTRL_ARB_MODE);

// 2. 监控带宽分配
for (int i = 0; i < 4; i++) {
    uint32_t bw = REG_READ(BW_COUNTER_M00 + i * 4);
    printf("Master %d: %u bytes/ms\n", i, bw);
}

// 3. 检查死锁
if (REG_READ(BUS_STATUS) & BUS_STATUS_DEADLOCK_DETECT) {
    printf("Deadlock detected!\n");
}
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
BUS_CTRL,0x00,32,RW,0x00000001,Bus control
ARB_CFG,0x04,32,RW,0x00003210,Arbitration priority config
BUS_STATUS,0x08,32,RO,0x00000000,Bus status
BW_COUNTER_M00,0x0C,32,RO,0x00000000,M00 bandwidth counter
BW_COUNTER_M01,0x10,32,RO,0x00000000,M01 bandwidth counter
BW_COUNTER_M02,0x14,32,RO,0x00000000,M02 bandwidth counter
BW_COUNTER_M03,0x18,32,RO,0x00000000,M03 bandwidth counter
```
