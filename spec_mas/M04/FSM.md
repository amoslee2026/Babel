---
module: M04
type: FSM
status: complete
parent: M04
fsm_type: Bus Arbitration FSM
generated: "2026-05-17T16:00:00+08:00"
---

# M04: Bus Arbitration FSM

## 1. Overview

M04 Bus Arbitration FSM 是 System Bus 模块的核心控制状态机，负责管理多 Master 请求仲裁、地址路由、数据传输和响应返回。该 FSM 实现 TileLink-UH 和 AXI4 双协议支持，确保各 Master 请求按配置的仲裁策略公平、高效地获得服务。

### 1.1 FSM Architecture

```
                    +-------+
                    | IDLE  |<-------------------------------------+
                    +---+---+                                      |
                        |                                          |
                        | req_pending (any tl_a_valid/axi_valid)   |
                        v                                          |
                    +-------+                                      |
                    | ARB   |                                      |
                    +---+---+                                      |
                        |                                          |
                        | arb_winner_valid                         |
                        v                                          |
                    +-------+                                      |
                    | ROUTE |                                      |
                    +---+---+                                      |
                        |                                          |
                        | route_target_valid                       |
                        v                                          |
                    +-------+                                      |
                    | XFER  |                                      |
                    +---+---+                                      |
                        |                                          |
                        | (slave_rsp_valid OR timeout)             |
                        v                                          |
                    +-------+                                      |
                    | RESP  |                                      |
                    +---+---+                                      |
                        |                                          |
                        | rsp_sent (tl_d_valid/axi_rsp_valid)      |
                        +------------------------------------------+
```

### 1.2 Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Number of Masters | 5 | M0-M4 request sources |
| Number of Slaves | 7 | S0-S6 target resources |
| Data Width | 128 bits | Bus data path width |
| Max Pending Requests | 1 | Single transaction at a time (non-burst) |
| Default Timeout | 1000 cycles | Transaction timeout threshold |

## 2. State Definitions

### 2.1 State Encoding

| State | Encoding | Description |
|-------|----------|-------------|
| IDLE | 3'b000 | No active transaction, monitoring request inputs |
| ARB | 3'b001 | Arbitrating among pending Master requests |
| ROUTE | 3'b010 | Decoding address, selecting target Slave |
| XFER | 3'b011 | Transferring request to Slave, waiting for response |
| RESP | 3'b100 | Returning response to requesting Master |

### 2.2 State Descriptions

#### IDLE (3'b000)

**Purpose**: 等待 Master 请求，监控所有输入端口。

**Entry Conditions**:
- Reset (rst_por_n or rst_sys_n)
- Completion of previous transaction (rsp_sent)

**Exit Conditions**:
- Any Master request pending (req_pending)

**Actions**:
- Clear all internal registers
- Monitor tl_a_valid (M0, M1, M2) and axi_awvalid/axi_arvalid (M3, M4)
- Update pending_status register

**State Outputs**:
- `bus_busy = 0`
- `arb_winner = 0`
- `route_target = 0`
- All slave interfaces: valid signals = 0

---

#### ARB (3'b001)

**Purpose**: 根据 BUS_ARB_CFG 配置的仲裁模式选择获胜 Master。

**Entry Conditions**:
- IDLE state with req_pending = 1

**Exit Conditions**:
- arb_winner determined (arb_winner_valid = 1)

**Actions**:
- Read pending requests from all Master ports
- Apply arbitration policy (Priority/Round-Robin/Weighted)
- Select arb_winner (4-bit Master ID)
- Capture request details (opcode, address, data, mask)
- Update BUS_STATUS[active_master]

**Arbitration Logic**:

| Arb Mode | Logic | Winner Selection |
|----------|-------|------------------|
| Priority (0) | Compare priorities, highest wins | prio[M0] > prio[M1] > ... > prio[M4] |
| Round-Robin (1) | Circular scan from last winner | last_winner+1 -> ... -> 4 -> 0 -> ... |
| Weighted RR (2) | Weight-based token allocation | weight[M0], weight[M1], ..., weight[M4] |

**State Outputs**:
- `bus_busy = 1`
- `arb_winner = selected_master_id`
- All Master ready signals = 0 (block new requests during arbitration)

---

#### ROUTE (3'b010)

**Purpose**: 解析请求地址，选择目标 Slave 端口。

**Entry Conditions**:
- ARB state with arb_winner_valid = 1

**Exit Conditions**:
- route_target determined (route_target_valid = 1)

**Address Decode Logic**:

```
addr[31:29] == 0b00    --> S0 (DRAM)
addr[31:29] == 0b10    --> Register space
  addr[28:16] == 0x000 --> S1 (SRAM)
  addr[28:16] == 0x008 --> S2 (Bus Regs)
  addr[28:16] == 0x009 --> S3 (ISA Regs)
  addr[28:16] == 0x00A --> S4 (Secure Regs)
  addr[28:16] == 0x00B --> S5 (ECC Regs)
  addr[28:16] == 0x00C --> S6 (Power Regs)
else                    --> ERROR (invalid address)
```

**Actions**:
- Decode request address
- Determine route_target (3-bit Slave ID)
- Check address validity
- Handle CDC crossing for S6 (CLK_AON domain)
- Update BUS_STATUS[active_slave]
- Start timeout counter

**State Outputs**:
- `route_target = selected_slave_id`
- If invalid address: route_target = ERROR, skip XFER

---

#### XFER (3'b011)

**Purpose**: 向选定的 Slave 发送请求，等待响应。

**Entry Conditions**:
- ROUTE state with route_target_valid = 1

**Exit Conditions**:
- Slave response received (slave_rsp_valid = 1)
- Timeout triggered (timeout_event = 1)

**Slave Interface Driving**:

| Target | Protocol | Signals Driven |
|--------|----------|----------------|
| S0, S1 | TileLink-UH | tl_s_a_valid, tl_s_a_opcode, tl_s_a_address, tl_s_a_data, ... |
| S2-S6 | Register | reg_req_valid, reg_req_addr, reg_req_rw, reg_req_data |

**Actions**:
- Drive Slave interface with captured request
- Monitor Slave ready signal
- Wait for Slave response (tl_s_d_valid or reg_rsp_valid)
- Track timeout counter
- Handle Slave error response

**Timeout Handling**:
- If counter reaches BUS_TIMEOUT:
  - Set BUS_STATUS[timeout] = 1
  - Generate error response (corrupt/denied = 1)
  - Set BUS_ERROR_ADDR, BUS_ERROR_TYPE = 0x02
  - Transition to RESP state

**State Outputs**:
- Slave valid signals driven per protocol
- `bus_busy = 1`

---

#### RESP (3'b100)

**Purpose**: 将 Slave 响应返回给请求 Master。

**Entry Conditions**:
- XFER state with slave_rsp_valid = 1 or timeout_event = 1

**Exit Conditions**:
- Response sent (rsp_sent = 1)

**Response Routing**:

| Original Master | Protocol | Response Signals |
|------------------|----------|------------------|
| M0, M1, M2 | TileLink-UH | tl_d_valid, tl_d_opcode, tl_d_data, tl_d_denied, tl_d_corrupt |
| M3, M4 | AXI4 | axi_bvalid/axi_rvalid, axi_bresp/axi_rresp, axi_rdata |

**Actions**:
- Drive Master response interface
- Update performance counters (BUS_PERF_COUNTER, BUS_LATENCY_AVG)
- Clear pending_status for this Master
- Handle error interrupt (if BUS_IRQ_EN enabled)

**State Outputs**:
- Master response valid signals driven per protocol
- `arb_winner = 0` (cleared after response)

## 3. State Transition Table

### 3.1 Transition Conditions

| Current | Next | Condition | Description |
|---------|------|-----------|-------------|
| IDLE | ARB | req_pending | Any Master request valid |
| ARB | ROUTE | arb_winner_valid | Arbitration complete |
| ROUTE | XFER | route_target_valid AND valid_addr | Valid address, route to Slave |
| ROUTE | RESP | route_target_valid AND invalid_addr | Invalid address, error response |
| XFER | RESP | slave_rsp_valid OR timeout_event | Response received or timeout |
| RESP | IDLE | rsp_sent | Response sent to Master |

### 3.2 Transition Timing

| Transition | Cycles | Description |
|------------|--------|-------------|
| IDLE -> ARB | 1 cycle | Request detection to arbitration start |
| ARB -> ROUTE | 1-2 cycles | Arbitration decision latency |
| ROUTE -> XFER | 1 cycle | Address decode latency |
| ROUTE -> RESP (error) | 1 cycle | Error response path |
| XFER -> RESP | Variable | Slave response latency (see below) |
| RESP -> IDLE | 1 cycle | Response send latency |

**Slave Response Latency (XFER -> RESP)**:

| Slave | Typical Latency | Max Latency |
|-------|-----------------|-------------|
| S0 (DRAM) | 50-100 ns | 200 ns (via M03) |
| S1 (SRAM) | 1-2 cycles | 4 cycles |
| S2-S5 (Regs) | 1-2 cycles | 4 cycles |
| S6 (Power, CDC) | 4-6 cycles | 10 cycles |

## 4. Input Signals

### 4.1 Master Request Inputs

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| tl_a_valid[0:2] | 3 | M0, M1, M2 | TileLink Channel A valid |
| tl_a_opcode[0:2] | 9 | M0, M1, M2 | TileLink opcode (3 bits each) |
| tl_a_address[0:2] | 96 | M0, M1, M2 | TileLink address (32 bits each) |
| tl_a_data[0:2] | 384 | M0, M1, M2 | TileLink write data (128 bits each) |
| tl_a_mask[0:2] | 48 | M0, M1, M2 | TileLink byte mask (16 bits each) |
| tl_a_source[0:2] | 12 | M0, M1, M2 | TileLink source ID (4 bits each) |
| axi_awvalid[3:4] | 2 | M3, M4 | AXI write address valid |
| axi_awaddr[3:4] | 64 | M3, M4 | AXI write address (32 bits each) |
| axi_arvalid[3:4] | 2 | M3, M4 | AXI read address valid |
| axi_araddr[3:4] | 64 | M3, M4 | AXI read address (32 bits each) |
| axi_wdata[3:4] | 256 | M3, M4 | AXI write data (128 bits each) |
| axi_wstrb[3:4] | 32 | M3, M4 | AXI write strobe (16 bits each) |

### 4.2 Slave Response Inputs

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| tl_s_d_valid[0:1] | 2 | S0, S1 | TileLink Channel D valid from Slave |
| tl_s_d_opcode[0:1] | 6 | S0, S1 | TileLink response opcode (3 bits each) |
| tl_s_d_data[0:1] | 256 | S0, S1 | TileLink read data (128 bits each) |
| tl_s_d_denied[0:1] | 2 | S0, S1 | TileLink denied flag |
| tl_s_d_corrupt[0:1] | 2 | S0, S1 | TileLink corrupt flag |
| reg_rsp_valid[2:6] | 5 | S2-S6 | Register response valid |
| reg_rsp_data[2:6] | 160 | S2-S6 | Register read data (32 bits each) |
| reg_rsp_error[2:6] | 5 | S2-S6 | Register error flag |

### 4.3 Control Inputs

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| bus_enable | 1 | M05 | Bus enable control |
| arb_mode | 4 | BUS_ARB_CFG | Arbitration mode (Priority/RR/Weighted) |
| prio_m[0:4] | 20 | BUS_ARB_CFG | Master priorities (4 bits each) |
| weight_m[0:4] | 20 | BUS_ARB_CFG | Master weights (4 bits each) |
| timeout_threshold | 16 | BUS_TIMEOUT | Timeout threshold in cycles |
| timeout_en | 1 | BUS_CTRL | Timeout enable flag |

### 4.4 Clock & Reset Inputs

| Signal | Width | Description |
|--------|-------|-------------|
| clk_sys | 1 | System clock (250-500 MHz) |
| rst_por_n | 1 | Power-On Reset, async active low |
| rst_sys_n | 1 | System reset, async active low |

## 5. Output Signals

### 5.1 Master Response Outputs

| Signal | Width | Destination | Description |
|--------|-------|--------------|-------------|
| tl_d_valid[0:2] | 3 | M0, M1, M2 | TileLink Channel D valid |
| tl_d_ready[0:2] | 3 | M0, M1, M2 | TileLink Channel D ready |
| tl_d_opcode[0:2] | 9 | M0, M1, M2 | TileLink response opcode |
| tl_d_data[0:2] | 384 | M0, M1, M2 | TileLink read data (128 bits each) |
| tl_d_denied[0:2] | 3 | M0, M1, M2 | TileLink denied flag |
| tl_d_corrupt[0:2] | 3 | M0, M1, M2 | TileLink corrupt flag |
| tl_d_source[0:2] | 12 | M0, M1, M2 | TileLink source ID echo |
| axi_bvalid[3:4] | 2 | M3, M4 | AXI write response valid |
| axi_bresp[3:4] | 4 | M3, M4 | AXI write response |
| axi_rvalid[3:4] | 2 | M3, M4 | AXI read response valid |
| axi_rresp[3:4] | 4 | M3, M4 | AXI read response |
| axi_rdata[3:4] | 256 | M3, M4 | AXI read data (128 bits each) |

### 5.2 Slave Request Outputs

| Signal | Width | Destination | Description |
|--------|-------|--------------|-------------|
| tl_s_a_valid[0:1] | 2 | S0, S1 | TileLink Channel A valid to Slave |
| tl_s_a_ready[0:1] | 2 | S0, S1 | TileLink Channel A ready from Slave |
| tl_s_a_opcode[0:1] | 6 | S0, S1 | TileLink opcode to Slave |
| tl_s_a_address[0:1] | 64 | S0, S1 | TileLink address to Slave |
| tl_s_a_data[0:1] | 256 | S0, S1 | TileLink write data to Slave |
| tl_s_a_mask[0:1] | 32 | S0, S1 | TileLink byte mask to Slave |
| tl_s_a_source[0:1] | 8 | S0, S1 | TileLink source ID to Slave |
| reg_req_valid[2:6] | 5 | S2-S6 | Register request valid |
| reg_req_addr[2:6] | 80 | S2-S6 | Register address (16 bits each) |
| reg_req_rw[2:6] | 5 | S2-S6 | Register read/write flag |
| reg_req_data[2:6] | 160 | S2-S6 | Register write data (32 bits each) |

### 5.3 Status Outputs

| Signal | Width | Destination | Description |
|--------|-------|--------------|-------------|
| bus_busy | 1 | M05, BUS_STATUS | Bus busy flag |
| bus_error | 1 | M05, BUS_STATUS | Bus error flag |
| arb_winner | 4 | BUS_STATUS | Current arbitration winner ID |
| route_target | 3 | BUS_STATUS | Current routing target Slave ID |
| pending_status | 5 | BUS_STATUS | Pending request status per Master |
| timeout_irq | 1 | M05 | Timeout interrupt |
| error_irq | 1 | M05 | Error interrupt |

### 5.4 Performance Outputs

| Signal | Width | Destination | Description |
|--------|-------|--------------|-------------|
| perf_counter | 32 | BUS_PERF_COUNTER | Transaction counter |
| latency_acc | 32 | Internal | Latency accumulator (for average) |
| latency_avg | 32 | BUS_LATENCY_AVG | Average latency |

## 6. Internal Registers

### 6.1 State Register

| Register | Width | Reset Value | Description |
|----------|-------|-------------|-------------|
| fsm_state | 3 | IDLE (3'b000) | Current FSM state |
| last_winner | 4 | 0 | Last arbitration winner (for Round-Robin) |
| weight_counter[0:4] | 20 | 0 | Weight counters (for Weighted RR) |

### 6.2 Transaction Registers

| Register | Width | Reset Value | Description |
|----------|-------|-------------|-------------|
| current_master | 4 | 0 | Current requesting Master ID |
| current_slave | 3 | 0 | Current target Slave ID |
| captured_opcode | 3 | 0 | Captured TileLink opcode |
| captured_address | 32 | 0 | Captured request address |
| captured_data | 128 | 0 | Captured write data |
| captured_mask | 16 | 0 | Captured byte mask |
| captured_source | 4 | 0 | Captured TileLink source ID |
| captured_axi_id | 4 | 0 | Captured AXI ID |
| captured_axi_len | 8 | 0 | Captured AXI burst length |
| captured_is_write | 1 | 0 | Write/Read flag |

### 6.3 Status Registers

| Register | Width | Reset Value | Description |
|----------|-------|-------------|-------------|
| pending_status | 5 | 0 | Pending request per Master (bit per Master) |
| timeout_counter | 16 | 0 | Timeout cycle counter |
| error_addr | 32 | 0 | Error address latch |
| error_type | 8 | 0 | Error type code |

### 6.4 Performance Registers

| Register | Width | Reset Value | Description |
|----------|-------|-------------|-------------|
| perf_counter | 32 | 0 | Total transactions completed |
| latency_acc | 32 | 0 | Latency accumulator (cycles) |
| transaction_start_time | 32 | 0 | Transaction start cycle (for latency) |

## 7. Timing Requirements

### 7.1 Critical Path Analysis

| Path | Source -> Dest | Max Delay | Clock Period |
|------|----------------|-----------|--------------|
| Arbitration Logic | req_pending -> arb_winner | 2 cycles | @500 MHz = 4 ns |
| Address Decode | captured_address -> route_target | 1 cycle | @500 MHz = 2 ns |
| Response Routing | slave_rsp -> master_rsp | 1 cycle | @500 MHz = 2 ns |
| Timeout Check | timeout_counter -> timeout_event | 1 cycle | @500 MHz = 2 ns |

### 7.2 Setup/Hold Requirements

| Signal | Setup Time | Hold Time | Description |
|--------|------------|-----------|-------------|
| tl_a_valid | 0.5 ns | 0.1 ns | Master request valid |
| tl_s_d_valid | 0.5 ns | 0.1 ns | Slave response valid |
| axi_awvalid | 0.5 ns | 0.1 ns | AXI write address valid |
| axi_arvalid | 0.5 ns | 0.1 ns | AXI read address valid |

### 7.3 Clock Domain Crossing

| Crossing | From -> To | Latency | Synchronizer |
|----------|------------|---------|--------------|
| JTAG Request | CLK_IO -> CLK_SYS | 2-3 cycles | 2-stage handshake |
| Power Request | CLK_SYS -> CLK_AON | 4-6 cycles | Pulse synchronizer |
| Power Response | CLK_AON -> CLK_SYS | 2-3 cycles | Handshake FIFO |

## 8. Error Handling

### 8.1 Error Types

| Code | Name | Condition | Response |
|------|------|-----------|----------|
| 0x01 | ADDR_INVALID | Invalid address decode | AccessAck with denied=1 |
| 0x02 | TIMEOUT | Response timeout | AccessAck with corrupt=1 |
| 0x03 | SLAVE_ERROR | Slave returned error | Pass-through error |
| 0x04 | CDC_ERROR | CDC synchronization failure | Error response |

### 8.2 Error Recovery

**Invalid Address (0x01)**:
- FSM transitions: ROUTE -> RESP (skip XFER)
- Response: AccessAck/AccessAckData with denied=1
- Interrupt: error_irq if BUS_IRQ_EN[0]=1

**Timeout (0x02)**:
- FSM transitions: XFER -> RESP
- Response: AccessAck/AccessAckData with corrupt=1
- Interrupt: timeout_irq if BUS_IRQ_EN[1]=1

**Slave Error (0x03)**:
- FSM transitions: XFER -> RESP
- Response: Pass-through Slave error (denied/corrupt from Slave)
- Interrupt: error_irq if BUS_IRQ_EN[0]=1

## 9. Verification Requirements

### 9.1 FSM Coverage

| Coverage Type | Target | Description |
|---------------|--------|-------------|
| State Coverage | 100% | All states visited |
| Transition Coverage | 100% | All transitions exercised |
| Arc Coverage | 100% | All state-to-state arcs |
| FSM Reset | Verified | Reset to IDLE verified |

### 9.2 Functional Tests

| Test | Description | Expected Behavior |
|------|-------------|-------------------|
| Single Request | One Master request | Complete transaction without arbitration |
| Multiple Requests | Two+ Masters simultaneous | Arbitration, winner selected correctly |
| Priority Arbitration | High priority request pending | High priority wins |
| Round-Robin Arbitration | Multiple requests pending | Fair distribution |
| Weighted RR Arbitration | Weighted requests | Correct weight-based distribution |
| Address Routing | All address ranges | Correct Slave selection |
| Invalid Address | Out-of-range address | Error response |
| Timeout | No Slave response | Timeout triggered, error response |
| Slave Error | Slave returns error | Error passed to Master |
| CDC Crossing | CLK_IO/CLK_AON requests | Correct synchronization |

### 9.3 Timing Tests

| Test | Description | Expected Timing |
|------|-------------|-----------------|
| Arbitration Latency | req_pending -> arb_winner | 1-2 cycles |
| Address Decode Latency | address -> route_target | 1 cycle |
| Response Return Latency | slave_rsp -> master_rsp | 1 cycle |
| Total Transaction | req -> rsp (SRAM) | 4-6 cycles |

## 10. Implementation Notes

### 10.1 Design Guidelines

1. **One-hot State Encoding**: Consider one-hot encoding for better timing if target frequency > 500 MHz.

2. **Arbitration Fairness**: Round-Robin mode must guarantee no starvation. Weighted RR must maintain weight ratios.

3. **Timeout Safety**: Timeout counter must reset after each transaction. Must not overflow.

4. **CDC Safety**: All CDC crossings use Gray-coded counters and proper synchronizers.

5. **Error Isolation**: Error handling must not block subsequent transactions.

### 10.2 RTL Implementation Checklist

- [ ] FSM state register with async reset
- [ ] Arbitration priority comparator
- [ ] Address decoder with error detection
- [ ] Timeout counter with threshold compare
- [ ] Response routing multiplexer
- [ ] Performance counters (transaction, latency)
- [ ] Interrupt generation logic
- [ ] CDC handshake for S6 (CLK_AON)

### 10.3 Synthesis Constraints

```sdc
# Clock definition
create_clock -name clk_sys -period 2 [get_ports clk_sys]

# FSM timing constraints
set_max_delay 2 -from [get_registers req_pending] -to [get_registers arb_winner]
set_max_delay 1 -from [get_registers captured_address] -to [get_registers route_target]

# Timeout counter constraint
set_max_delay 1 -from [get_registers timeout_counter] -to [get_registers timeout_event]

# False paths for CDC
set_false_path -from [get_clocks clk_io] -to [get_clocks clk_sys]
set_false_path -from [get_clocks clk_aon] -to [get_clocks clk_sys]
```

## 11. References

- [M04 MAS.md](./MAS.md) - Module Architecture Specification
- [REQ-MEM-002] - Bandwidth requirements (>= 10 GB/s DRAM, >= 8 GB/s SRAM)
- [REQ-IO-001] - JTAG interface requirements
- [REQ-IO-002] - Clock domain crossing requirements
- TileLink-UH Specification - [TL-Spec]
- AXI4 Specification - [AXI-Spec]