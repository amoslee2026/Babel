# M03_DRAMController 寄存器映射

<!-- REQ-M03-R001 ~ REQ-M03-R004 -->

**Base Address**: `0xC000_0000`（APB 配置接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| DRAM_CTRL   | 0x00 | 32 | RW  | 0x0000_0001 | REQ-M03-R001 | 控制寄存器：使能、自刷新、ECC |
| TIMING_CFG  | 0x04 | 32 | RW  | 0x2412_1218 | REQ-M03-R002 | 时序参数：tRCD、tCL、tRP、tRAS |
| ECC_STATUS  | 0x08 | 32 | W1C | 0x0000_0000 | REQ-M03-R003 | ECC 状态：SBE/DBE 标志、错误地址 |
| PERF_CNT    | 0x0C | 32 | RO  | 0x0000_0000 | REQ-M03-R004 | 性能计数器 |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |
| W1C  | 写 1 清零 | 返回当前值 | 写 1 清零，写 0 无效 |

---

## 2. 寄存器详细定义

### 2.1 DRAM_CTRL (0x00) - 控制寄存器

**Access**: RW
**Reset Value**: 0x0000_0001
**REQ_ID**: REQ-M03-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | EN | RW | 1 | 控制器使能。1=使能，0=禁用 |
| [1] | SELF_REFRESH | RW | 0 | 自刷新模式。1=进入自刷新 |
| [2] | ECC_EN | RW | 0 | ECC 使能。1=使能 |
| [3] | ECC_IRQ_EN | RW | 0 | ECC 双比特错误中断使能 |
| [7:4] | BURST_LEN | RW | 8 | 突发长度配置（默认 BL8） |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- SELF_REFRESH 切换需等待 DRAM 空闲
- ECC_EN 变更需重新初始化 DRAM

---

### 2.2 TIMING_CFG (0x04) - 时序参数配置

**Access**: RW
**Reset Value**: 0x2412_1218
**REQ_ID**: REQ-M03-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [7:0] | tRCD | RW | 0x18 | 行到列延迟（单位 CLK_SYS） |
| [15:8] | tCL | RW | 0x12 | CAS 延迟 |
| [23:16] | tRP | RW | 0x12 | 预充电时间 |
| [31:24] | tRAS | RW | 0x24 | 行激活时间 |

#### 访问规则

- 修改时序参数需先禁用控制器（EN=0）
- 复位值对应 DDR4-2400 默认时序

---

### 2.3 ECC_STATUS (0x08) - ECC 状态

**Access**: W1C (标志位)
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M03-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | SBE | W1C | 0 | 单比特错误标志。写 1 清零 |
| [1] | DBE | W1C | 0 | 双比特错误标志。写 1 清零 |
| [15:2] | RESERVED | - | 0 | 保留 |
| [31:16] | ERR_ADDR | RO | 0 | 最近错误地址高 16 位 |

#### 访问规则

- SBE/DBE 标志为 W1C，写 1 清零，写 0 无效
- ERR_ADDR 为只读，保留最近错误地址

---

### 2.4 PERF_CNT (0x0C) - 性能计数器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M03-R004

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | 内存访问周期计数 |

---

## 3. 编程示例

```c
// 1. 配置时序参数（先禁用控制器）
REG_WRITE(DRAM_CTRL, REG_READ(DRAM_CTRL) & ~DRAM_CTRL_EN);
REG_WRITE(TIMING_CFG, 0x2412_1218);  // DDR4-2400 默认时序

// 2. 使能 ECC 和控制器
REG_WRITE(DRAM_CTRL, DRAM_CTRL_EN | DRAM_CTRL_ECC_EN | (8 << 4));

// 3. 检查 ECC 错误
uint32_t ecc = REG_READ(ECC_STATUS);
if (ecc & ECC_STATUS_DBE) {
    uint32_t addr = (ecc >> 16) & 0xFFFF;
    printf("DBE error at 0x%x\n", addr << 16);
    REG_WRITE(ECC_STATUS, ECC_STATUS_DBE);  // W1C 清除
}
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
DRAM_CTRL,0x00,32,RW,0x00000001,Control register
TIMING_CFG,0x04,32,RW,0x24121218,Timing configuration
ECC_STATUS,0x08,32,W1C,0x00000000,ECC status
PERF_CNT,0x0C,32,RO,0x00000000,Performance counter
```
