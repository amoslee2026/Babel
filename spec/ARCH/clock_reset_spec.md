# Clock & Reset Architecture

## Clock Sources

| Source | Frequency | Purpose | REQ |
|--------|-----------|---------|-----|
| EXT_CLK | 50 MHz | 外部晶振输入 | - |
| PLL_MAIN | 250-500 MHz | 主系统时钟（DVFS 可调） | REQ-PWR-003 |
| PLL_AON | 1 MHz | Always-on 域时钟 | - |

## DVFS Operating Points

| OP | Frequency | Voltage | Power Estimate | Use Case |
|----|-----------|---------|----------------|----------|
| OP0 (High) | 500 MHz | 0.9 V | ~1.8 W | Active inference REQ-PERF-001 |
| OP1 (Low) | 250 MHz | 0.7 V | ~0.6 W | Idle/light load |
| OP2 (Sleep) | 1 MHz (AON) | 0.6 V (AON) | ~0.1 W | Deep sleep REQ-PWR-002 |

## Clock Domains

| Domain | Frequency Range | Modules | DVFS | Gating |
|--------|-----------------|---------|------|--------|
| CLK_SYS | 250-500 MHz | M00-M04, M08-M14 | Yes | Software |
| CLK_AON | 1 MHz | M05-M07 | No | Never |
| CLK_IO | 50 MHz | M15-M16 | No | Never |

## Clock Gating Strategy

| Module | Gating Type | Trigger | Latency |
|--------|-------------|---------|---------|
| M00-M04 | Software CG | Power Manager M05 | < 10 cycles |
| M08-M14 | Software CG | Power Manager M05 | < 5 cycles |
| M05-M07 | Never gated | - | - |

## CDC Strategy

| From | To | Method | Verification |
|------|-----|--------|--------------|
| CLK_SYS -> CLK_AON | 2-stage synchronizer | STA CDC check |
| CLK_AON -> CLK_SYS | Handshake protocol | Formal verification |
| CLK_SYS -> CLK_IO | Async FIFO | FIFO depth check |

## Reset Sources

| Source | Type | Scope | Assertion | De-assertion |
|--------|------|-------|-----------|--------------|
| POR | Async | Global | Power-on | After PLL lock |
| SW_RESET | Sync | Main | Software | Immediate |
| WDT_RESET | Async | Main | Watchdog timeout | After WDT clear |

## Reset Sequence

| Step | Action | Duration |
|------|--------|----------|
| 1 | POR asserted | 0 |
| 2 | PLL configuration | 100 us |
| 3 | PLL lock wait | 50 us |
| 4 | CLK_AON stable | - |
| 5 | PD_MAIN power-on | 10 us |
| 6 | CLK_SYS stable | - |
| 7 | SW_RESET de-assert | - |
| 8 | Secure Boot start (M14) | - |

## Reset Coverage

| Module | Reset Value | Reset Type |
|--------|-------------|------------|
| All registers | Defined (X to 0) | Async/Sync per domain |
| SRAM (M02) | 0x00 | Power-on reset |
| DRAM (M03) | N/A (external) | - |

## Verification Requirements

| Check | Method | Coverage |
|-------|--------|----------|
| CDC analysis | STA tool | 100% cross-domain paths |
| Handshake protocol | Formal verification | Protocol correctness |
| Reset sequence | Simulation | Timing checks |
