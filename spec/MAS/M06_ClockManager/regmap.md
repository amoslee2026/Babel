# M06_ClockManager 寄存器映射

<!-- REQ-M06-R001 ~ REQ-M06-R003 -->

**Base Address**: 由 SoC 地址映射分配（APB 从接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| CLK_CTRL   | 0x00 | 32 | RW | 0x0000_0000 | REQ-M06-R001 | 时钟控制：PLL 使能、时钟门控 |
| PLL_CFG    | 0x04 | 32 | RW | 0x0010_3D09 | REQ-M06-R002 | PLL 配置：倍频系数、环路带宽 |
| CLK_STATUS | 0x08 | 32 | RO | 0x0000_0000 | REQ-M06-R003 | 时钟状态：PLL 锁定、时钟稳定 |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |

---

## 2. 寄存器详细定义

### 2.1 CLK_CTRL (0x00) - 时钟控制

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M06-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | PLL_EN | RW | 0 | PLL 使能。1=使能，0=禁用 |
| [1] | CLK_GATE_EN | RW | 0 | 时钟门控使能。1=使能，0=禁用 |
| [7:2] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- PLL_EN 切换后需等待 PLL_LOCK=1 方可使用输出时钟
- CLK_GATE_EN 变更在当前时钟周期结束后生效

---

### 2.2 PLL_CFG (0x04) - PLL 配置

**Access**: RW
**Reset Value**: 0x0010_3D09
**REQ_ID**: REQ-M06-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [15:0] | DIV_RATIO | RW | 0x3D09 | PLL 倍频系数（15625 = 500MHz/32kHz） |
| [23:16] | BW_CFG | RW | 0x10 | 环路带宽配置 |
| [31:24] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- 修改 PLL 配置前需先禁用 PLL（PLL_EN=0）
- 修改后需重新使能 PLL 并等待 PLL_LOCK=1

---

### 2.3 CLK_STATUS (0x08) - 时钟状态

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M06-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | PLL_LOCK | RO | 0 | PLL 锁定状态。1=已锁定 |
| [1] | CLK_STABLE | RO | 0 | 时钟稳定指示。1=时钟输出稳定 |
| [7:2] | RESERVED | - | 0 | 保留 |
| [31:8] | RESERVED | - | 0 | 保留 |

---

## 3. 编程示例

```c
// 1. 配置 PLL 倍频系数（先禁用 PLL）
REG_WRITE(CLK_CTRL, REG_READ(CLK_CTRL) & ~CLK_CTRL_PLL_EN);
REG_WRITE(PLL_CFG, (0x3D09 << 0) | (0x10 << 16));  // 500MHz, BW=0x10

// 2. 使能 PLL
REG_WRITE(CLK_CTRL, CLK_CTRL_PLL_EN);

// 3. 等待 PLL 锁定
while (!(REG_READ(CLK_STATUS) & CLK_STATUS_PLL_LOCK));

// 4. 使能时钟门控
REG_WRITE(CLK_CTRL, REG_READ(CLK_CTRL) | CLK_CTRL_CLK_GATE_EN);

// 5. 检查时钟稳定
if (REG_READ(CLK_STATUS) & CLK_STATUS_CLK_STABLE) {
    printf("Clock stable\n");
}
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
CLK_CTRL,0x00,32,RW,0x00000000,Clock control register
PLL_CFG,0x04,32,RW,0x00103D09,PLL configuration
CLK_STATUS,0x08,32,RO,0x00000000,Clock status register
```
