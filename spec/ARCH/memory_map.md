# Memory Architecture

## Memory Types

| Type | Size | Purpose | ECC | REQ |
|------|------|---------|-----|-----|
| DRAM | 2 GB | 模型权重、KV cache、中间结果 | SECDED | REQ-MEM-001, REQ-MEM-005 |
| SRAM | 512 KB | Scratchpad（激活值、临时数据） | SECDED | REQ-MEM-004, REQ-MEM-005 |
| Registers | 4 KB | 控制寄存器、状态寄存器 | None | - |

## Memory Performance Parameters

| Parameter | DRAM | SRAM | REQ |
|-----------|------|------|-----|
| Bandwidth (读+写) | >= 10 GB/s | >= 8 GB/s | REQ-MEM-002 |
| Latency (row hit) | <= 100 ns | <= 2 ns | REQ-MEM-003 |
| Latency (row miss) | <= 50 ns | - | - |
| Access Width | 32/64/128 bit | 32/64 bit | - |

## ECC Implementation

| Memory | ECC Type | Protection | Correction |
|--------|----------|------------|------------|
| DRAM | SECDED (72,64) | 单错检测+纠正，双错检测 | Hardware auto-correct |
| SRAM | SECDED (39,32) | 单错检测+纠正，双错检测 | Hardware auto-correct |

**ECC 状态寄存器**：
- `ECC_DRAM_ERR_ADDR`: DRAM 错误地址
- `ECC_DRAM_ERR_TYPE`: 错误类型（0=单错已纠正，1=双错检测）
- `ECC_SRAM_ERR_ADDR`: SRAM 错误地址
- `ECC_SRAM_ERR_TYPE`: 错误类型

## Memory Map

| Base Address | Size | Type | Access | Module |
|--------------|------|------|--------|--------|
| 0x0000_0000 | 2 GB | DRAM | RW | M03 |
| 0x8000_0000 | 512 KB | SRAM | RW | M02 |
| 0x8008_0000 | 4 KB | Registers | RW | M04 |
| 0x8009_0000 | 4 KB | ISA Registers | RW | M13 |
| 0x800A_0000 | 4 KB | Security Registers | RW | M14 |
| 0x800B_0000 | 4 KB | ECC Status | RW | M02, M03 |

## Register Map (Detailed)

### ISA Decoder Registers (M13)

| Offset | Name | R/W | Description |
|--------|------|-----|-------------|
| 0x000 | ISA_INST | W | 当前指令 |
| 0x004 | ISA_OP | R | 解码后的操作码 |
| 0x008 | ISA_RD | R | 目标寄存器 |
| 0x00C | ISA_RS1 | R | 源寄存器1 |
| 0x010 | ISA_RS2 | R | 源寄存器2 |
| 0x014 | ISA_IMM | R | 立即数 |

### Security Registers (M14)

| Offset | Name | R/W | Description |
|--------|------|-----|-------------|
| 0x000 | SEC_BOOT_EN | RW | Secure Boot 启用标志 REQ-SEC-001 |
| 0x004 | SEC_FW_HASH | R | 固件哈希值 |
| 0x008 | SEC_STATUS | R | 安全状态（0=验证通过，1=失败） |

### Power Manager Registers (M05)

| Offset | Name | R/W | Description |
|--------|------|-----|-------------|
| 0x000 | PWR_MODE | RW | 功耗模式（0=Active, 1=Sleep, 2=Deep） |
| 0x004 | DVFS_OP | RW | DVFS 工作点（0=High, 1=Low） REQ-PWR-003 |
| 0x008 | PWR_ESTIMATE | R | 当前功耗估算值 |

## Memory Bandwidth Allocation

| Use Case | DRAM BW | SRAM BW | Notes |
|----------|---------|---------|-------|
| Weight loading | 8 GB/s | - | 模型加载 |
| KV cache | 4 GB/s | 2 GB/s | Decode phase |
| Activation | 4 GB/s | 4 GB/s | Prefill phase |
| Inter-op | - | 2 GB/s | 算子间数据流 |

## Memory Access Arbitration

| Priority | Master | Use Case |
|----------|--------|----------|
| 0 (Highest) | M00 (Systolic Array) | Compute |
| 1 | M09-M12 (Operators) | Transformer ops |
| 2 | M13 (ISA Decoder) | Instruction fetch |
| 3 | Debug/JTAG (M15) | 调试访问 |
