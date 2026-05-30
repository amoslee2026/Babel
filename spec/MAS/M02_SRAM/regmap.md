# M02_SRAM 寄存器映射

<!-- REQ-M02-R001 ~ REQ-M02-R003 -->

**Base Address**: 由 M04_SystemBus 分配（APB 从接口）
**Address Space**: `16` bits (64 KB)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| SRAM_CTRL  | 0x0000 | 32 | RW | 0x3 | REQ-M02-R001 | 控制寄存器：使能、ECC、Bank 模式 |
| ECC_STATUS | 0x0004 | 32 | RO | 0x0 | REQ-M02-R002 | ECC 错误统计：SEC/DED 计数 |
| ECC_ADDR   | 0x0008 | 32 | RO | 0x0 | REQ-M02-R003 | 最近 ECC 错误地址 |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |

---

## 2. 寄存器详细定义

### 2.1 SRAM_CTRL (0x0000) - 控制寄存器

**Access**: RW
**Reset Value**: 0x0000_0003
**REQ_ID**: REQ-M02-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | EN | RW | 1 | SRAM 使能。1=使能，0=禁用 |
| [1] | ECC_EN | RW | 1 | ECC 使能。1=使能，0=禁用 |
| [3:2] | BANK_MODE | RW | 0 | Bank 模式。00=独立，01=交织 |
| [7:4] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- 禁用 EN 后所有读写请求返回错误
- ECC_EN 变更不影响已有数据，仅影响后续读写

---

### 2.2 ECC_STATUS (0x0004) - ECC 错误统计

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M02-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [15:0] | SEC_CNT | RO | 0 | 单比特纠正累计计数 |
| [31:16] | DED_CNT | RO | 0 | 双比特检测累计计数 |

#### 访问规则

- 计数器只增不减，仅 POR 复位清零
- SEC_CNT 饱和后停止计数（0xFFFF）

---

### 2.3 ECC_ADDR (0x0008) - 最近错误地址

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M02-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [18:0] | ERR_ADDR | RO | 0 | 最近 ECC 错误地址（19-bit 字地址） |
| [31:19] | RESERVED | - | 0 | 保留 |

#### 访问规则

- 每次检测到 SEC 或 DED 错误时更新
- 仅保留最近一次错误地址

---

## 3. 编程示例

```c
// 1. 检查 ECC 使能状态
if (!(REG_READ(SRAM_CTRL) & SRAM_CTRL_ECC_EN)) {
    printf("Warning: ECC disabled\n");
}

// 2. 查询 ECC 错误统计
uint32_t status = REG_READ(ECC_STATUS);
uint16_t sec_cnt = status & 0xFFFF;
uint16_t ded_cnt = (status >> 16) & 0xFFFF;

if (ded_cnt > 0) {
    uint32_t err_addr = REG_READ(ECC_ADDR) & 0x7FFFF;
    printf("DED error at addr 0x%x\n", err_addr);
}
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
SRAM_CTRL,0x0000,32,RW,0x00000003,Control register
ECC_STATUS,0x0004,32,RO,0x00000000,ECC error statistics
ECC_ADDR,0x0008,32,RO,0x00000000,Last ECC error address
```
