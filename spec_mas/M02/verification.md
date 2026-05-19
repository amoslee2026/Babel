---
module: M02_SRAMScratchpad
type: verification
status: complete
parent: M02
module_type: storage
generated: "2026-05-17T16:00:00+08:00"
---

# M02: SRAM Scratchpad Verification Plan

## 1. Overview

M02 SRAM Scratchpad 是 TinyStories NPU 的 512 KB 高速片上存储模块，配备 SECDED ECC (39,32) 保护。验证目标是确保 ECC 单错纠正/双错检测正确性、Bank Interleaving 无冲突、Address Conflict 处理、访问延迟 <= 2 ns、带宽 >= 8 GB/s。

### 1.1 Verification Targets

| Metric | Target | REQ Reference |
|--------|--------|---------------|
| ECC SECDED (39,32) | 100% correct | REQ-MEM-005 |
| Single Error Correct | All syndrome values | REQ-MEM-005 |
| Double Error Detect | All patterns | REQ-MEM-005 |
| Bank Interleaving | Zero conflict at factor 4 | Internal |
| Access Latency | <= 2 ns @ 500 MHz | REQ-MEM-003 |
| Bandwidth | >= 8 GB/s | REQ-MEM-002 |
| Address Range | 0x8000_0000 - 0x8007_FFFF | REQ-MEM-004 |

### 1.2 Verification Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 5.x | RTL simulation + coverage |
| Cocotb | 1.x | Python test framework |
| Formal | Yosys/ABC | ECC assertion proof |
| BIST | March C+ | SRAM array self-test |

## 2. Functional Coverage Points

| ID | Feature | Description | Priority | Coverage Target |
|----|---------|-------------|----------|-----------------|
| FC-001 | ECC SECDED Encode | 32-bit to 39-bit encoding | P0 | 100% |
| FC-002 | ECC Syndrome Calc | 7-bit syndrome calculation | P0 | 100% |
| FC-003 | ECC Single Error Correct | Single-bit error correction | P0 | 100% |
| FC-004 | ECC Double Error Detect | Double-bit error detection | P0 | 100% |
| FC-005 | ECC Multi Error Detect | Multi-bit error detection | P1 | 100% |
| FC-006 | ECC Error Logging | Error address/type/count | P1 | 100% |
| FC-007 | ECC IRQ Generation | Error interrupt generation | P1 | 100% |
| FC-008 | 32-bit Read | 32-bit data read | P0 | 100% |
| FC-009 | 32-bit Write | 32-bit data write | P0 | 100% |
| FC-010 | 64-bit Read | 64-bit data read | P0 | 100% |
| FC-011 | 64-bit Write | 64-bit data write | P0 | 100% |
| FC-012 | Bank Select | Bank[16:19] addressing | P0 | 100% |
| FC-013 | Bank Interleaving | 4-way interleaving | P0 | 100% |
| FC-014 | Bank Conflict | Conflict detection/wait | P1 | 100% |
| FC-015 | Priority Arb | Priority-based arbitration | P0 | 100% |
| FC-016 | Master M00 Access | Systolic Array access | P0 | 100% |
| FC-017 | Master M09-M12 | Operator Unit access | P0 | 100% |
| FC-018 | Master M13 | ISA Decoder access | P1 | 100% |
| FC-019 | Master M15 | JTAG Debug access | P2 | 95% |
| FC-020 | Bus Interface | TileLink/AXI interface | P0 | 100% |
| FC-021 | Direct Interface | Compute Unit direct access | P0 | 100% |
| FC-022 | Address Valid | 0x8000_0000 - 0x8007_FFFF | P0 | 100% |
| FC-023 | Address Invalid | Out of range handling | P1 | 100% |
| FC-024 | Write Byte Enable | wstrb byte masking | P1 | 100% |
| FC-025 | Power Active | Normal operation mode | P1 | 100% |
| FC-026 | Power Sleep | Sleep retention mode | P2 | 95% |
| FC-027 | Power Deep Sleep | Power Gate mode | P2 | 95% |
| FC-028 | DVFS OP0 | 500 MHz operation | P1 | 100% |
| FC-029 | DVFS OP1 | 250 MHz operation | P1 | 100% |
| FC-030 | BIST March C+ | Built-in self-test | P1 | 100% |
| FC-031 | ECC Test Mode | Error injection mode | P1 | 100% |
| FC-032 | Retention Enter | Enter retention mode | P2 | 95% |
| FC-033 | Retention Exit | Exit retention mode | P2 | 95% |
| FC-034 | Power Gate Enter | Enter power gate | P2 | 95% |
| FC-035 | Power Gate Exit | Exit power gate | P2 | 95% |

## 3. Assertion List

| ID | Type | Assertion | Description |
|----|------|-----------|-------------|
| AS-001 | Immediate | `bus_cmd_addr >= 0x8000_0000 && <= 0x8007_FFFF` | Address in SRAM range |
| AS-002 | Immediate | `bus_cmd_width in {0,1}` | Access width valid |
| AS-003 | Immediate | `arb_master_id <= 6` | Master ID valid |
| AS-004 | Immediate | `arb_priority <= 3` | Priority valid |
| AS-005 | Cover | `single_error_detected` | Single error coverage |
| AS-006 | Cover | `double_error_detected` | Double error coverage |
| AS-007 | Cover | `error_corrected` | Correction coverage |
| AS-008 | Immediate | `syndrome == 0 -> no_error` | No error syndrome |
| AS-009 | Immediate | `syndrome != 0 && parity_ok -> single_error` | Single error detect |
| AS-010 | Immediate | `syndrome != 0 && parity_fail -> double_error` | Double error detect |
| AS-011 | Cover | `all_syndrome_values` | All 128 syndrome values |
| AS-012 | Concurrent | `ecc_error -> ecc_err_valid` | Error flag timing |
| AS-013 | Concurrent | `ecc_irq -> ecc_irq_en` | IRQ enable dependency |
| AS-014 | Immediate | `bank_addr < 128` | Bank index valid |
| AS-015 | Cover | `bank_conflict_detected` | Conflict coverage |
| AS-016 | Concurrent | `arb_grant -> arb_busy` | Grant/busy timing |
| AS-017 | Cover | `all_master_ids` | All masters tested |
| AS-018 | Immediate | `ecc_enable == 1 || 0` | ECC enable valid |
| AS-019 | Cover | `32bit_access` | 32-bit access coverage |
| AS-020 | Cover | `64bit_access` | 64-bit access coverage |
| AS-021 | Immediate | `sram_retention valid` | Retention mode valid |
| AS-022 | Immediate | `sram_power_gate valid` | Power gate valid |
| AS-023 | Cover | `dvfs_op0_transition` | DVFS OP0 coverage |
| AS-024 | Cover | `dvfs_op1_transition` | DVFS OP1 coverage |
| AS-025 | Concurrent | `write_complete -> read_valid` | Write-read ordering |
| AS-026 | Immediate | `ecc_err_count increment` | Counter increment |
| AS-027 | Cover | `bist_pass` | BIST pass coverage |
| AS-028 | Cover | `bist_fail` | BIST fail coverage |

## 4. Test Scenarios

### 4.1 Normal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TN-001 | 32-bit Read | Basic 32-bit read | Valid address | Correct data |
| TN-002 | 32-bit Write | Basic 32-bit write | Address + data | Data stored |
| TN-003 | 64-bit Read | 64-bit read operation | Valid address | Correct data |
| TN-004 | 64-bit Write | 64-bit write operation | Address + data | Data stored |
| TN-005 | ECC No Error | Normal read/write | Clean data | No error flag |
| TN-006 | ECC Single Error | Inject single bit error | Corrupted 1 bit | Error corrected |
| TN-007 | ECC Double Error | Inject double bit error | Corrupted 2 bits | Error detected |
| TN-008 | ECC Error Log | Error logging | Error event | Correct log |
| TN-009 | ECC IRQ | Interrupt generation | Error + irq_en | IRQ generated |
| TN-010 | Bank Interleave 0 | Bank 0 access | addr[16:19]=0 | Bank 0 selected |
| TN-011 | Bank Interleave 1-4 | Consecutive banks | addr sequence | Different banks |
| TN-012 | Bank No Conflict | No bank conflict | Different banks | Parallel access |
| TN-013 | Arb Priority 0 | M00 highest priority | M00 request | Immediate grant |
| TN-014 | Arb Priority 1-3 | Other priority | Lower priority | Correct order |
| TN-015 | Bus Read | TileLink/AXI read | Bus request | Correct response |
| TN-016 | Bus Write | TileLink/AXI write | Bus request | Correct response |
| TN-017 | Direct Read | Compute Unit direct | Direct request | Correct response |
| TN-018 | Direct Write | Compute Unit direct | Direct request | Correct response |
| TN-019 | Write Byte Enable | Partial write | wstrb mask | Partial write correct |
| TN-020 | DVFS OP0 | 500 MHz operation | OP0 mode | Latency <= 2 ns |
| TN-021 | DVFS OP1 | 250 MHz operation | OP1 mode | Latency <= 4 ns |
| TN-022 | BIST Run | March C+ algorithm | BIST start | All cells tested |
| TN-023 | ECC Test Mode | Error injection | Test mode | Injected error detected |
| TN-024 | Full Address Walk | All addresses | All 128K addresses | All accessible |
| TN-025 | Bandwidth Test | Max bandwidth test | Burst requests | BW >= 8 GB/s |

### 4.2 Boundary Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TB-001 | Address Min | addr = 0x8000_0000 | Minimum address | Correct access |
| TB-002 | Address Max | addr = 0x8007_FFFC | Maximum address | Correct access |
| TB-003 | Address Odd | addr = 0x8000_0001 | Odd address | Error or align |
| TB-004 | Bank Boundary | Bank 0 to Bank 127 | All banks | All banks accessible |
| TB-005 | Syndrome All 0 | No error syndrome | syndrome=0 | No error flag |
| TB-006 | Syndrome Max | Max syndrome value | syndrome=127 | Error detected |
| TB-007 | ECC All 0s | All zero data | data=0 | Correct ECC |
| TB-008 | ECC All 1s | All ones data | data=0xFFFFFFFF | Correct ECC |
| TB-009 | Single Error Bit 0 | Error at bit 0 | Bit 0 flipped | Correct bit 0 |
| TB-010 | Single Error Bit 31 | Error at bit 31 | Bit 31 flipped | Correct bit 31 |
| TB-011 | Single Error ECC Bit | Error in ECC | ECC bit flipped | No data change |
| TB-012 | Double Error Adjacent | Adjacent bits error | Bits 0,1 flipped | Double detected |
| TB-013 | Bank Conflict Max | Max conflict | Same bank 4 requests | Conflict handling |
| TB-014 | Master All | All masters request | All masters active | Arbitration correct |
| TB-015 | Arb Priority Same | Same priority requests | Priority 1 multi | Round-robin |
| TB-016 | 64-bit Bank Boundary | Cross-bank 64-bit | Boundary address | Two banks accessed |

### 4.3 Abnormal Test Scenarios

| ID | Scenario | Description | Input | Expected Output |
|----|----------|-------------|-------|-----------------|
| TA-001 | Address Invalid | addr = 0x8008_0000 | Out of range | Error flag |
| TA-002 | Address Underflow | addr = 0x7FFF_FFFF | Below SRAM | Error flag |
| TA-003 | Master Invalid | arb_master_id = 7 | Invalid master | Error flag |
| TA-004 | Width Invalid | bus_cmd_width = 2 | Invalid width | Error flag |
| TA-005 | Multi-bit Error | 3+ bits error | Multi-bit corruption | Multi detected |
| TA-006 | ECC Disabled | ecc_enable = 0 | ECC off | No ECC check |
| TA-007 | IRQ Disabled | ecc_irq_en = 0 | IRQ off | No IRQ generated |
| TA-008 | Power Sleep Access | Access in sleep | Sleep mode | Access rejected |
| TA-009 | Power Deep Sleep | Deep sleep mode | Power gate | No access |
| TA-010 | BIST Fail | Inject BIST error | Faulty cell | BIST fail flag |
| TA-011 | Arb Busy Conflict | Access when busy | Double request | Wait/grant |
| TA-012 | Write Read Conflict | Same address | Write then read | Ordering correct |
| TA-013 | DVFS Transition | DVFS mid-access | DVFS request | Deferred or handled |
| TA-014 | Retention Enter Mid | Retention mid-access | Enter request | Deferred |
| TA-015 | ECC Counter Overflow | Counter max | Overflow count | Counter wrap |
| TA-016 | Syndrome Parity Mismatch | Invalid syndrome | Bad syndrome | Error detected |

## 5. Coverage Targets

| Category | Target | Metric |
|----------|--------|--------|
| Code Coverage | 100% | Line, branch, toggle, FSM |
| Functional Coverage | 95% | All FC points hit |
| Assertion Coverage | 100% | All AS covered |
| Corner Case Coverage | 95% | Boundary + abnormal scenarios |
| ECC Coverage | 100% | All syndrome values |

### 5.1 Code Coverage Details

| Type | Target | Description |
|------|--------|-------------|
| Line Coverage | 100% | All RTL lines executed |
| Branch Coverage | 100% | All if/case branches taken |
| Toggle Coverage | 100% | All signals 0->1 and 1->0 |
| FSM Coverage | 100% | All arbitration FSM states |
| Expression Coverage | 95% | All expression conditions |

### 5.2 Functional Coverage Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| ECC Correctness | 100% | All syndrome values tested |
| Single Error Coverage | 100% | All 39 bit positions |
| Double Error Coverage | 100% | All adjacent pairs |
| Bank Access | All 128 banks | Address walk test |
| Bandwidth | >= 8 GB/s | Burst throughput test |
| Latency | <= 2 ns | Cycle timing measurement |

## 6. Verification Tools

### 6.1 Simulation Environment

| Component | Tool | Configuration |
|-----------|------|---------------|
| RTL Simulator | Verilator 5.x | --coverage + --trace |
| Test Framework | Cocotb | Python-based test cases |
| ECC Model | Python Hamming | Reference ECC calc |
| Waveform | GTKWave | Debug visualization |

### 6.2 Coverage Collection

```bash
# Verilator coverage command
verilator --cc --exe --coverage -Wno-fatal top.v tb_top.cpp
make -C obj_dir
./obj_dir/Vtop --coverage

# Coverage analysis
verilatator_coverage --annotate coverage.log obj_dir/Vtop_coverage.dat
```

### 6.3 Formal Verification

| Property | Tool | Method |
|----------|------|--------|
| ECC Syndrome | Yosys Sby | All syndrome values proof |
| Error Detection | Sby | Single/double error proof |
| Arb Priority | Sby | Priority arbitration proof |

### 6.4 BIST Integration

```
BIST Test Sequence (March C+):
  1. Write all 0s
  2. Read all 0s, write all 1s
  3. Read all 1s, write all 0s
  4. Address decrement read
  5. Address decrement write
  6. Final read verify
```

### 6.5 Test Execution Flow

```
1. Build RTL with Verilator + coverage
2. Run Normal scenarios (TN-001 to TN-025)
3. Run Boundary scenarios (TB-001 to TB-016)
4. Run Abnormal scenarios (TA-001 to TA-016)
5. Run BIST test sequence
6. Collect coverage data
7. Analyze coverage report
8. Fill coverage holes if < target
9. Generate verification report
```

## 7. References

- REQ-MEM-002: Bandwidth >= 8 GB/s
- REQ-MEM-003: Latency <= 2 ns
- REQ-MEM-004: Capacity 512 KB
- REQ-MEM-005: ECC SECDED
- MAS: /spec_mas/M02/MAS.md
- FSM: /spec_mas/M02/FSM.md
- Datapath: /spec_mas/M02/datapath.md