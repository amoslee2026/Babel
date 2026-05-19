# Design for Testability

## DFT Strategy

| Method | Coverage | Implementation | REQ |
|--------|----------|----------------|-----|
| Scan Chain | >= 95% | Full scan insertion | ATPG |
| Memory BIST | 100% | MBIST controller | All SRAM/DRAM |
| JTAG | Debug | IEEE 1149.1 TAP | REQ-IO-001 |

## Scan Architecture

| Parameter | Value | Notes |
|-----------|-------|-------|
| Coverage Target | >= 95% | REQ-DFT-001 |
| Scan Chains | 4 | Balanced length |
| Chain Length | ~10k cells | Per chain |
| Scan Cells | Full scan | All registers |

## Memory BIST (MBIST)

| Memory | Size | BIST Type | Coverage |
|--------|------|-----------|----------|
| SRAM (M02) | 512 KB | March C- | 100% |
| DRAM (M03) | 2 GB | External BIST | 100% |

**MBIST Algorithm**：
- March C-：检测 stuck-at、transition、address faults
- 透明测试模式：支持运行时测试
- ECC 验证：测试 SECDED 功能 REQ-MEM-005

## JTAG TAP Controller

| Register | Width | Function |
|----------|-------|----------|
| IR | 4 | Instruction Register |
| DR_BYPASS | 1 | Bypass mode |
| DR_IDCODE | 32 | Device ID |
| DR_SCAN | N | Scan chain access |
| DR_DEBUG | 32 | Debug access |

**JTAG Instructions**：

| Instruction | Code | Function |
|-------------|------|----------|
| BYPASS | 0x0 | Bypass mode |
| IDCODE | 0x1 | Read device ID |
| SCAN_IN | 0x2 | Scan chain input |
| SCAN_OUT | 0x3 | Scan chain output |
| DEBUG | 0x4 | Debug mode |

## ATPG Requirements

| Fault Model | Coverage Target |
|-------------|-----------------|
| Stuck-at | >= 95% |
| Transition | >= 90% |
| Path delay | >= 80% |
| Bridging | >= 80% |

## Test Modes

| Mode | Description | Access |
|------|-------------|--------|
| Functional | 正常运行 | External |
| Scan | ATPG 测试 | JTAG |
| MBIST | 内存测试 | JTAG + Internal |
| Debug | 调试模式 | JTAG |

## Test Access Mechanism (TAM)

| Level | Method | Description |
|-------|--------|-------------|
| Level 0 | JTAG | 外部访问 |
| Level 1 | Scan Chain | 逻辑测试 |
| Level 2 | MBIST | 内存测试 |
| Level 3 | Debug | 内部调试 |

## DFT Integration Points

| Module | Scan | MBIST | Debug |
|--------|------|-------|-------|
| M00 (Systolic Array) | Yes | - | Yes |
| M01 (Dataflow Controller) | Yes | - | Yes |
| M02 (SRAM) | - | Yes | Yes |
| M03 (DRAM Controller) | Yes | External | Yes |
| M04 (System Bus) | Yes | - | Yes |
| M05-M07 (Power/Clock/Reset) | Yes | - | Yes |
| M08-M12 (Operators) | Yes | - | Yes |
| M13-M14 (ISA/Security) | Yes | - | Yes |

## Production Test Flow

| Step | Test | Duration |
|------|------|----------|
| 1 | Contact check | 10 ms |
| 2 | IDCODE read | 5 ms |
| 3 | Scan ATPG | 200 ms |
| 4 | MBIST SRAM | 50 ms |
| 5 | MBIST DRAM (partial) | 100 ms |
| 6 | Functional quick test | 50 ms |
| **Total** | - | ~415 ms |
