---
module: M03_DRAMController
type: verification
status: complete
parent: M03
module_type: storage
generated: "2026-05-17T16:00:00+08:00"
---

# M03: DRAM Controller Verification Plan

## 1. Overview

M03 DRAM Controller 是 TinyStories NPU 的主存储控制器，管理 2 GB 3D Stacked DRAM，通过 D2D 接口连接外部 DRAM die。验证目标是确保 Bandwidth >= 10 GB/s、ECC (72,64) SECDED 正确性、D2D Interface 稳定性、Row Hit Latency <= 100 ns、功耗效率 <= 5 pJ/bit。

### 1.1 Verification Targets

| Metric | Target | REQ Reference |
|--------|--------|---------------|
| Bandwidth | >= 10 GB/s | REQ-MEM-002 |
| ECC SECDED (72,64) | 100% correct | REQ-MEM-005 |
| D2D Bandwidth | >= 10 GB/s | REQ-D2D-001 |
| D2D Latency | <= 100 ns | REQ-D2D-004 |
| Row Hit Latency | <= 100 ns | REQ-MEM-003 |
| D2D Energy | <= 5 pJ/bit | REQ-D2D-003 |
| Memory Capacity | 2 GB | REQ-MEM-001 |

### 1.2 Verification Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 5.x | RTL simulation + coverage |
| Cocotb | 1.x | Python test framework |
| Formal | Yosys/ABC | D2D protocol assertion proof |
| DRAM Model | Python LPDDR4X | DRAM behavioral model |

## 2. Functional Coverage Points

| ID | Feature | Description | Priority | Coverage Target |
|----|---------|-------------|----------|-----------------|
| FC-001 | ECC SECDED (72,64) Encode | 64-bit to 72-bit encoding | P0 | 100% |
| FC-002 | ECC Syndrome Calc | 8-bit syndrome calculation | P0 | 100% |
| FC-003 | ECC Single Error Correct | Single-bit error correction | P0 | 100% |
| FC-004 | ECC Double Error Detect | Double-bit error detection | P0 | 100% |
| FC-005 | ECC Multi Error Detect | Multi-bit error detection | P1 | 100% |
| FC-006 | ECC Error Logging | Error address/type/count | P1 | 100% |
| FC-007 | ECC IRQ Generation | Error interrupt generation | P1 | 100% |
| FC-008 | LPDDR4X ACT | Activate command | P0 | 100% |
| FC-009 | LPDDR4X READ | Read command | P0 | 100% |
| FC-010 | LPDDR4X WRITE | Write command | P0 | 100% |
| FC-011 | LPDDR4X PRE | Precharge command | P0 | 100% |
| FC-012 | LPDDR4X REF | Refresh command | P1 | 100% |
| FC-013 | LPDDR4X SREF | Self-Refresh entry | P1 | 100% |
| FC-014 | LPDDR4X MRR | Mode Register Read | P2 | 95% |
| FC-015 | LPDDR4X MRW | Mode Register Write | P2 | 95% |
| FC-016 | Row Hit Access | Open page access | P0 | 100% |
| FC-017 | Row Miss Access | Need ACT access | P0 | 100% |
| FC-018 | Bank Select | Bank 0-7 selection | P0 | 100% |
| FC-019 | Burst Read | BL16/32 burst read | P0 | 100% |
| FC-020 | Burst Write | BL16/32 burst write | P0 | 100% |
| FC-021 | D2D TX Command | D2D command transmission | P0 | 100% |
| FC-022 | D2D TX Data | D2D data transmission | P0 | 100% |
| FC-023 | D2D RX Data | D2D data reception | P0 | 100% |
| FC-024 | D2D Training | Lane calibration | P0 | 100% |
| FC-025 | D2D PLL Lock | PLL lock verification | P0 | 100% |
| FC-026 | Bandwidth Arbitration | Master bandwidth allocation | P0 | 100% |
| FC-027 | Bandwidth Monitor | Bandwidth utilization tracking | P1 | 100% |
| FC-028 | Self-Refresh Entry | Enter self-refresh mode | P1 | 100% |
| FC-029 | Self-Refresh Exit | Exit self-refresh mode | P1 | 100% |
| FC-030 | Power Down Entry | Enter power down mode | P2 | 95% |
| FC-031 | Power Down Exit | Exit power down mode | P2 | 95% |
| FC-032 | Deep Power Down | DPD mode | P2 | 95% |
| FC-033 | CDC CLK_SYS->CLK_D2D | Command/data CDC | P0 | 100% |
| FC-034 | CDC CLK_D2D->CLK_SYS | Read data CDC | P0 | 100% |
| FC-035 | Address Valid | 0x0000_0000 - 0x7FFF_FFFF | P0 | 100% |
| FC-036 | Address Invalid | Out of range handling | P1 | 100% |
| FC-037 | Timeout Handling | Request timeout | P1 | 100% |
| FC-038 | Error Propagation | D2D error handling | P0 | 100% |
| FC-039 | DVFS Transition | DVFS operating point | P1 | 100% |
| FC-040 | Interrupt Generation | DRAM IRQ | P1 | 100% |

## 3. Assertion List

| ID | Type | Assertion | Description |
|----|------|-----------|-------------|
| AS-001 | Immediate | `bus_cmd_addr >= 0x0000_0000 && <= 0x7FFF_FFFF` | Address in DRAM range |
| AS-002 | Immediate | `d2d_cmd_burst in {16,32}` | Burst length valid |
| AS-003 | Immediate | `bw_priority <= 3` | Priority valid |
| AS-004 | Immediate | `dram_power_mode in {0,1,2}` | Power mode valid |
| AS-005 | Cover | `single_error_detected` | Single error coverage |
| AS-006 | Cover | `double_error_detected` | Double error coverage |
| AS-007 | Cover | `error_corrected` | Correction coverage |
| AS-008 | Immediate | `syndrome == 0 -> no_error` | No error syndrome |
| AS-009 | Immediate | `syndrome != 0 && parity_ok -> single_error` | Single error detect |
| AS-010 | Immediate | `syndrome != 0 && parity_fail -> double_error` | Double error detect |
| AS-011 | Cover | `all_syndrome_values_256` | All 256 syndrome values |
| AS-012 | Concurrent | `ACT -> READ/WRITE valid` | Activate sequence |
| AS-013 | Concurrent | `PRE -> Bank closed` | Precharge effect |
| AS-014 | Cover | `row_hit_latency <= 100ns` | REQ-MEM-003 |
| AS-015 | Cover | `bandwidth >= 10GB/s` | REQ-MEM-002 |
| AS-016 | Cover | `d2d_latency <= 100ns` | REQ-D2D-004 |
| AS-017 | Cover | `d2d_energy <= 5pJ/bit` | REQ-D2D-003 |
| AS-018 | Immediate | `d2d_pll_lock == 1 -> training_start` | PLL dependency |
| AS-019 | Concurrent | `training_done -> normal_op` | Training complete |
| AS-020 | Cover | `all_banks_accessed` | Bank coverage |
| AS-021 | Immediate | `cdc_fifo_not_overflow` | CDC FIFO safety |
| AS-022 | Immediate | `cdc_fifo_not_empty_read` | CDC FIFO safety |
| AS-023 | Concurrent | `sref_entry -> dram_idle` | Self-refresh timing |
| AS-024 | Concurrent | `sref_exit -> dram_active` | Self-refresh exit |
| AS-025 | Cover | `all_master_bw_allocation` | BW arbitration |
| AS-026 | Immediate | `timeout_triggered -> error_flag` | Timeout handling |
| AS-027 | Cover | `dvfs_transition_complete` | DVFS coverage |
| AS-028 | Concurrent | `d2d_error -> dram_error` | Error propagation |
| AS-029 | Cover | `burst_complete` | Burst coverage |
| AS-030 | Immediate | `ecc_threshold_trigger -> irq` | Threshold IRQ |

## 4. Test Scenarios

### 4.1 Normal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TN-001 | Single Read | Single word read | Valid address | Correct data |
| TN-002 | Single Write | Single word write | Address + data | Data stored |
| TN-003 | Burst Read BL16 | 16-beat burst read | Burst address | All data correct |
| TN-004 | Burst Read BL32 | 32-beat burst read | Burst address | All data correct |
| TN-005 | Burst Write BL16 | 16-beat burst write | Burst data | All data stored |
| TN-006 | Burst Write BL32 | 32-beat burst write | Burst data | All data stored |
| TN-007 | Row Hit Read | Open page read | Same row access | Latency <= 100 ns |
| TN-008 | Row Miss Read | Closed page read | Different row | ACT + READ |
| TN-009 | Bank Switch | Bank 0 to Bank 7 | Different banks | All banks work |
| TN-010 | ECC No Error | Normal read/write | Clean data | No error flag |
| TN-011 | ECC Single Error | Inject single bit error | Corrupted 1 bit | Error corrected |
| TN-012 | ECC Double Error | Inject double bit error | Corrupted 2 bits | Error detected |
| TN-013 | ECC Error Log | Error logging | Error event | Correct log |
| TN-014 | ECC IRQ | Interrupt generation | Error + irq_en | IRQ generated |
| TN-015 | D2D Training | Lane calibration | Training start | Training done |
| TN-016 | D2D PLL Lock | PLL verification | PLL input | PLL locked |
| TN-017 | D2D TX Command | Command transmission | LPDDR4X command | Command sent |
| TN-018 | D2D TX/RX Data | Data transfer | Data payload | Data correct |
| TN-019 | Bandwidth Arbitration | BW allocation | Multi-master | Correct allocation |
| TN-020 | Bandwidth Monitor | BW tracking | Traffic | Accurate count |
| TN-021 | Self-Refresh Entry | Enter SREF | SREF request | DRAM in SREF |
| TN-022 | Self-Refresh Exit | Exit SREF | Exit request | DRAM active |
| TN-023 | CDC Sys->D2D | Clock domain crossing | Sys request | D2D received |
| TN-024 | CDC D2D->Sys | Clock domain crossing | D2D response | Sys received |
| TN-025 | DVFS OP0-OP1 | Frequency switch | DVFS request | Seamless transition |
| TN-026 | Full Address Walk | All addresses | 2GB range | All accessible |
| TN-027 | Bandwidth Test | Max bandwidth | Burst traffic | BW >= 10 GB/s |
| TN-028 | Energy Test | Energy measurement | Traffic | Energy <= 5 pJ/bit |
| TN-029 | Refresh Test | Auto refresh | Refresh interval | Data preserved |
| TN-030 | Interrupt Test | IRQ generation | Error event | IRQ generated |

### 4.2 Boundary Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TB-001 | Address Min | addr = 0x0000_0000 | Minimum address | Correct access |
| TB-002 | Address Max | addr = 0x7FFF_FFFC | Maximum address | Correct access |
| TB-003 | Bank Boundary | Bank 0 to Bank 7 | All banks | All accessible |
| TB-004 | Row Boundary | Row 0 to Row max | All rows | All accessible |
| TB-005 | Burst Boundary | BL16 start/end | Burst boundary | Correct burst |
| TB-006 | ECC Syndrome All 0 | No error syndrome | syndrome=0 | No error flag |
| TB-007 | ECC Syndrome Max | Max syndrome value | syndrome=255 | Error detected |
| TB-008 | ECC All 0s Data | All zero data | data=0 | Correct ECC |
| TB-009 | ECC All 1s Data | All ones data | data=0xFFFFFFFF_FFFFFFFF | Correct ECC |
| TB-010 | Single Error Bit 0 | Error at bit 0 | Bit 0 flipped | Correct bit 0 |
| TB-011 | Single Error Bit 63 | Error at bit 63 | Bit 63 flipped | Correct bit 63 |
| TB-012 | Double Error Adjacent | Adjacent bits error | Bits 0,1 flipped | Double detected |
| TB-013 | D2D Lane 0 | Lane 0 test | Lane 0 only | Lane 0 works |
| TB-014 | D2D All Lanes | All 16 lanes | All lanes | All lanes work |
| TB-015 | CDC FIFO Full | FIFO near full | High traffic | FIFO handled |
| TB-016 | CDC FIFO Empty | FIFO empty | Low traffic | FIFO handled |
| TB-017 | Timeout Boundary | Timeout threshold | Timeout value | Timeout triggered |
| TB-018 | Power All Modes | All power modes | Active/SREF/DPD | All modes work |

### 4.3 Abnormal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TA-001 | Address Invalid | addr >= 0x8000_0000 | Out of DRAM range | Error flag |
| TA-002 | Address Underflow | addr < 0x0000_0000 | Negative address | Error flag |
| TA-003 | Burst Invalid | d2d_cmd_burst = 255 | Invalid burst | Error flag |
| TA-004 | Bank Invalid | Bank > 7 | Invalid bank | Error flag |
| TA-005 | Multi-bit Error | 3+ bits error | Multi-bit corruption | Multi detected |
| TA-006 | ECC Disabled | ecc_en = 0 | ECC off | No ECC check |
| TA-007 | IRQ Disabled | ecc_irq_en = 0 | IRQ off | No IRQ generated |
| TA-008 | D2D PLL Unlocked | PLL not locked | PLL fail | Training abort |
| TA-009 | D2D Lane Fail | Lane error | Lane failure | Lane mask update |
| TA-010 | D2D Timeout | No D2D response | Timeout trigger | Timeout handling |
| TA-011 | CDC FIFO Overflow | FIFO overflow | High traffic | Overflow handling |
| TA-012 | CDC FIFO Underflow | FIFO underflow | Empty read | Underflow handling |
| TA-013 | Self-Refresh Abort | Abort SREF entry | SREF abort | Abort handled |
| TA-014 | Power Transition Error | Mode switch error | Error during switch | Error handling |
| TA-015 | Bandwidth Starvation | BW allocation fail | No BW granted | Starvation detect |
| TA-016 | DVFS Under Transfer | DVFS mid-transfer | DVFS request | Deferred switch |
| TA-017 | Refresh Conflict | Refresh mid-access | Refresh request | Deferred refresh |
| TA-018 | Error Threshold Overflow | Counter overflow | Max count | Counter wrap |

## 5. Coverage Targets

| Category | Target | Metric |
|----------|--------|--------|
| Code Coverage | 100% | Line, branch, toggle, FSM |
| Functional Coverage | 95% | All FC points hit |
| Assertion Coverage | 100% | All AS covered |
| Corner Case Coverage | 95% | Boundary + abnormal scenarios |
| ECC Coverage | 100% | All syndrome values (256) |
| D2D Coverage | 100% | All lanes, all training phases |

### 5.1 Code Coverage Details

| Type | Target | Description |
|------|--------|-------------|
| Line Coverage | 100% | All RTL lines executed |
| Branch Coverage | 100% | All if/case branches taken |
| Toggle Coverage | 100% | All signals 0->1 and 1->0 |
| FSM Coverage | 100% | All LPDDR4X controller FSM states |
| Expression Coverage | 95% | All expression conditions |

### 5.2 Functional Coverage Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Bandwidth | >= 10 GB/s | Burst throughput test |
| Latency (Row Hit) | <= 100 ns | Cycle timing measurement |
| D2D Latency | <= 100 ns | RTT timing measurement |
| D2D Energy | <= 5 pJ/bit | Energy calculation |
| ECC Coverage | All 256 syndromes | Syndrome walk test |
| Bank Coverage | All 8 banks | Bank walk test |

## 6. Verification Tools

### 6.1 Simulation Environment

| Component | Tool | Configuration |
|-----------|------|---------------|
| RTL Simulator | Verilator 5.x | --coverage + --trace |
| Test Framework | Cocotb | Python-based test cases |
| DRAM Model | Python LPDDR4X | Behavioral DRAM die |
| ECC Model | Python Hamming | Reference ECC calc |
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
| ECC Syndrome (72,64) | Yosys Sby | All 256 syndrome values proof |
| LPDDR4X Protocol | Sby | Command sequence proof |
| CDC FIFO Safety | Sby | No overflow/underflow proof |
| D2D Training | Sby | Training sequence proof |

### 6.4 DRAM Behavioral Model

```
DRAM Die Behavioral Model:
  - 2 GB capacity
  - 8 Banks
  - Row/Column addressing
  - LPDDR4X timing parameters
  - ECC injection capability
  - Power mode support
```

### 6.5 Test Execution Flow

```
1. Build RTL with Verilator + coverage
2. Run Normal scenarios (TN-001 to TN-030)
3. Run Boundary scenarios (TB-001 to TB-018)
4. Run Abnormal scenarios (TA-001 to TA-018)
5. Run D2D training sequence
6. Run ECC syndrome walk (256 values)
7. Collect coverage data
8. Analyze coverage report
9. Fill coverage holes if < target
10. Generate verification report
```

## 7. References

- REQ-MEM-001: 2 GB capacity
- REQ-MEM-002: Bandwidth >= 10 GB/s
- REQ-MEM-003: Latency <= 100 ns
- REQ-MEM-005: ECC SECDED
- REQ-D2D-001: D2D bandwidth >= 10 GB/s
- REQ-D2D-003: D2D energy <= 5 pJ/bit
- REQ-D2D-004: D2D latency <= 100 ns
- MAS: /spec_mas/M03/MAS.md
- FSM: /spec_mas/M03/FSM.md
- Datapath: /spec_mas/M03/datapath.md