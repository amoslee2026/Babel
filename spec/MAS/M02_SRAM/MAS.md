---
module: M02
type: MAS
status: complete
parent: TOP
module_type: storage
generated: 2026-05-12T09:25:00Z
---

# M02_SRAM 模块实现规范

## 模块概述

512 KB Scratchpad SRAM，作为 Systolic Array (M00) 和 Dataflow Controller (M01) 的本地数据缓冲。

| 参数 | 值 |
|------|-----|
| 容量 | 512 KB |
| 时钟域 | CLK_SYS (500 MHz) |
| 电源域 | PD_MAIN |
| 数据位宽 | 256 bit |
| 地址位宽 | 19 bit (512K / 32B = 16K entries) |
| ECC | SECDED (Single Error Correction, Double Error Detection) |
| 工艺 | Samsung SF4 4nm |

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 系统时钟 CLK_SYS |
| rst_n | input | 1 | 异步复位，低有效 |
| addr | input | 19 | 地址 [18:0] |
| wdata | input | 256 | 写数据 |
| rdata | output | 256 | 读数据 |
| we | input | 1 | 写使能 |
| re | input | 1 | 读使能 |
| ready | output | 1 | 就绪信号 |
| ecc_err | output | 2 | ECC错误：00=无错，01=单比特纠正，10=双比特检测 |
| bus_req | input | 1 | 总线请求 (from M04) |
| bus_grant | output | 1 | 总线授权 |
| bus_addr | input | 32 | 总线地址 |
| bus_wdata | input | 256 | 总线写数据 |
| bus_rdata | output | 256 | 总线读数据 |
| bus_we | input | 1 | 总线写使能 |

## 存储组织

### Bank 划分

4 个 bank，每个 128 KB，支持并行访问不同 bank。

| Bank | 地址范围 | 容量 |
|------|----------|------|
| Bank 0 | 0x00000 - 0x07FFF | 128 KB |
| Bank 1 | 0x08000 - 0x0FFFF | 128 KB |
| Bank 2 | 0x10000 - 0x17FFF | 128 KB |
| Bank 3 | 0x18000 - 0x1FFFF | 128 KB |

Bank 选择：`bank_sel = addr[18:17]`

### 存储单元

每个 bank：
- 4096 行 × 256 bit
- 单端口 SRAM 宏单元
- 读延迟：1 cycle
- 写延迟：1 cycle

## ECC 方案

### SECDED 编码

- 数据位：256 bit
- 校验位：9 bit (Hamming code)
- 总存储：265 bit/entry
- 编码：写入时生成校验位
- 解码：读出时检测并纠正

### ECC 功能

| 错误类型 | 检测 | 纠正 | ecc_err |
|----------|------|------|---------|
| 无错误 | ✓ | - | 2'b00 |
| 单比特错误 | ✓ | ✓ | 2'b01 |
| 双比特错误 | ✓ | ✗ | 2'b10 |
| 多比特错误 | 部分 | ✗ | 2'b10 |

## 寄存器

### SRAM_CTRL (偏移 0x0000)

| 位 | 名称 | 读写 | 复位值 | 描述 |
|----|------|------|--------|------|
| [0] | EN | RW | 1'b1 | SRAM 使能 |
| [1] | ECC_EN | RW | 1'b1 | ECC 使能 |
| [3:2] | BANK_MODE | RW | 2'b00 | Bank 模式：00=独立，01=交织 |
| [31:4] | RSVD | RO | 0 | 保留 |

### ECC_STATUS (偏移 0x0004)

| 位 | 名称 | 读写 | 复位值 | 描述 |
|----|------|------|--------|------|
| [15:0] | SEC_CNT | RO | 0 | 单比特纠正计数 |
| [31:16] | DED_CNT | RO | 0 | 双比特检测计数 |

### ECC_ADDR (偏移 0x0008)

| 位 | 名称 | 读写 | 复位值 | 描述 |
|----|------|------|--------|------|
| [18:0] | ERR_ADDR | RO | 0 | 最近错误地址 |
| [31:19] | RSVD | RO | 0 | 保留 |

## 时序约束

| 参数 | 值 | 单位 |
|------|-----|------|
| 时钟周期 | 2.0 | ns |
| 建立时间 | 0.2 | ns |
| 保持时间 | 0.1 | ns |
| 读访问时间 | 1 | cycle |
| 写访问时间 | 1 | cycle |
| ECC 延迟 | 0.5 | ns |

## 功耗估算

| 模式 | 功耗 | 条件 |
|------|------|------|
| Active Read | 45 mW | 500 MHz, 50% 活动率 |
| Active Write | 52 mW | 500 MHz, 50% 活动率 |
| Idle | 8 mW | 时钟门控 |
| Standby | 1.2 mW | 电源门控 |

## 面积估算

| 组件 | 面积 (mm²) |
|------|-----------|
| SRAM 宏单元 | 0.85 |
| ECC 逻辑 | 0.08 |
| 控制逻辑 | 0.05 |
| 总计 | 0.98 |
