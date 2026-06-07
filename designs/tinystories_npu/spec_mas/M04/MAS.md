---
module: M04
type: MAS
status: complete
parent: null
module_type: interconnect
generated: "2026-05-17T15:30:00+08:00"
---

# M04: System Bus

## 1. Overview

M04 System Bus 是 TinyStories NPU 的核心互联模块，位于 PD_MAIN 电源域，负责连接计算子系统（M00）、存储子系统（M02/M03）、控制模块（M13/M14）以及外部 IO 接口（M15/M16）。该模块实现 TileLink/AXI 双协议支持、多 Master 仲裁、地址路由和跨时钟域同步四大功能，确保各模块间高效、可靠的数据传输，满足 REQ-MEM-002 规定的 >= 10 GB/s DRAM bandwidth 和 >= 8 GB/s SRAM bandwidth 目标。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| TileLink/AXI Dual-Protocol | 支持 TileLink-UH 和 AXI4 协议，灵活适配不同 Master | - |
| Multi-Master Arbitration | 支持 5 个 Master 请求源，优先级仲裁策略 | REQ-MEM-002 |
| Address Routing | 基于地址映射的 Slave 选择，支持 DRAM/SRAM/Register 空间 | - |
| CDC Synchronization | CLK_SYS/CLK_IO/CLK_AON 跨时钟域处理 | REQ-IO-001, REQ-IO-002 |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 支持 |
| Power Domain | PD_MAIN | 0.7-0.9 V，可 Power Gate |
| Target Power | 50 mW | Bus logic + arbitration @ OP0 |

## 2. Interface

### 2.1 Master Ports (Request Sources)

M04 接收以下 Master 模块的请求：

| Port ID | Master Module | Protocol | Clock Domain | Priority | Description |
|---------|---------------|----------|--------------|----------|-------------|
| M0 | M00 Systolic Array | TileLink-UH | CLK_SYS | 0 (Highest) | Compute data access |
| M1 | M02 SRAM Scratchpad | TileLink-UH | CLK_SYS | 2 | Scratchpad DMA |
| M2 | M03 DRAM Controller | TileLink-UH | CLK_SYS | 2 | DRAM DMA |
| M3 | M13 ISA Decoder | AXI4 | CLK_SYS | 1 | Instruction fetch |
| M4 | M15 JTAG Interface | AXI4 | CLK_IO | 3 (Lowest) | Debug access |

#### 2.1.1 TileLink-UH Master Interface (M0, M1, M2)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tl_a_valid | Input | 1 | TileLink Channel A valid |
| tl_a_ready | Output | 1 | TileLink Channel A ready |
| tl_a_opcode | Input | 3 | Operation code (PutFullData=0, Get=4, etc.) |
| tl_a_param | Input | 3 | Parameter (burst info) |
| tl_a_size | Input | 3 | Transaction size (log2 bytes) |
| tl_a_source | Input | 4 | Source ID (Master port ID) |
| tl_a_address | Input | 32 | Target address |
| tl_a_mask | Input | 16 | Byte mask for write |
| tl_a_data | Input | 128 | Write data |
| tl_a_corrupt | Input | 1 | Data corrupt flag |
| tl_d_valid | Output | 1 | TileLink Channel D valid |
| tl_d_ready | Input | 1 | TileLink Channel D ready |
| tl_d_opcode | Output | 3 | Response opcode (AccessAck=0, AccessAckData=1) |
| tl_d_param | Output | 2 | Response parameter |
| tl_d_size | Output | 3 | Response size |
| tl_d_source | Output | 4 | Source ID echo |
| tl_d_sink | Output | 2 | Sink ID |
| tl_d_data | Output | 128 | Read data |
| tl_d_corrupt | Output | 1 | Data corrupt flag |
| tl_d_denied | Output | 1 | Access denied flag |

#### 2.1.2 AXI4 Master Interface (M3, M4)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| axi_awid | Input | 4 | Write address ID |
| axi_awaddr | Input | 32 | Write address |
| axi_awlen | Input | 8 | Burst length |
| axi_awsize | Input | 3 | Burst size |
| axi_awburst | Input | 2 | Burst type |
| axi_awvalid | Input | 1 | Write address valid |
| axi_awready | Output | 1 | Write address ready |
| axi_wdata | Input | 128 | Write data |
| axi_wstrb | Input | 16 | Write strobe |
| axi_wlast | Input | 1 | Last write beat |
| axi_wvalid | Input | 1 | Write valid |
| axi_wready | Output | 1 | Write ready |
| axi_bid | Output | 4 | Write response ID |
| axi_bresp | Output | 2 | Write response |
| axi_bvalid | Output | 1 | Write response valid |
| axi_bready | Input | 1 | Write response ready |
| axi_arid | Input | 4 | Read address ID |
| axi_araddr | Input | 32 | Read address |
| axi_arlen | Input | 8 | Burst length |
| axi_arsize | Input | 3 | Burst size |
| axi_arburst | Input | 2 | Burst type |
| axi_arvalid | Input | 1 | Read address valid |
| axi_arready | Output | 1 | Read address ready |
| axi_rid | Output | 4 | Read data ID |
| axi_rdata | Output | 128 | Read data |
| axi_rresp | Output | 2 | Read response |
| axi_rlast | Output | 1 | Last read beat |
| axi_rvalid | Output | 1 | Read valid |
| axi_rready | Input | 1 | Read ready |

### 2.2 Slave Ports (Target Resources)

M04 路由请求至以下 Slave 模块：

| Port ID | Slave Module | Base Address | Size | Access | Clock Domain |
|---------|--------------|--------------|------|--------|--------------|
| S0 | M03 DRAM Controller | 0x0000_0000 | 2 GB | RW | CLK_SYS |
| S1 | M02 SRAM Scratchpad | 0x8000_0000 | 512 KB | RW | CLK_SYS |
| S2 | M04 Bus Registers | 0x8008_0000 | 4 KB | RW | CLK_SYS |
| S3 | M13 ISA Decoder Regs | 0x8009_0000 | 4 KB | RW | CLK_SYS |
| S4 | M14 Secure Boot Regs | 0x800A_0000 | 4 KB | RW | CLK_SYS |
| S5 | M02/M03 ECC Status | 0x800B_0000 | 4 KB | RW | CLK_SYS |
| S6 | M05 Power Manager Regs | 0x800C_0000 | 4 KB | RW | CLK_AON |

#### 2.2.1 TileLink-UH Slave Interface (S0, S1)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tl_s_a_valid | Output | 1 | TileLink Channel A valid to Slave |
| tl_s_a_ready | Input | 1 | TileLink Channel A ready from Slave |
| tl_s_a_opcode | Output | 3 | Operation code |
| tl_s_a_param | Output | 3 | Parameter |
| tl_s_a_size | Output | 3 | Transaction size |
| tl_s_a_source | Output | 4 | Source ID |
| tl_s_a_address | Output | 32 | Target address (masked to Slave range) |
| tl_s_a_mask | Output | 16 | Byte mask |
| tl_s_a_data | Output | 128 | Write data |
| tl_s_a_corrupt | Output | 1 | Corrupt flag |
| tl_s_d_valid | Input | 1 | TileLink Channel D valid from Slave |
| tl_s_d_ready | Output | 1 | TileLink Channel D ready to Slave |
| tl_s_d_opcode | Input | 3 | Response opcode |
| tl_s_d_param | Input | 2 | Response parameter |
| tl_s_d_size | Input | 3 | Response size |
| tl_s_d_source | Input | 4 | Source ID echo |
| tl_s_d_sink | Input | 2 | Sink ID |
| tl_s_d_data | Input | 128 | Read data |
| tl_s_d_corrupt | Input | 1 | Corrupt flag |
| tl_s_d_denied | Input | 1 | Denied flag |

#### 2.2.2 Register Slave Interface (S2-S6)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| reg_req_valid | Output | 1 | Register request valid |
| reg_req_ready | Input | 1 | Register request ready |
| reg_req_addr | Output | 16 | Register address (offset within range) |
| reg_req_rw | Output | 1 | Read/Write flag |
| reg_req_data | Output | 32 | Write data |
| reg_rsp_valid | Input | 1 | Register response valid |
| reg_rsp_data | Input | 32 | Read data |
| reg_rsp_error | Input | 1 | Error flag |

### 2.3 Clock & Reset

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk_sys | Input | 1 | System clock (250-500 MHz) |
| clk_io | Input | 1 | IO clock (50 MHz) |
| clk_aon | Input | 1 | Always-On clock (1 MHz) |
| rst_sys_n | Input | 1 | System reset, async active low |
| rst_por_n | Input | 1 | Power-On Reset, async active low |

### 2.4 CDC Interface (for M15, M05)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| cdc_io_req_valid | Input | 1 | IO domain request valid (from CDC bridge) |
| cdc_io_req_ready | Output | 1 | IO domain request ready (to CDC bridge) |
| cdc_io_rsp_valid | Output | 1 | IO domain response valid (to CDC bridge) |
| cdc_io_rsp_ready | Input | 1 | IO domain response ready (from CDC bridge) |
| cdc_aon_req_valid | Input | 1 | AON domain request valid (from CDC bridge) |
| cdc_aon_req_ready | Output | 1 | AON domain request ready (to CDC bridge) |
| cdc_aon_rsp_valid | Output | 1 | AON domain response valid (to CDC bridge) |
| cdc_aon_rsp_ready | Input | 1 | AON domain response ready (from CDC bridge) |

### 2.5 Control & Status

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| bus_enable | Input | 1 | Bus enable (from M05 Power Manager) |
| bus_busy | Output | 1 | Bus busy flag |
| bus_error | Output | 1 | Bus error flag |
| arb_winner | Output | 4 | Current arbitration winner ID |
| route_target | Output | 3 | Current routing target Slave ID |

### 2.6 Register Map (S2: M04 Registers)

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | BUS_CTRL | RW | 32 | Bus control register |
| 0x0004 | BUS_STATUS | R | 32 | Bus status register |
| 0x0008 | BUS_ARB_CFG | RW | 32 | Arbitration configuration |
| 0x000C | BUS_ROUTE_CFG | RW | 32 | Routing configuration |
| 0x0010 | BUS_TIMEOUT | RW | 32 | Transaction timeout (cycles) |
| 0x0014 | BUS_ERROR_ADDR | R | 32 | Error address |
| 0x0018 | BUS_ERROR_TYPE | R | 32 | Error type |
| 0x001C | BUS_IRQ_EN | RW | 32 | Interrupt enable |
| 0x0020 | BUS_IRQ_STATUS | R | 32 | Interrupt status |
| 0x0024 | BUS_IRQ_CLEAR | RW | 32 | Interrupt clear |
| 0x0028 | BUS_PERF_COUNTER | R | 32 | Performance counter (transactions) |
| 0x002C | BUS_LATENCY_AVG | R | 32 | Average latency (cycles) |

#### 2.6.1 Register Bit Definitions

**BUS_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enable | Bus enable |
| [1] | arb_fixed | Fixed arbitration mode |
| [2] | timeout_en | Timeout enable |
| [3] | error_irq_en | Error interrupt enable |
| [4:7] | arb_mode | Arbitration mode (0=Priority, 1=RoundRobin, 2=Weighted) |
| [8:31] | reserved | Reserved |

**BUS_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | Bus ready |
| [1] | busy | Transaction in progress |
| [2] | error | Error detected |
| [3] | timeout | Timeout occurred |
| [4:7] | active_master | Current active master ID |
| [8:10] | active_slave | Current active slave ID |
| [11] | pending_m0 | Master 0 pending |
| [12] | pending_m1 | Master 1 pending |
| [13] | pending_m2 | Master 2 pending |
| [14] | pending_m3 | Master 3 pending |
| [15] | pending_m4 | Master 4 pending |
| [16:31] | reserved | Reserved |

**BUS_ARB_CFG (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:3] | prio_m0 | Master 0 priority (0=lowest) |
| [4:7] | prio_m1 | Master 1 priority |
| [8:11] | prio_m2 | Master 2 priority |
| [12:15] | prio_m3 | Master 3 priority |
| [16:19] | prio_m4 | Master 4 priority |
| [20:23] | weight_m0 | Weighted round-robin weight for M0 |
| [24:27] | weight_m1 | Weighted round-robin weight for M1 |
| [28:31] | reserved | Reserved |

## 3. Functional Description

### 3.1 Arbitration

Arbiter 管理 5 个 Master 端口的请求仲裁，支持三种仲裁模式。

#### 3.1.1 Arbitration Modes

| Mode | Code | Description | Use Case |
|------|------|-------------|----------|
| Priority | 0 | 固定优先级，高优先级 Master 优先响应 | 高性能计算场景 |
| Round-Robin | 1 | 循环轮询，公平分配带宽 | 多任务均衡场景 |
| Weighted RR | 2 | 加权循环，按权重分配带宽比例 | 定制带宽分配 |

#### 3.1.2 Default Priority Assignment

| Master | Priority | Weight | Description |
|--------|----------|--------|-------------|
| M0 (Systolic Array) | 0 (Highest) | 8 | Compute data access, highest throughput |
| M3 (ISA Decoder) | 1 | 4 | Instruction fetch, critical for execution |
| M1 (SRAM DMA) | 2 | 2 | Scratchpad DMA |
| M2 (DRAM DMA) | 2 | 2 | DRAM DMA |
| M4 (JTAG) | 3 (Lowest) | 1 | Debug access, non-critical |

#### 3.1.3 Arbitration FSM

```
    +-------+
    | IDLE  |
    +---+---+
        |
        | (any tl_a_valid or axi_awvalid or axi_arvalid)
        v
    +-------+
    | ARB   | (Select winner based on mode)
    +---+---+
        |
        | (arb_winner determined)
        v
    +-------+
    | ROUTE | (Decode address, select Slave)
    +---+---+
        |
        | (route_target determined)
        v
    +-------+
    | XFER  | (Transfer to Slave, wait for response)
    +---+---+
        |
        | (response received or timeout)
        v
    +-------+
    | RESP  | (Return response to Master)
    +---+---+
        |
        | (tl_d_valid or axi_bvalid/axi_rvalid sent)
        v
    +-------+
    | IDLE  |
    +-------+
```

#### 3.1.4 Arbitration Timing

| Scenario | Latency | Description |
|----------|---------|-------------|
| Single request | 1 cycle | No arbitration needed |
| Two requests | 2 cycles | Arbitration + routing |
| Multiple pending | 2-4 cycles | Priority comparison + winner selection |
| Response return | 1 cycle | Response path latency |

### 3.2 Address Routing

Address Decoder 根据请求地址路由至对应 Slave。

#### 3.2.1 Address Map

| Address Range | Slave | Description |
|---------------|-------|-------------|
| 0x0000_0000 - 0x7FFF_FFFF | S0 (DRAM) | 2 GB DRAM space |
| 0x8000_0000 - 0x8007_FFFF | S1 (SRAM) | 512 KB SRAM space |
| 0x8008_0000 - 0x8008_FFFF | S2 (Bus Regs) | 4 KB Bus registers |
| 0x8009_0000 - 0x8009_FFFF | S3 (ISA Regs) | 4 KB ISA Decoder registers |
| 0x800A_0000 - 0x800A_FFFF | S4 (Secure Regs) | 4 KB Secure Boot registers |
| 0x800B_0000 - 0x800B_FFFF | S5 (ECC Regs) | 4 KB ECC status registers |
| 0x800C_0000 - 0x800C_FFFF | S6 (Power Regs) | 4 KB Power Manager registers (via CDC) |

#### 3.2.2 Routing Logic

```
Address Decode:
  addr[31:29] == 0b00 --> S0 (DRAM)
  addr[31:29] == 0b10 --> Register space
    addr[28:16] == 0x000 --> S1 (SRAM) [addr[15:0] within 512KB]
    addr[28:16] == 0x008 --> S2 (Bus Regs)
    addr[28:16] == 0x009 --> S3 (ISA Regs)
    addr[28:16] == 0x00A --> S4 (Secure Regs)
    addr[28:16] == 0x00B --> S5 (ECC Regs)
    addr[28:16] == 0x00C --> S6 (Power Regs)
  else --> Error (invalid address)
```

#### 3.2.3 Error Handling

| Condition | Error Code | Response |
|-----------|------------|----------|
| Invalid address | 0x01 | AccessAck with denied=1, error_irq |
| Timeout | 0x02 | AccessAck with corrupt=1, timeout_irq |
| Slave error | 0x03 | Pass-through Slave error response |

### 3.3 Protocol Conversion

Protocol Converter 实现 TileLink-UH 和 AXI4 之间的转换。

#### 3.3.1 TileLink to AXI Conversion

| TileLink Op | AXI Op | Mapping |
|-------------|--------|---------|
| PutFullData (opcode=0) | AW channel write | Single beat write |
| PutPartialData (opcode=1) | AW channel write | Partial write with mask |
| Get (opcode=4) | AR channel read | Single beat read |
| LogicData (opcode=2) | Unsupported | Error response |
| Intent (opcode=5) | Unsupported | Error response |

#### 3.3.2 AXI to TileLink Conversion

| AXI Op | TileLink Op | Mapping |
|--------|-------------|---------|
| AW channel write | PutFullData/PutPartialData | Based on wstrb mask |
| AR channel read | Get | Single beat read |

#### 3.3.3 Burst Handling

| Protocol | Burst Support | Handling |
|----------|---------------|----------|
| TileLink-UH | Burst via param | Converted to AXI burst |
| AXI4 | INCR burst (awburst=1) | Converted to multiple TileLink beats |
| AXI4 | FIXED burst (awburst=0) | Single beat TileLink |
| AXI4 | WRAP burst (awburst=2) | Unsupported, error response |

### 3.4 CDC Synchronization

CDC Bridge 处理跨时钟域请求（CLK_SYS <-> CLK_IO/CLK_AON）。

#### 3.4.1 CDC Bridge Architecture

```
CLK_SYS Domain         CDC Bridge           CLK_IO/CLK_AON Domain
    |                      |                      |
    +-- Request FIFO --+   |   +-- Request FIFO --+
    |  (async)         |   |   |  (async)         |
    +-- Response FIFO -+   |   +-- Response FIFO -+
    |  (async)         |   |   |  (async)         |
```

#### 3.4.2 CDC Methods

| Crossing | From -> To | Method | Depth |
|----------|------------|--------|-------|
| JTAG -> Bus | CLK_IO -> CLK_SYS | 2-stage handshake | 4 entries |
| Bus -> Power | CLK_SYS -> CLK_AON | Pulse synchronizer | 2 entries |
| Power -> Bus | CLK_AON -> CLK_SYS | Handshake synchronizer | 4 entries |

#### 3.4.3 CDC Latency

| Crossing | Sync Latency | Description |
|----------|--------------|-------------|
| CLK_IO -> CLK_SYS | 2-3 cycles | Request sync |
| CLK_SYS -> CLK_IO | 2-3 cycles | Response sync |
| CLK_SYS -> CLK_AON | 4-6 cycles | Slow clock domain |
| CLK_AON -> CLK_SYS | 2-3 cycles | Fast clock domain |

### 3.5 Timeout Mechanism

Timeout Counter 监控长时间未响应的请求。

#### 3.5.1 Timeout Configuration

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| BUS_TIMEOUT | 1000 cycles | 64-65535 | Maximum wait time for response |
| Timeout Enable | Enabled | - | BUS_CTRL[2] controls |

#### 3.5.2 Timeout Handling

```
Transaction Start:
  - Start timeout counter
  - Wait for Slave response

Timeout Trigger (counter == BUS_TIMEOUT):
  - Cancel transaction
  - Set BUS_STATUS[timeout]=1
  - Generate error response (corrupt=1)
  - Set BUS_ERROR_ADDR, BUS_ERROR_TYPE=0x02
  - Generate IRQ (if enabled)
```

### 3.6 Performance Monitoring

Performance Monitor 提供总线利用率统计。

#### 3.6.1 Counters

| Counter | Description |
|---------|-------------|
| BUS_PERF_COUNTER | Total transactions completed |
| BUS_LATENCY_AVG | Average latency (cycles) |
| Per-Master pending | BUS_STATUS[11:15] |
| Per-Slave activity | Internal tracking |

#### 3.6.2 Bandwidth Calculation

```
Effective Bandwidth = (Total Bytes Transferred) / (Time Window)

DRAM BW Target: >= 10 GB/s
SRAM BW Target: >= 8 GB/s
```

## 4. Timing

### 4.1 Arbitration Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_arb_decision | 1-2 cycles | Arbitration decision time |
| t_route_decode | 1 cycle | Address decode time |
| t_master_accept | 1 cycle | Master request acceptance |
| t_slave_accept | 1 cycle | Slave request acceptance |

### 4.2 Transfer Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_bus_latency | 2-4 cycles | Bus internal latency (no Slave delay) |
| t_dram_access | 50-100 ns | DRAM access latency (via M03) |
| t_sram_access | 1-2 cycles | SRAM access latency (via M02) |
| t_reg_access | 1-2 cycles | Register access latency |

### 4.3 CDC Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_cdc_io_sync | 2-3 cycles | IO domain synchronization |
| t_cdc_aon_sync | 4-6 cycles | AON domain synchronization |
| t_cdc_total | t_cdc_sync + t_bus_latency | Total CDC path latency |

### 4.4 Timeout Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_timeout_min | 64 cycles | Minimum timeout value |
| t_timeout_default | 1000 cycles | Default timeout value |
| t_timeout_max | 65535 cycles | Maximum timeout value |

### 4.5 Throughput

| Metric | Target | Condition |
|--------|--------|-----------|
| DRAM Bandwidth | >= 10 GB/s | Burst mode, 128-bit bus |
| SRAM Bandwidth | >= 8 GB/s | Burst mode, 128-bit bus |
| Register BW | <= 1 GB/s | Single-beat transactions |
| Arbitration Rate | >= 250 M req/s | @ 500 MHz |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **Bus Width**: 128-bit data path，满足 DRAM/SRAM bandwidth 需求，支持 TileLink/AXI 双协议。

2. **Arbitration Safety**: Arbitration 必须保证：
   - 无饥饿：Round-Robin 模式下所有 Master 最终获得服务
   - 无死锁：Priority 模式下低优先级请求可超时取消
   - 响应返回：正确路由响应至请求 Master

3. **CDC Reliability**: CDC Bridge 使用 Gray-coded FIFO 和两级同步器，确保无 metastability。

4. **Error Recovery**: 错误响应立即返回，不阻塞后续请求。

5. **Protocol Compliance**: TileLink 和 AXI 协议完全兼容，支持标准工具链。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol | Notes |
|-----------|---------------|----------|-------|
| Master M0 | M00 Systolic Array | TileLink-UH | Compute data |
| Master M1 | M02 SRAM Scratchpad | TileLink-UH | DMA control |
| Master M2 | M03 DRAM Controller | TileLink-UH | DMA control |
| Master M3 | M13 ISA Decoder | AXI4 | Instruction fetch |
| Master M4 | M15 JTAG Interface | AXI4 | Debug (via CDC) |
| Slave S0 | M03 DRAM Controller | TileLink-UH | Memory target |
| Slave S1 | M02 SRAM Scratchpad | TileLink-UH | Memory target |
| Slave S3 | M13 ISA Decoder | Register | Control registers |
| Slave S4 | M14 Secure Boot | Register | Security registers |
| Slave S6 | M05 Power Manager | Register | Power regs (via CDC) |

### 5.3 Verification Requirements

| Test Category | Description |
|---------------|-------------|
| Arbitration | 验证 Priority/Round-Robin/Weighted 模式 |
| Routing | 验证所有地址空间路由正确 |
| Protocol | 验证 TileLink/AXI 转换和 burst 处理 |
| CDC | 验证跨时钟域传输可靠性 |
| Timeout | 验证超时触发和恢复 |
| Error | 铺证错误响应和中断 |
| Performance | 验证 bandwidth 和 latency |

### 5.4 Power Budget Allocation

| Domain | Budget | Allocation |
|--------|--------|------------|
| Arbiter Logic | 15 mW | Priority/RR logic + FSM |
| Routing Logic | 10 mW | Address decode + route mux |
| Protocol Conv | 10 mW | TileLink/AXI conversion |
| CDC Bridges | 10 mW | Async FIFO + synchronizers |
| Register Slave | 5 mW | Register interface |
| **Total** | **50 mW** | @ OP0, 500 MHz |

### 5.5 Clock Domain Crossing

| Crossing | From | To | Method | Target Module |
|----------|------|----|--------|---------------|
| Debug Request | CLK_IO (50 MHz) | CLK_SYS (500 MHz) | Handshake FIFO | M15 JTAG |
| Power Request | CLK_SYS (500 MHz) | CLK_AON (1 MHz) | Pulse sync | M05 Power |
| Power Response | CLK_AON (1 MHz) | CLK_SYS (500 MHz) | Handshake | M05 Power |

### 5.6 Reset Strategy

| Reset | Source | Effect |
|-------|--------|--------|
| rst_por_n | Power-On | 全部寄存器复位，FSM 进入 IDLE |
| rst_sys_n | External | 仅状态寄存器复位，配置保留 |
| Soft Reset | BUS_CTRL[0]=0 | 禁用总线，保持配置 |