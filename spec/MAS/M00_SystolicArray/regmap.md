# M00_SystolicArray 寄存器映射

<!-- REQ-M00-R001 ~ REQ-M00-R004 -->

**Base Address**: 由 M04_SystemBus 分配（APB 从接口）
**Address Space**: `8` bits (256 bytes)

---

## 1. 寄存器列表

| 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
|---------|---------|------|---------|--------|--------|---------|
| SA_CTRL     | 0x00 | 32 | RW | 0x0 | REQ-M00-R001 | 控制寄存器：start、soft_rst、precision、dataflow_mode |
| SA_STATUS   | 0x04 | 32 | RO | 0x0 | REQ-M00-R002 | 状态寄存器：busy、done、stall、fsm_state |
| SA_DIM_CFG  | 0x08 | 32 | RW | 0x0 | REQ-M00-R003 | 矩阵维度配置：dim_m、dim_n、dim_k |
| SA_PERF_CNT | 0x0C | 32 | RO | 0x0 | REQ-M00-R004 | 计算周期计数器（每次 start 清零） |

### 1.1 访问类型说明

| 类型 | 含义 | 读操作 | 写操作 |
|------|------|--------|--------|
| RW   | 读写 | 返回当前值 | 写入新值 |
| RO   | 只读 | 返回当前值 | 忽略 |

---

## 2. 寄存器详细定义

### 2.1 SA_CTRL (0x00) - 控制寄存器

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M00-R001

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | START | RW | 0 | 启动计算。写 1 启动，完成后自动清零 |
| [1] | SOFT_RST | RW | 0 | 软复位。写 1 触发内部复位，自清零 |
| [3:2] | PRECISION | RW | 0 | 精度选择。00=INT8, 01=FP16, 10=BF16 |
| [4] | DATAFLOW_MODE | RW | 0 | 数据流模式。0=output-stationary, 1=weight-stationary |
| [7:5] | RESERVED | - | 0 | 保留，必须写 0 |
| [31:8] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- START 写 1 启动计算，硬件完成后自动清零
- SOFT_RST 为自清零位

---

### 2.2 SA_STATUS (0x04) - 状态寄存器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M00-R002

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [0] | BUSY | RO | 0 | 忙标志。1=正在计算 |
| [1] | DONE | RO | 0 | 完成标志。1=上次计算完成 |
| [2] | STALL | RO | 0 | 停顿标志。1=数据通路停顿 |
| [7:4] | FSM_STATE | RO | 0 | 当前 FSM 状态编码 |
| [31:8] | RESERVED | - | 0 | 保留 |

---

### 2.3 SA_DIM_CFG (0x08) - 矩阵维度配置

**Access**: RW
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M00-R003

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [4:0] | DIM_M | RW | 0 | 矩阵 M 维度 (0-31) |
| [9:5] | DIM_N | RW | 0 | 矩阵 N 维度 (0-31) |
| [19:10] | DIM_K | RW | 0 | 矩阵 K 维度 (0-1023) |
| [31:20] | RESERVED | - | 0 | 保留，必须写 0 |

#### 访问规则

- 计算进行中（BUSY=1）时修改维度配置无效，下次 START 生效

---

### 2.4 SA_PERF_CNT (0x0C) - 性能计数器

**Access**: RO
**Reset Value**: 0x0000_0000
**REQ_ID**: REQ-M00-R004

#### 位域定义

| 位 | 名称 | 访问 | 复位值 | 功能 |
|----|------|------|--------|------|
| [31:0] | COUNT | RO | 0 | 计算周期计数。每次 START 清零 |

---

## 3. 编程示例

```c
// 1. 配置矩阵维度
REG_WRITE(SA_DIM_CFG, (8 << 0) | (8 << 5) | (8 << 10));  // 8x8x8

// 2. 配置精度和数据流模式
REG_WRITE(SA_CTRL, (0x01 << 2) | (0 << 4));  // FP16, output-stationary

// 3. 启动计算
REG_WRITE(SA_CTRL, REG_READ(SA_CTRL) | 0x1);  // START=1

// 4. 等待完成
while (REG_READ(SA_STATUS) & SA_STATUS_BUSY);

// 5. 读取性能计数
uint32_t cycles = REG_READ(SA_PERF_CNT);
```

---

## 6. 寄存器地址映射表

```csv
Name,Offset,Width,Access,Reset,Description
SA_CTRL,0x00,32,RW,0x00000000,Control register
SA_STATUS,0x04,32,RO,0x00000000,Status register
SA_DIM_CFG,0x08,32,RW,0x00000000,Matrix dimension configuration
SA_PERF_CNT,0x0C,32,RO,0x00000000,Performance counter
```
