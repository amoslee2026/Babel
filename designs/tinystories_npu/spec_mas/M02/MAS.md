---
module: M02
type: MAS
status: complete
parent: null
module_type: storage
chiplet_features: [ECC_SECDED]
generated: "2026-05-17T15:00:00+08:00"
---

# M02: SRAM Scratchpad

## 1. Overview

M02 SRAM Scratchpad 是 TinyStories NPU 的高速片上存储模块，提供 512 KB 低延迟存储空间，用于激活值存储、算子间临时数据缓冲以及 KV Cache 部分。该模块位于 Main Power Domain (PD_MAIN)，运行于 CLK_SYS 时钟域 (250-500 MHz)，配备 SECDED ECC 保护以确保数据可靠性。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| Storage Capacity | 512 KB SRAM array | REQ-MEM-004 |
| ECC Protection | SECDED (39,32) - 单错纠正，双错检测 | REQ-MEM-005 |
| Access Latency | 单周期访问 (<= 2 ns @ 500 MHz) | REQ-MEM-003 |
| Bandwidth | >= 8 GB/s (读+写合计) | REQ-MEM-002 |
| Access Width | 32-bit / 64-bit 可配置 | - |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 可调 |
| Power Domain | PD_MAIN | 0.7-0.9 V，支持 Power Gate |
| Base Address | 0x8000_0000 | Memory Map 中的 SRAM 基地址 |
| Address Range | 0x8000_0000 - 0x8007_FFFF | 512 KB (128K x 32-bit) |

### 1.3 Use Cases

| Use Case | Bandwidth Allocation | Description |
|----------|---------------------|-------------|
| Activation Buffer | 4 GB/s | Prefill phase 激活值存储 |
| KV Cache (partial) | 2 GB/s | Decode phase KV 缓存部分 |
| Inter-op Dataflow | 2 GB/s | 算子间数据流缓冲 |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| clk_sys_i | Input | 1 | CLK_SYS | 主系统时钟 (250-500 MHz) |
| rst_sys_n_i | Input | 1 | CLK_SYS | 系统复位，低有效 |
| pg_main_en_i | Input | 1 | CLK_SYS | Power Gate 使能 (from M05) |

#### 2.1.2 System Bus Interface (TileLink/AXI)

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| bus_cmd_valid_i | Input | 1 | CLK_SYS | 总线命令有效 |
| bus_cmd_ready_o | Output | 1 | CLK_SYS | 总线命令就绪 |
| bus_cmd_addr_i | Input | 32 | CLK_SYS | 访问地址 (byte address) |
| bus_cmd_rw_i | Input | 1 | CLK_SYS | 读/写命令标识 (0=Read, 1=Write) |
| bus_cmd_width_i | Input | 2 | CLK_SYS | 访问宽度 (0=32-bit, 1=64-bit) |
| bus_cmd_wdata_i | Input | 64 | CLK_SYS | 写数据 (max 64-bit) |
| bus_cmd_wstrb_i | Input | 8 | CLK_SYS | 写字节使能 |
| bus_rsp_valid_o | Output | 1 | CLK_SYS | 响应有效 |
| bus_rsp_rdata_o | Output | 64 | CLK_SYS | 读响应数据 |
| bus_rsp_error_o | Output | 1 | CLK_SYS | 响应错误标志 |

#### 2.1.3 Compute Unit Direct Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sram_req_valid_i | Input | 1 | CLK_SYS | 直接访问请求有效 (from M00/M11/M12) |
| sram_req_addr_i | Input | 20 | CLK_SYS | 访问地址 (word address, 128K entries) |
| sram_req_rw_i | Input | 1 | CLK_SYS | 读/写标识 |
| sram_req_wdata_i | Input | 64 | CLK_SYS | 写数据 |
| sram_req_wstrb_i | Input | 8 | CLK_SYS | 写字节使能 |
| sram_rsp_valid_o | Output | 1 | CLK_SYS | 响应有效 |
| sram_rsp_rdata_o | Output | 64 | CLK_SYS | 读响应数据 |
| sram_rsp_error_o | Output | 1 | CLK_SYS | 响应错误标志 |

#### 2.1.4 Arbitration Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| arb_master_id_i | Input | 4 | CLK_SYS | 当前访问 Master ID |
| arb_priority_i | Input | 3 | CLK_SYS | 访问优先级 (0=Highest, 3=Lowest) |
| arb_grant_o | Output | 4 | CLK_SYS | 授权 Master ID |
| arb_busy_o | Output | 1 | CLK_SYS | SRAM 访问忙碌标志 |

#### 2.1.5 ECC Status Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| ecc_err_addr_o | Output | 32 | CLK_SYS | ECC 错误发生地址 |
| ecc_err_type_o | Output | 1 | CLK_SYS | 错误类型 (0=单错已纠正, 1=双错检测) |
| ecc_err_valid_o | Output | 1 | CLK_SYS | ECC 错误有效标志 |
| ecc_irq_o | Output | 1 | CLK_SYS | ECC 错误中断请求 |

#### 2.1.6 Power Management Interface

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| sram_retention_i | Input | 1 | CLK_SYS | SRAM Retention 模式使能 (Deep Sleep) |
| sram_power_gate_i | Input | 1 | CLK_SYS | SRAM Power Gate 使能 |
| sram_power_status_o | Output | 1 | CLK_SYS | SRAM 电源状态 |

### 2.2 Register Map (ECC Status Region: 0x800B_0000)

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | ECC_SRAM_ERR_ADDR | R | 32 | SRAM ECC 错误地址 |
| 0x0004 | ECC_SRAM_ERR_TYPE | R | 32 | 错误类型寄存器 |
| 0x0008 | ECC_SRAM_ERR_COUNT | R | 32 | ECC 错误计数器 |
| 0x000C | ECC_SRAM_CTRL | RW | 32 | ECC 控制寄存器 |
| 0x0010 | ECC_SRAM_STATUS | R | 32 | ECC 状态寄存器 |
| 0x0014 | ECC_SRAM_IRQ_EN | RW | 32 | ECC 中断使能寄存器 |
| 0x0018 | ECC_SRAM_IRQ_CLR | RW | 32 | ECC 中断清除寄存器 |

#### 2.2.1 Register Bit Definitions

**ECC_SRAM_ERR_ADDR (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:19] | err_addr | 错误发生的 SRAM 地址 (word address) |
| [20:31] | reserved | 保留 |

**ECC_SRAM_ERR_TYPE (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | err_type | 错误类型 (0=单错已纠正, 1=双错检测) |
| [1] | err_corrected | 单错已纠正标志 |
| [2] | err_detected | 双错检测标志 |
| [3:31] | reserved | 保留 |

**ECC_SRAM_ERR_COUNT (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:15] | single_err_count | 单错计数 |
| [16:31] | double_err_count | 双错计数 |

**ECC_SRAM_CTRL (0x000C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ecc_enable | ECC 功能使能 |
| [1] | ecc_auto_correct | 自动纠正单错使能 |
| [2] | ecc_irq_enable | ECC 错误中断使能 |
| [3] | ecc_count_enable | ECC 计数器使能 |
| [4:31] | reserved | 保留 |

**ECC_SRAM_STATUS (0x0010)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ecc_active | ECC 功能激活状态 |
| [1] | ecc_error_pending | 错误待处理标志 |
| [2] | ecc_correcting | 正在纠正错误 |
| [3:31] | reserved | 保留 |

**ECC_SRAM_IRQ_EN (0x0014)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | irq_single_err | 单错中断使能 |
| [1] | irq_double_err | 双错中断使能 |
| [2:31] | reserved | 保留 |

**ECC_SRAM_IRQ_CLR (0x0018)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | clr_single_err | 清除单错中断 |
| [1] | clr_double_err | 清除双错中断 |
| [2:31] | reserved | 保留 |

### 2.3 Master ID Mapping

| Master ID | Module | Description | Priority |
|-----------|--------|-------------|----------|
| 0x0 | M00 | Systolic Array | 0 (Highest) |
| 0x1-0x4 | M09-M12 | Transformer Operators | 1 |
| 0x5 | M13 | ISA Decoder | 2 |
| 0x6 | M15 | Debug/JTAG | 3 (Lowest) |
| 0x7-0xF | Reserved | - | - |

## 3. Functional Description

### 3.1 SRAM Array Organization

| Parameter | Value | Description |
|-----------|-------|-------------|
| Total Capacity | 512 KB | 131,072 x 32-bit words |
| Organization | 128 banks x 1024 words/bank | 多 Bank 并行访问 |
| Bank Width | 32-bit + 7-bit ECC | 39-bit total per word |
| Access Granularity | 32-bit / 64-bit | 可配置访问宽度 |

### 3.2 ECC Implementation (SECDED 39,32)

#### 3.2.1 ECC Encoding

| Data Width | ECC Bits | Code Word | Code Name |
|------------|----------|-----------|-----------|
| 32-bit | 7-bit | 39-bit | SECDED (39,32) |

ECC 位分布：
```
Bit Position:  [0-31] = Data (D0-D31)
               [32-38] = ECC Check Bits (C0-C6)

Check Bit Positions (Hamming Code):
  C0: covers bits 1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37
  C1: covers bits 2,3,6,7,10,11,14,15,18,19,22,23,26,27,30,31,34,35,38
  C2: covers bits 4-7,12-15,20-23,28-31,36-38
  C3: covers bits 8-15,24-31
  C4: covers bits 16-31
  C5: covers bits 32-38
  C6: overall parity (covers all bits)
```

#### 3.2.2 ECC Error Detection & Correction

| Error Type | Detection | Correction | Action |
|------------|-----------|------------|--------|
| No Error | Syndrome = 0 | - | Normal operation |
| Single-bit Error | Syndrome != 0, parity OK | Auto-correct | ECC_SRAM_ERR_TYPE[0]=0, IRQ |
| Double-bit Error | Syndrome != 0, parity fail | Detect only | ECC_SRAM_ERR_TYPE[0]=1, IRQ |

ECC Syndrome 解码：
```
Syndone = Syndrome XOR Expected_Parity
if Syndrome == 0:
    No Error
elif Syndrome[6] == 1:  # Overall parity matches
    Single-bit Error at position = Syndrome[0:5]
else:
    Double-bit Error detected
```

#### 3.2.3 ECC Processing Flow

```
SRAM Read Request
    |
    v
Read 39-bit code word from SRAM array
    |
    v
Calculate Syndrome (7-bit)
    |
    v
Check Syndrome
    |
    +-- Syndrome == 0 --> Return data directly
    |
    +-- Single-bit Error --> Correct bit, set error flag, return corrected data
    |
    +-- Double-bit Error --> Set error flag, return data with error indication
    |
    v
Update ECC_SRAM_ERR_ADDR, ECC_SRAM_ERR_TYPE, ECC_SRAM_ERR_COUNT
    |
    v
Generate IRQ if enabled
```

#### 3.2.4 Double Error Recovery (B07 Fix)

**REQ-M02-010: ECC Double Error Recovery**

| Recovery Action | Trigger | Implementation |
|-----------------|---------|----------------|
| Retry Read | First double error | Re-read (up to 3 retries) |
| Mark Bad Block | 3+ consecutive errors | Bad block register update |
| Data Rebuild | KV Cache region | Request M09 recompute from DRAM |
| Halt Thread | Activation region | Notify M01, halt affected thread |

#### 3.2.5 Address Boundary (B09 Fix)

**REQ-M02-011: Address Boundary Check**

| Boundary | Range | Error Response |
|----------|-------|----------------|
| Valid | 0x8000_0000 - 0x8007_FFFF | Normal access |
| Out of Range | >= 0x8008_0000 | Error flag + Zero data |

**Error Signals**: `addr_error_o` (1-bit), `addr_error_code_o`

### 3.3 Arbitration Logic

#### 3.3.1 Priority-Based Arbitration

| Priority Level | Master | Arbitration Policy |
|----------------|--------|--------------------|
| 0 (Highest) | M00 Systolic Array | Preemptive，立即授权 |
| 1 | M09-M12 Operators | Round-robin among same priority |
| 2 | M13 ISA Decoder | Wait for higher priority complete |
| 3 (Lowest) | M15 JTAG | Background access，lowest priority |

#### 3.3.2 Arbitration Algorithm

```
Arbitration Cycle:
    |
    v
Check arb_busy_o
    |
    +-- busy --> Wait for current access complete
    |
    v
Priority Check:
    |
    +-- Priority 0 request --> Grant immediately
    |
    +-- Priority 1 requests --> Round-robin among M09-M12
    |
    +-- Priority 2 request --> Grant if no higher priority pending
    |
    +-- Priority 3 request --> Grant if idle
    |
    v
Set arb_grant_o = Master ID
    |
    v
Process SRAM access (single cycle)
    |
    v
Clear arb_busy_o
```

#### 3.3.3 Bank Interleaving

| Feature | Description |
|---------|-------------|
| Bank Addressing | Address[16:19] selects bank (16 banks active simultaneously) |
| Interleaving Factor | 4 (4 consecutive addresses in different banks) |
| Parallelism | Up to 4 concurrent access without bank conflict |

Bank 访问规则：
- 连续地址分布在不同 Bank，减少 Bank Conflict
- Priority 0 访问可打断 Priority 1-3 的 Bank 等待
- 64-bit 访问占用相邻两个 Bank

### 3.4 Power Management

#### 3.4.1 Retention Mode

| Mode | Power Gate | Retention | Access |
|------|------------|-----------|--------|
| Active | OFF | OFF | Full access |
| Sleep | OFF | ON | Disabled |
| Deep Sleep | ON | ON | Disabled |

Retention 控制流程：
```
sram_retention_i = 1 (from M05)
    |
    v
Enable SRAM retention bias
    |
    v
Maintain minimum voltage (0.6V)
    |
    v
Data preserved, no access allowed
    |
    v
Wait for sram_retention_i = 0
    |
    v
Disable retention bias
    |
    v
Resume normal operation
```

#### 3.4.2 Power Gate Sequence

| Phase | Duration | Description |
|-------|----------|-------------|
| Save State | < 10 cycles | 保存关键状态寄存器 |
| Retention Enable | 1 cycle | 启用 SRAM retention |
| Power Gate | < 100 us | Power Gate 激活 |
| Power Restore | < 10 ms | Power Gate 释放 |
| Restore State | < 10 cycles | 恢复状态寄存器 |

### 3.5 Access Pipeline

#### 3.5.1 Single-Cycle Access

| Phase | Cycle | Operation |
|-------|-------|-----------|
| Address Decode | Cycle 0 | 解码地址，选择 Bank |
| SRAM Read/Write | Cycle 0 | 执行 SRAM 阵列访问 |
| ECC Processing | Cycle 0 | ECC 计算/纠错 (并行) |
| Response | Cycle 0 | 输出响应数据 |

Pipeline 特性：
- 单周期完成整个访问流程
- ECC 处理与数据访问并行
- 无流水线气泡，100% 利用率

#### 3.5.2 Bandwidth Calculation

| Configuration | Bandwidth | Calculation |
|---------------|-----------|-------------|
| 32-bit @ 500 MHz | 2 GB/s | 4 bytes * 500 MHz |
| 64-bit @ 500 MHz | 4 GB/s | 8 bytes * 500 MHz |
| Dual-port @ 500 MHz | 8 GB/s | 4 GB/s (read) + 4 GB/s (write) |

## 4. Timing

### 4.1 Access Timing Parameters

| Parameter | Value @ 500 MHz | Value @ 250 MHz | Description |
|-----------|-----------------|-----------------|-------------|
| t_access | 2 ns | 4 ns | 单次访问周期 |
| t_read | 2 ns | 4 ns | 读访问延迟 |
| t_write | 2 ns | 4 ns | 写访问延迟 |
| t_ecc_calc | 0 ns | 0 ns | ECC 计算并行 |
| t_response | 2 ns | 4 ns | 响应输出延迟 |

### 4.2 Arbitration Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_arb_decision | < 1 cycle | 仲裁决策时间 |
| t_grant_latency | 1 cycle | 授权延迟 |
| t_bank_conflict | 0-3 cycles | Bank 冲突等待时间 |

### 4.3 ECC Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_syndrome_calc | < 0.5 ns | Syndrome 计算时间 (并行) |
| t_error_correct | < 0.5 ns | 单错纠正时间 |
| t_error_report | 1 cycle | 错误报告延迟 |

### 4.4 Power Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_retention_enter | < 10 cycles | Retention 进入时间 |
| t_retention_exit | < 10 cycles | Retention 退出时间 |
| t_power_gate_enter | < 100 us | Power Gate 进入时间 |
| t_power_gate_exit | < 10 ms | Power Gate 退出时间 |

### 4.5 DVFS Impact

| OP | Frequency | Access Latency | Bandwidth |
|----|-----------|----------------|-----------|
| OP0 | 500 MHz | 2 ns | 8 GB/s |
| OP1 | 250 MHz | 4 ns | 4 GB/s |
| OP2 | 1 MHz (AON) | Disabled | 0 GB/s |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **Bank Organization**: 128 Bank 并行设计，支持高带宽并发访问，减少 Bank Conflict。

2. **ECC Integration**: SECDED ECC 完全并行处理，不增加访问延迟。ECC 逻辑与 SRAM 阵列访问同步执行。

3. **Arbitration Logic**: Priority-based 仲裁支持 Compute Unit 高优先级访问，确保推理性能。

4. **Power Management**: Retention 模式在 Deep Sleep 时保持数据，Power Gate 时完全断电。

5. **Direct Interface**: Compute Unit (M00/M11/M12) 可绕过 System Bus 直接访问 SRAM，减少延迟。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol |
|-----------|---------------|----------|
| System Bus | M04 System Bus | TileLink/AXI |
| Direct Access | M00, M11, M12 | Custom handshake |
| Arbitration | All Masters | Priority-based |
| Power Control | M05 Power Manager | Direct control |
| ECC Status | System Bus | Register access |

### 5.3 Verification Requirements

| Test Category | Description | Coverage Target |
|---------------|-------------|-----------------|
| SRAM Access | 32-bit/64-bit 读写，边界地址 | 100% address coverage |
| ECC Single Error | 单错检测、纠正、报告 | All syndrome values |
| ECC Double Error | 双错检测、报告、IRQ | All double-bit patterns |
| Arbitration | 所有 Priority 组合，Bank Conflict | 100% priority scenarios |
| Power Mode | Active/Sleep/Deep Sleep 切换 | All power transitions |
| DVFS | OP0/OP1 频率切换 | All DVFS transitions |

### 5.4 Power Budget Allocation

| Domain | Budget @ OP0 | Budget @ OP1 | Allocation |
|--------|-------------|-------------|------------|
| SRAM Array | 150 mW | 75 mW | Active power |
| ECC Logic | 20 mW | 10 mW | Syndrome calc + correction |
| Arbitration | 10 mW | 5 mW | Arb logic + routing |
| Bus Interface | 20 mW | 10 mW | TileLink/AXI interface |
| **Total** | **200 mW** | **100 mW** | REQ-PWR-001 compliance |

### 5.5 Physical Design Requirements

| Requirement | Value | Description |
|-------------|-------|-------------|
| SRAM Density | >= 0.5 MB/mm^2 | 标准 7nm SRAM 密度 |
| Bank Width | 32-bit + 7 ECC | 39-bit per Bank |
| Retention Voltage | 0.6 V | Retention 模式最小电压 |
| Power Gate Header/Footer | Required | 支持 Deep Sleep |

### 5.6 Testability (DFT)

| Feature | Description |
|---------|-------------|
| BIST (Built-in Self Test) | SRAM 阵列自测试，支持 March C+ 算法 |
| ECC Test Mode | 可注入错误位测试 ECC 功能 |
| Margin Test | 可调整 SRAM 时序裕量测试 |
| Power Gate Test | Power Gate 序列测试模式 |

### 5.7 Quality Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| Soft Error Rate | < 10 FIT | 单位时间软错误率 |
| Hard Error Rate | < 0.1 FIT | 单位时间硬错误率 |
| ECC Coverage | 100% | 所有 SRAM 字都有 ECC 保护 |
| Availability | > 99.99% | 考虑 ECC 纠错后的可用性 |

## 6. Dependencies

| Module | Dependency Type | Description |
|--------|-----------------|-------------|
| M00 Systolic Array | Data consumer | 激活值、权重读取 |
| M04 System Bus | Bus interface | TileLink/AXI 总线连接 |
| M05 Power Manager | Power control | DVFS, Power Gate, Retention |
| M06 Clock Manager | Clock source | CLK_SYS 时钟 |
| M09-M12 Operators | Data consumer | Transformer 算子数据存储 |
| M13 ISA Decoder | Instruction data | 指令相关数据 |
| M15 JTAG | Debug access | 调试模式下 SRAM 访问 |