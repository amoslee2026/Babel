---
module: M04
type: DFT
status: complete
parent: M04
module_type: interconnect
generated: "2026-05-17T16:30:00+08:00"
---

# M04: System Bus - DFT Specification

## 1. Overview

M04 System Bus 是核心互联模块，DFT 策略覆盖 Arbiter Logic、Address Routing、Protocol Converter、CDC Bridge 四大测试对象。目标测试覆盖率 >= 95% (REQ-DFT-001)。

| Test Object | Coverage Target | Priority |
|-------------|-----------------|----------|
| Arbiter Logic | 98% | Highest |
| Address Routing | 98% | Highest |
| Protocol Converter | 95% | High |
| CDC Bridge | 100% | Critical |

## 2. Scan Chain Configuration

### 2.1 Scan Chain Architecture

System Bus 采用功能分组 scan chain 架构。

| Chain Group | Chain ID | Elements | Length (FFs) | Description |
|--------------|----------|----------|--------------|-------------|
| Arbiter Logic | SC0 | 1 chain | 1,000 | Priority/RR arbitration FSM |
| Address Router | SC1 | 1 chain | 800 | Address decode + slave select |
| Protocol Converter | SC2 | 1 chain | 600 | TileLink/AXI conversion logic |
| CDC Bridge (IO) | SC3 | 1 chain | 400 | CLK_SYS <-> CLK_IO CDC |
| CDC Bridge (AON) | SC4 | 1 chain | 400 | CLK_SYS <-> CLK_AON CDC |
| Timeout Logic | SC5 | 1 chain | 300 | Timeout counter + error handling |
| Register Slave | SC6 | 1 chain | 400 | Bus register interface |
| Performance Counter | SC7 | 1 chain | 300 | Performance monitor |

**Total Scan Chains**: 8 chains
**Total Scan Elements**: ~4,200 FFs

### 2.2 Scan Chain Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| scan_enable_i | Input | 1 | Global scan enable |
| scan_mode_i | Input | 2 | Scan mode selection |
| scan_in_i | Input | 8 | Scan data input |
| scan_out_o | Output | 8 | Scan data output |
| scan_clk_i | Input | 1 | Scan clock |
| scan_rst_n_i | Input | 1 | Scan reset |

### 2.3 Scan Chain Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Scan Clock Frequency | 10-50 MHz | Test clock |
| Scan Chain Cycle | <= 1 ms | Max chain load/unload |
| Scan Capture Window | >= 10 ns | Setup + Hold margin |

## 3. BIST Design

### 3.1 Interconnect BIST (LBIST)

LBIST 覆盖 Arbitration 和 Routing Logic。

| Parameter | Value | Description |
|-----------|-------|-------------|
| BIST Controller | 1 instance | Centralized LBIST |
| PRPG | LFSR-32 | 32-bit pattern generator |
| MISR | MISR-32 | 32-bit signature compactor |
| Test Patterns | 5,000 | Arbitration + routing coverage |
| Coverage Target | 98% | Logic fault coverage |

**Arbitration FSM Coverage**:

```
Arbiter FSM State Coverage:
  IDLE -> ARB -> ROUTE -> XFER -> RESP -> IDLE
  
  Test Coverage:
    - All arbitration modes (Priority, Round-Robin, Weighted)
    - All master request combinations
    - Response routing correctness
```

### 3.2 CDC Test

CDC Bridge 测试验证跨时钟域可靠性。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| FIFO Depth Test | Async FIFO 深度验证 | No overflow/underflow |
| Handshake Test | 2-stage handshake correctness | All handshake states |
| Metastability Test | CDC path stability | All CDC paths |
| Gray Code Test | FIFO pointer Gray encoding | Pointer transitions |

**CDC Test Architecture**:

```
CDC Test Structure:
  
  CLK_SYS Domain:
    - Test pattern generator
    - Write to async FIFO
    
  CDC Bridge:
    - Gray-coded pointer sync
    - 2-stage synchronizer
    
  CLK_IO/CLK_AON Domain:
    - Read from async FIFO
    - Pattern verification
```

**CDC Test Sequence**:

```
CDC Handshake Test:
  1. Generate test pattern in CLK_SYS
  2. Write to CDC FIFO
  3. Wait for handshake completion
  4. Read pattern in CLK_IO/CLK_AON
  5. Verify pattern match
  
CDC Stress Test:
  6. Continuous pattern generation
  7. Verify FIFO depth management
  8. Measure synchronization latency
```

### 3.3 Protocol Converter Test

TileLink <-> AXI 转换测试。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| TileLink to AXI | PutFullData -> AW channel | All TileLink opcodes |
| AXI to TileLink | AW channel -> PutFullData | All AXI operations |
| Burst Handling | Burst conversion correctness | All burst modes |
| Error Response | Error pass-through | All error codes |

**Protocol Test Sequence**:

```
TileLink to AXI Conversion Test:
  1. Issue TileLink PutFullData (opcode=0)
  2. Verify AXI AW channel write
  3. Verify data transfer
  4. Check AXI BRESP response
  
AXI to TileLink Conversion Test:
  5. Issue AXI write (AW + W channels)
  6. Verify TileLink response
  7. Check AccessAckData response
  
Burst Test:
  8. Issue TileLink burst (param field)
  9. Verify AXI burst conversion
  10. Check all beat handling
```

### 3.4 Address Routing Test

地址解码和 Slave 选择测试。

| Test Type | Description | Coverage |
|-----------|-------------|----------|
| Address Decode | Address[31:29] routing | All address regions |
| Slave Select | Slave S0-S6 selection | All 7 slaves |
| Boundary Test | Address boundary routing | All boundaries |
| Error Address | Invalid address handling | Error response |

**Address Routing Test**:

```
Address Routing Test:
  For each slave S0-S6:
    1. Generate address in slave range
    2. Verify correct slave selection
    3. Verify data path to slave
    
  Invalid Address Test:
    4. Generate address outside valid range
    5. Verify error response
    6. Verify IRQ generation
```

## 4. Test Access Mechanism (TAM)

### 4.1 JTAG TAP Controller

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| tck_i | Input | 1 | JTAG Test Clock |
| tms_i | Input | 1 | JTAG Test Mode Select |
| tdi_i | Input | 1 | JTAG Test Data Input |
| tdo_o | Output | 1 | JTAG Test Data Output |
| trst_n_i | Input | 1 | JTAG Test Reset |

**JTAG Instructions**:

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| EXTEST | 0x00 | External test (boundary scan) |
| SAMPLE | 0x01 | Sample boundary registers |
| INTEST | 0x02 | Internal test (scan chain) |
| IDCODE | 0x04 | Device ID read |
| BYPASS | 0x0F | Bypass mode |
| USER1 | 0x08 | CDC test control |
| USER2 | 0x09 | Protocol converter test |
| USER3 | 0x0A | Interconnect LBIST |

### 4.2 Master/Slave Port Test Access

| Port | Test Method | Description |
|------|-------------|-------------|
| Master M0-M4 | Loopback test | Master -> Slave -> Master |
| Slave S0-S6 | Direct access | Test pattern injection |

### 4.3 CDC Test Access

| Crossing | Test Method | Description |
|----------|-------------|-------------|
| CLK_SYS <-> CLK_IO | Handshake test | JTAG USER1 instruction |
| CLK_SYS <-> CLK_AON | Pulse sync test | Dedicated test mode |

## 5. Test Mode Definition

### 5.1 Test Mode Register

| Mode | Code | Description | Active Chains |
|------|------|-------------|---------------|
| NORMAL_MODE | 0x00 | Functional operation | None |
| SCAN_MODE | 0x01 | Scan chain access | All 8 chains |
| LBIST_MODE | 0x02 | Logic BIST execution | Arbiter + Router chains |
| CDC_TEST_MODE | 0x03 | CDC synchronization test | CDC chains |
| PROTOCOL_TEST | 0x04 | Protocol conversion test | Protocol chain |
| ROUTING_TEST | 0x05 | Address routing test | Router chain |
| BURN_IN_MODE | 0x06 | Burn-in stress test | Selected chains |

### 5.2 Test Mode Control Signals

| Signal | Width | Description |
|--------|-------|-------------|
| test_mode_i | 3 | Test mode selection |
| test_start_i | 1 | Test start command |
| test_done_o | 1 | Test completion |
| test_pass_o | 1 | Pass indicator |
| test_fail_o | 1 | Fail indicator |
| test_error_code_o | 8 | Error detail |

## 6. Coverage Target

### 6.1 CDC Fault Coverage

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Metastability | 100% | CDC stress test |
| FIFO Overflow/Underflow | 100% | FIFO depth test |
| Handshake Error | 100% | Handshake correctness test |
| Gray Code Error | 100% | Pointer encoding test |

### 6.2 Logic Fault Coverage

| Fault Type | Target Coverage | Method |
|------------|-----------------|--------|
| Stuck-at Fault | 98% | Scan + LBIST |
| Transition Fault | 95% | At-speed scan |
| Path Delay Fault | 92% | At-speed LBIST |

### 6.3 Module-Level Coverage

| Sub-Module | Stuck-at | Transition | CDC | Overall |
|------------|----------|------------|-----|---------|
| Arbiter Logic | 98% | 95% | - | 96% |
| Address Router | 98% | 95% | - | 96% |
| Protocol Converter | 95% | 92% | - | 94% |
| CDC Bridge | 100% | 100% | 100% | 100% |
| Timeout Logic | 98% | 95% | - | 96% |
| Register Slave | 95% | 92% | - | 94% |

### 6.4 Test Time Estimation

| Test Type | Duration | Description |
|-----------|----------|-------------|
| Scan Chain | ~1 ms | All 8 chains |
| LBIST Execution | ~50 ms | 5,000 patterns |
| CDC Test | ~10 ms | All CDC crossings |
| Protocol Test | ~5 ms | Conversion tests |
| Routing Test | ~5 ms | Address routing |
| Total Test Time | ~75 ms | All modes combined |

## 7. DFT Implementation Notes

### 7.1 CDC Test Guidelines

1. **Metastability Detection**: CDC path 使用 formal verification + STA CDC check。
2. **FIFO Safety**: Async FIFO 深度验证无溢出/无空读。
3. **At-Speed CDC Test**: CDC 测试在实际时钟频率下执行。

### 7.2 Arbitration Test Guidelines

1. **All Modes**: Priority, Round-Robin, Weighted 全覆盖。
2. **No Starvation**: Round-Robin 模式验证无饥饿。
3. **No Deadlock**: Priority 模式验证 timeout 机制有效。

### 7.3 Protocol Test Guidelines

1. **Full Opcode Coverage**: TileLink opcode 0-5, AXI all operations。
2. **Burst Correctness**: Burst length和 beat handling 验证。
3. **Error Pass-through**: Slave error 正确传递到 Master。

### 7.4 Test Integration

| Integration Point | Description |
|-------------------|-------------|
| M00 Systolic Array | Master M0 test coordination |
| M02/M03 Storage | Slave S0/S1 test coordination |
| M05 Power Manager | CDC AON test coordination |
| M15 JTAG | Master M4 (Debug) test coordination |

## 8. References

- IEEE 1149.1: JTAG Standard
- TileLink Specification: SiFive TileLink protocol
- AXI4 Specification: ARM AMBA AXI4 protocol
- REQ-DFT-001: Test coverage >= 95%
- REQ-IO-001, REQ-IO-002: CDC requirements
- M04 MAS.md: Module architecture specification