---
module: M04_SystemBus
type: verification
status: complete
parent: M04
module_type: interconnect
generated: "2026-05-17T16:00:00+08:00"
---

# M04: System Bus Verification Plan

## 1. Overview

M04 System Bus 是 TinyStories NPU 的核心互联模块，实现 TileLink/AXI 双协议支持、多 Master 仲裁、地址路由和跨时钟域同步。验证目标是确保 TileLink/AXI 协议合规性、仲裁公平性、路由正确性、CDC 稳定性、带宽 >= 10 GB/s DRAM 和 >= 8 GB/s SRAM。

### 1.1 Verification Targets

| Metric | Target | REQ Reference |
|--------|--------|---------------|
| TileLink Protocol | 100% compliant | Internal |
| AXI4 Protocol | 100% compliant | Internal |
| Arbitration Fairness | No starvation | REQ-MEM-002 |
| Address Routing | All slaves reachable | Internal |
| CDC Reliability | Zero metastability | REQ-IO-001, REQ-IO-002 |
| DRAM Bandwidth | >= 10 GB/s | REQ-MEM-002 |
| SRAM Bandwidth | >= 8 GB/s | REQ-MEM-002 |
| Timeout Handling | All cases | Internal |
| Error Response | All error types | Internal |

### 1.2 Verification Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 5.x | RTL simulation + coverage |
| Cocotb | 1.x | Python test framework |
| Formal | Yosys/ABC | Protocol assertion proof |
| TileLink Spec | TileLink-UH | Protocol reference |
| AXI4 Spec | ARM AXI4 | Protocol reference |

## 2. Functional Coverage Points

| ID | Feature | Description | Priority | Coverage Target |
|----|---------|-------------|----------|-----------------|
| FC-001 | TileLink PutFullData | Write full data operation | P0 | 100% |
| FC-002 | TileLink PutPartialData | Partial write with mask | P1 | 100% |
| FC-003 | TileLink Get | Read operation | P0 | 100% |
| FC-004 | TileLink AccessAck | Write response | P0 | 100% |
| FC-005 | TileLink AccessAckData | Read response | P0 | 100% |
| FC-006 | TileLink Burst | Multi-beat transfer | P1 | 100% |
| FC-007 | AXI4 Write Addr | AW channel write | P0 | 100% |
| FC-008 | AXI4 Write Data | W channel data | P0 | 100% |
| FC-009 | AXI4 Write Resp | B channel response | P0 | 100% |
| FC-010 | AXI4 Read Addr | AR channel read | P0 | 100% |
| FC-011 | AXI4 Read Data | R channel data | P0 | 100% |
| FC-012 | AXI4 Burst INCR | INCR burst mode | P1 | 100% |
| FC-013 | AXI4 Burst FIXED | FIXED burst mode | P2 | 95% |
| FC-014 | Protocol Conversion | TileLink <-> AXI conversion | P0 | 100% |
| FC-015 | Master M0 (Systolic) | M00 requests | P0 | 100% |
| FC-016 | Master M1 (SRAM) | M02 DMA requests | P0 | 100% |
| FC-017 | Master M2 (DRAM) | M03 DMA requests | P0 | 100% |
| FC-018 | Master M3 (ISA) | M13 instruction fetch | P0 | 100% |
| FC-019 | Master M4 (JTAG) | M15 debug requests | P1 | 100% |
| FC-020 | Slave S0 (DRAM) | DRAM target | P0 | 100% |
| FC-021 | Slave S1 (SRAM) | SRAM target | P0 | 100% |
| FC-022 | Slave S2-S6 (Regs) | Register targets | P1 | 100% |
| FC-023 | Arbitration Priority | Priority-based arb | P0 | 100% |
| FC-024 | Arbitration Round-Robin | RR mode | P1 | 100% |
| FC-025 | Arbitration Weighted RR | Weighted mode | P2 | 95% |
| FC-026 | Route DRAM | 0x0000_0000 - 0x7FFF_FFFF | P0 | 100% |
| FC-027 | Route SRAM | 0x8000_0000 - 0x8007_FFFF | P0 | 100% |
| FC-028 | Route Bus Regs | 0x8008_0000 | P1 | 100% |
| FC-029 | Route ISA Regs | 0x8009_0000 | P1 | 100% |
| FC-030 | Route Secure Regs | 0x800A_0000 | P1 | 100% |
| FC-031 | Route ECC Regs | 0x800B_0000 | P1 | 100% |
| FC-032 | Route Power Regs | 0x800C_0000 | P1 | 100% |
| FC-033 | Route Invalid | Invalid address error | P0 | 100% |
| FC-034 | CDC CLK_IO->CLK_SYS | JTAG request CDC | P0 | 100% |
| FC-035 | CDC CLK_SYS->CLK_IO | JTAG response CDC | P0 | 100% |
| FC-036 | CDC CLK_SYS->CLK_AON | Power request CDC | P0 | 100% |
| FC-037 | CDC CLK_AON->CLK_SYS | Power response CDC | P0 | 100% |
| FC-038 | Timeout Trigger | Request timeout | P1 | 100% |
| FC-039 | Timeout Recovery | Timeout recovery | P1 | 100% |
| FC-040 | Error Invalid Addr | Invalid address error | P0 | 100% |
| FC-041 | Error Slave Error | Slave error pass-through | P0 | 100% |
| FC-042 | Error IRQ | Error interrupt | P1 | 100% |
| FC-043 | Performance Counter | Transaction counting | P1 | 100% |
| FC-044 | Latency Measurement | Avg latency tracking | P1 | 100% |
| FC-045 | Bus Enable/Disable | Bus control | P1 | 100% |
| FC-046 | Multi-Master Concurrent | Concurrent requests | P0 | 100% |
| FC-047 | Response Routing | Response to correct master | P0 | 100% |
| FC-048 | Burst Handling | Multi-beat completion | P1 | 100% |

## 3. Assertion List

| ID | Type | Assertion | Description |
|----|------|-----------|-------------|
| AS-001 | Immediate | `tl_a_opcode in {0,1,4,5}` | TileLink opcode valid |
| AS-002 | Immediate | `tl_a_size <= 4` | Transaction size valid |
| AS-003 | Immediate | `tl_a_source <= 4` | Source ID valid |
| AS-004 | Immediate | `axi_awlen <= 255` | AXI burst length valid |
| AS-005 | Immediate | `axi_awsize <= 4` | AXI burst size valid |
| AS-006 | Immediate | `axi_awburst in {0,1,2}` | AXI burst type valid |
| AS-007 | Cover | `tilelink_protocol_complete` | TileLink coverage |
| AS-008 | Cover | `axi4_protocol_complete` | AXI4 coverage |
| AS-009 | Concurrent | `tl_a_valid && tl_a_ready -> transfer` | TileLink handshake |
| AS-010 | Concurrent | `axi_awvalid && axi_awready -> aw_accepted` | AXI handshake |
| AS-011 | Concurrent | `axi_wvalid && axi_wready -> w_accepted` | AXI handshake |
| AS-012 | Concurrent | `axi_arvalid && axi_arready -> ar_accepted` | AXI handshake |
| AS-013 | Cover | `all_masters_tested` | Master coverage |
| AS-014 | Cover | `all_slaves_tested` | Slave coverage |
| AS-015 | Immediate | `arb_winner <= 4` | Winner ID valid |
| AS-016 | Cover | `no_starvation` | Arbitration fairness |
| AS-017 | Immediate | `route_target <= 6` | Target ID valid |
| AS-018 | Cover | `route_dram_correct` | DRAM routing |
| AS-019 | Cover | `route_sram_correct` | SRAM routing |
| AS-020 | Cover | `route_regs_correct` | Register routing |
| AS-021 | Immediate | `invalid_address -> error_response` | Error routing |
| AS-022 | Concurrent | `cdc_fifo_not_overflow` | CDC FIFO safety |
| AS-023 | Concurrent | `cdc_fifo_not_empty_read` | CDC FIFO safety |
| AS-024 | Cover | `cdc_io_sync_complete` | IO CDC coverage |
| AS-025 | Cover | `cdc_aon_sync_complete` | AON CDC coverage |
| AS-026 | Cover | `timeout_triggered` | Timeout coverage |
| AS-027 | Immediate | `timeout -> error_response` | Timeout response |
| AS-028 | Cover | `error_irq_generated` | Error IRQ coverage |
| AS-029 | Cover | `burst_complete` | Burst completion |
| AS-030 | Cover | `response_returned_correct_master` | Response routing |
| AS-031 | Immediate | `bus_enable == 1 -> bus_active` | Bus enable effect |
| AS-032 | Cover | `perf_counter_increment` | Counter coverage |
| AS-033 | Cover | `latency_measured` | Latency tracking |
| AS-034 | Concurrent | `protocol_conversion_correct` | Conversion accuracy |
| AS-035 | Cover | `multi_master_arbitration` | Arbitration coverage |
| AS-036 | Immediate | `bus_busy == 1 -> transaction_active` | Busy flag accurate |

## 4. Test Scenarios

### 4.1 Normal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TN-001 | TileLink Write | PutFullData operation | Valid write request | AccessAck response |
| TN-002 | TileLink Read | Get operation | Valid read request | AccessAckData response |
| TN-003 | TileLink Burst | Multi-beat TileLink | Burst request | All beats complete |
| TN-004 | AXI4 Write | AW+W+B channels | AXI write request | B response OK |
| TN-005 | AXI4 Read | AR+R channels | AXI read request | R data correct |
| TN-006 | AXI4 Burst INCR | INCR burst read | Burst request | All beats correct |
| TN-007 | AXI4 Burst Write | INCR burst write | Burst write | All beats stored |
| TN-008 | Master M0 Request | Systolic Array access | M0 TileLink request | DRAM/SRAM response |
| TN-009 | Master M3 Request | ISA Decoder AXI | M3 AXI request | Register response |
| TN-010 | Master M4 Request | JTAG debug AXI | M4 AXI request | CDC + response |
| TN-011 | Slave S0 Access | DRAM target | DRAM address | DRAM response |
| TN-012 | Slave S1 Access | SRAM target | SRAM address | SRAM response |
| TN-013 | Slave S2 Access | Bus registers | Reg address | Register response |
| TN-014 | Arb Priority Mode | Priority arbitration | Multi-master | Highest priority wins |
| TN-015 | Arb Round-Robin | RR arbitration | RR mode | Fair scheduling |
| TN-016 | Arb Weighted RR | Weighted arbitration | Weight config | Weight distribution |
| TN-017 | Route DRAM | DRAM address routing | addr < 0x8000_0000 | S0 selected |
| TN-018 | Route SRAM | SRAM address routing | addr >= 0x8000_0000 | S1 selected |
| TN-019 | Route Registers | Register routing | Reg addresses | Correct S2-S6 |
| TN-020 | CDC IO->Sys | IO domain request | JTAG request | Sys domain received |
| TN-021 | CDC Sys->IO | Sys domain response | Bus response | IO domain received |
| TN-022 | CDC Sys->AON | AON request | Power request | AON received |
| TN-023 | CDC AON->Sys | AON response | Power response | Sys received |
| TN-024 | Timeout Normal | Normal timeout | Timeout value | Timeout triggered |
| TN-025 | Error Invalid Addr | Invalid address | addr = 0xFFFF_FFFF | Error response |
| TN-026 | Performance Counter | Transaction count | Multiple transactions | Accurate count |
| TN-027 | Latency Measurement | Avg latency | Traffic | Accurate latency |
| TN-028 | Multi-Master Concurrent | Concurrent requests | All masters active | Arbitration correct |
| TN-029 | Response Routing | Response return | Completed request | Correct master |
| TN-030 | Protocol Conversion | TL to AXI conversion | TileLink request | AXI slave access |
| TN-031 | Bus Enable/Disable | Bus control | Enable/disable | Bus state correct |
| TN-032 | Burst Completion | Multi-beat finish | Burst request | All beats done |

### 4.2 Boundary Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TB-001 | Address Min DRAM | addr = 0x0000_0000 | Minimum DRAM | DRAM access |
| TB-002 | Address Max DRAM | addr = 0x7FFF_FFFF | Maximum DRAM | DRAM access |
| TB-003 | Address Min SRAM | addr = 0x8000_0000 | Minimum SRAM | SRAM access |
| TB-004 | Address Max SRAM | addr = 0x8007_FFFF | Maximum SRAM | SRAM access |
| TB-005 | Address Boundary Reg | addr = 0x8008_0000 | Reg boundary | Bus regs |
| TB-006 | Burst Max Length | axi_awlen = 255 | Max burst | Full burst |
| TB-007 | Burst Size Max | axi_awsize = 4 | Max size | 128-bit transfer |
| TB-008 | All Masters Request | All 5 masters | Concurrent | Arbitration |
| TB-009 | All Slaves Access | All 7 slaves | Sequential | All accessible |
| TB-010 | Timeout Min | timeout = 64 cycles | Min timeout | Timeout triggered |
| TB-011 | Timeout Max | timeout = 65535 cycles | Max timeout | Timeout handling |
| TB-012 | CDC FIFO Near Full | FIFO depth - 1 | High traffic | FIFO handled |
| TB-013 | CDC FIFO Near Empty | FIFO depth = 1 | Low traffic | FIFO handled |
| TB-014 | Priority All Same | Same priority | Equal priority | Round-robin |
| TB-015 | Weight Max/Min | Max/min weights | Weight config | Weight distribution |
| TB-016 | Burst Cross Boundary | Cross address range | Boundary burst | Error handling |

### 4.3 Abnormal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TA-001 | Invalid TileLink Opcode | tl_a_opcode = 7 | Invalid opcode | Error response |
| TA-002 | Invalid AXI Burst Type | axi_awburst = 3 | Invalid burst | Error response |
| TA-003 | Invalid Master ID | tl_a_source = 7 | Invalid master | Error flag |
| TA-004 | Invalid Slave ID | route_target = 7 | Invalid slave | Error flag |
| TA-005 | Address Out of Range | addr = 0xFFFF_FFFF | Invalid address | Error response |
| TA-006 | Address Gap | addr = 0x800D_0000 | Unmapped region | Error response |
| TA-007 | AXI Wrap Burst | axi_awburst = 2 | WRAP burst | Error response |
| TA-008 | CDC FIFO Overflow | FIFO overflow | High traffic | Overflow handling |
| TA-009 | CDC FIFO Underflow | FIFO underflow | Empty read | Underflow handling |
| TA-010 | Timeout Exceeded | Timeout trigger | No response | Timeout error |
| TA-011 | Slave Error | Slave error response | Slave error | Error pass-through |
| TA-012 | Master Abort | Master abort request | Abort signal | Abort handling |
| TA-013 | Bus Disable Access | Access when disabled | Bus disabled | Access rejected |
| TA-014 | Arb Starvation Test | Long wait low priority | Priority test | Starvation detect |
| TA-015 | Response Mismatch | Wrong response routing | Routing error | Error flag |
| TA-016 | Protocol Mismatch | TL/AXI mismatch | Protocol error | Error handling |
| TA-017 | Concurrent Error | Multi-master error | Multiple errors | Error priority |
| TA-018 | DVFS During Transfer | DVFS mid-transfer | DVFS request | Deferred DVFS |

## 5. Coverage Targets

| Category | Target | Metric |
|----------|--------|--------|
| Code Coverage | 100% | Line, branch, toggle, FSM |
| Functional Coverage | 95% | All FC points hit |
| Assertion Coverage | 100% | All AS covered |
| Corner Case Coverage | 95% | Boundary + abnormal scenarios |
| Protocol Coverage | 100% | TileLink + AXI full coverage |
| CDC Coverage | 100% | All CDC paths verified |

### 5.1 Code Coverage Details

| Type | Target | Description |
|------|--------|-------------|
| Line Coverage | 100% | All RTL lines executed |
| Branch Coverage | 100% | All if/case branches taken |
| Toggle Coverage | 100% | All signals 0->1 and 1->0 |
| FSM Coverage | 100% | All arbitration/routing FSM states |
| Expression Coverage | 95% | All expression conditions |

### 5.2 Functional Coverage Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| TileLink Compliance | 100% | Protocol checker |
| AXI4 Compliance | 100% | Protocol checker |
| Arbitration Fairness | No starvation | Starvation test |
| DRAM Bandwidth | >= 10 GB/s | Throughput test |
| SRAM Bandwidth | >= 8 GB/s | Throughput test |
| CDC Reliability | Zero metastability | CDC formal check |

## 6. Verification Tools

### 6.1 Simulation Environment

| Component | Tool | Configuration |
|-----------|------|---------------|
| RTL Simulator | Verilator 5.x | --coverage + --trace |
| Test Framework | Cocotb | Python-based test cases |
| TileLink Checker | Formal | Protocol assertion |
| AXI Checker | Formal | Protocol assertion |
| Waveform | GTKWave | Debug visualization |

### 6.2 Coverage Collection

```bash
# Verilator coverage command
verilator --cc --exe --coverage -Wno-fatal top.v tb_top.cpp
make -C obj_dir
./obj_dir/Vtop --coverage

# Coverage analysis
verilator_coverage --annotate coverage.log obj_dir/Vtop_coverage.dat
```

### 6.3 Formal Verification

| Property | Tool | Method |
|----------|------|--------|
| TileLink Protocol | Yosys Sby | Full protocol proof |
| AXI4 Protocol | Sby | Full protocol proof |
| Arbitration Fairness | Sby | No starvation proof |
| CDC FIFO Safety | Sby | No overflow/underflow proof |
| Address Routing | Sby | All addresses proof |

### 6.4 Protocol Checkers

```
TileLink Protocol Checker:
  - Opcode validity
  - Size consistency
  - Handshake timing
  - Response correctness

AXI4 Protocol Checker:
  - Channel ordering
  - ID tracking
  - Burst completion
  - Response validity
```

### 6.5 Test Execution Flow

```
1. Build RTL with Verilator + coverage
2. Run Normal scenarios (TN-001 to TN-032)
3. Run Boundary scenarios (TB-001 to TB-016)
4. Run Abnormal scenarios (TA-001 to TA-018)
5. Run protocol compliance tests
6. Run CDC reliability tests
7. Collect coverage data
8. Analyze coverage report
9. Fill coverage holes if < target
10. Generate verification report
```

## 7. References

- REQ-MEM-002: Bandwidth targets
- REQ-IO-001: CDC CLK_SYS/CLK_IO
- REQ-IO-002: CDC CLK_SYS/CLK_AON
- TileLink Specification: TileLink-UH
- AXI4 Specification: ARM AXI4 Protocol
- MAS: /spec_mas/M04/MAS.md
- FSM: /spec_mas/M04/FSM.md
- Datapath: /spec_mas/M04/datapath.md