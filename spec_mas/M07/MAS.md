---
module: M07
type: MAS
status: complete
parent: null
module_type: control
generated: 2026-05-17T14:56:00+08:00
---

# M07: Reset Manager

## 1. Overview

Reset Manager (M07) 负责整个系统的复位序列控制和复位信号分发。作为 Always-On 域的核心控制模块，确保系统从上电到正常工作的完整复位流程。

### 1.1 Key Features

- Reset Source Management (POR/SW_RESET/WDT_RESET)
- 8-Step Reset Sequence Control
- Reset Distribution to All Modules
- Async/Sync Reset Type Selection per Domain

### 1.2 Module Attributes

| Attribute | Value |
|-----------|-------|
| Module ID | M07 |
| Name | Reset Manager |
| Clock Domain | CLK_AON (1 MHz) |
| Power Domain | PD_AON (Always-on, 0.6-0.9V) |
| Type | control |

## 2. Interface

### 2.1 Signal List

| Signal | Direction | Width | Clock Domain | Description |
|--------|-----------|-------|--------------|-------------|
| por_in | Input | 1 | Async | Power-on Reset input from external pin |
| sw_reset_req | Input | 1 | CLK_SYS | Software reset request from M13/M14 |
| wdt_reset_in | Input | 1 | CLK_AON | Watchdog timer reset from M05 |
| pll_locked | Input | 1 | CLK_AON | PLL lock status from M06 |
| clk_aon_stable | Input | 1 | CLK_AON | CLK_AON stability indicator from M06 |
| clk_sys_stable | Input | 1 | CLK_SYS | CLK_SYS stability indicator from M06 |
| pd_main_ready | Input | 1 | CLK_AON | PD_MAIN power-on ready from M05 |
| reset_main_out | Output | 1 | Async | Reset signal to PD_MAIN modules (M00-M04, M08-M14) |
| reset_aon_out | Output | 1 | Async | Reset signal to PD_AON modules (M05, M06) |
| reset_io_out | Output | 1 | Async | Reset signal to PD_IO modules (M15-M16) |
| reset_status | Output | 3 | CLK_AON | Reset status code (3-bit) |
| boot_start | Output | 1 | CLK_SYS | Secure Boot start trigger to M14 |
| sequence_done | Output | 1 | CLK_AON | Reset sequence completion flag |

### 2.2 Reset Status Code

| Code | Meaning |
|------|---------|
| 0x0 | Idle / Normal Operation |
| 0x1 | POR Sequence Active |
| 0x2 | SW_RESET Active |
| 0x3 | WDT_RESET Active |
| 0x4 | PLL Locking |
| 0x5 | Power-On In Progress |
| 0x6 | Clock Stabilizing |
| 0x7 | Boot Starting |

## 3. Functional Description

### 3.1 Reset Sources

| Source | Type | Scope | Assertion | De-assertion |
|--------|------|-------|-----------|--------------|
| POR | Async | Global (All Domains) | Power-on | After PLL lock + sequence complete |
| SW_RESET | Sync | PD_MAIN only | Software request | Immediate after 1 cycle |
| WDT_RESET | Async | PD_MAIN only | Watchdog timeout | After WDT clear + sequence |

### 3.2 Reset Sequence (8 Steps)

| Step | Action | Duration | Dependencies |
|------|--------|----------|--------------|
| 1 | POR asserted | 0 us | External power-on |
| 2 | PLL configuration | 100 us | M06 PLL config registers |
| 3 | PLL lock wait | 50 us | pll_locked signal |
| 4 | CLK_AON stable | - | clk_aon_stable from M06 |
| 5 | PD_MAIN power-on | 10 us | pd_main_ready from M05 |
| 6 | CLK_SYS stable | - | clk_sys_stable from M06 |
| 7 | SW_RESET de-assert | - | reset_main_out release |
| 8 | Secure Boot start | - | boot_start to M14 |

### 3.3 Reset Sequence Timing Diagram

```
        ___     ___         ___________     ___     ___     ___
por_in  |   |___|   |_______|           |___|   |___|   |___|   |___
        | Power-on     PLL config       | Sequence Complete

pll_locked       _____________________________/---------------
                 (Locked after 50us wait)

clk_aon_stable   _____________/-------------------------------
                 (Stable after PLL lock)

pd_main_ready    _______________________/---------------------
                 (Power-on ready after 10us)

clk_sys_stable   _______________________________/-------------
                 (Stable after PD_MAIN ready)

reset_main_out   ______________|               |_____________
                 (Asserted)     (De-asserted at Step 7)

boot_start       ________________________________|____________
                 (Trigger at Step 8)
```

### 3.4 Reset Distribution Logic

```
Reset Distribution Matrix:

| Target Domain | POR | SW_RESET | WDT_RESET | Type |
|---------------|-----|----------|-----------|------|
| PD_AON (M05-M07) | Yes | No | No | Async |
| PD_MAIN (M00-M04, M08-M14) | Yes | Yes | Yes | Sync |
| PD_IO (M15-M16) | Yes | No | No | Async |

Distribution Priority: POR > WDT_RESET > SW_RESET
```

## 4. Reset Coverage

### 4.1 Register Reset Values

| Module Category | Reset Value | Reset Type | Notes |
|-----------------|-------------|------------|-------|
| Control Registers | 0x0 | Async | All X to 0 on POR |
| Status Registers | 0x0 | Async | Clear all status flags |
| Config Registers | Default | Sync | Load from boot config |
| Counter Registers | 0x0 | Async | Clear all counters |

### 4.2 Memory Reset Values

| Memory Type | Reset Value | Reset Method | Notes |
|-------------|-------------|--------------|-------|
| SRAM (M02) | 0x00 | Power-on reset | All cells cleared |
| DRAM (M03) | N/A | External | DRAM controller reset only |
| Registers (All) | Defined | Async/Sync | X to 0 per domain |

### 4.3 Special Reset Handling

| Module | Reset Behavior | Special Handling |
|--------|----------------|------------------|
| M14 Secure Boot | Full reset | Requires signature re-verify |
| M05 Power Manager | State preserved | Always-on, POR only |
| M06 Clock Manager | PLL re-config | Requires PLL lock sequence |
| M02 SRAM | ECC clear | Initialize ECC syndrome |

## 5. Timing

### 5.1 Reset Timing Parameters

| Parameter | Value | Unit | Description |
|-----------|-------|------|-------------|
| T_por_min | 0 | us | Minimum POR assertion time |
| T_pll_config | 100 | us | PLL configuration duration |
| T_pll_lock | 50 | us | PLL lock wait time |
| T_pd_poweron | 10 | us | PD_MAIN power-on time |
| T_reset_release | 1 | cycle | Reset de-assertion delay |
| T_seq_total | 160+ | us | Total sequence duration |

### 5.2 Reset Assertion/De-assertion Timing

| Event | Assertion | De-assertion | Latency |
|-------|-----------|--------------|---------|
| POR | Async (immediate) | After sequence complete | 160+ us |
| SW_RESET | Sync (1 cycle) | Sync (1 cycle) | 2 cycles |
| WDT_RESET | Async (immediate) | After WDT clear + wait | Variable |

### 5.3 Clock Domain Crossing Timing

| Crossing | Method | Synchronizer Depth | Timing Constraint |
|----------|--------|-------------------|-------------------|
| CLK_SYS -> CLK_AON | 2-stage sync | 2 FFs | MTBF >= 10 years |
| CLK_AON -> CLK_SYS | Handshake | Protocol based | No timing violation |

## 6. FSM Overview

### 6.1 Reset Manager FSM States

| State | Code | Description | Next State |
|-------|------|-------------|------------|
| IDLE | 0x0 | Normal operation | POR_ASSERTED on por_in |
| POR_ASSERTED | 0x1 | POR active | PLL_CONFIG |
| PLL_CONFIG | 0x4 | PLL configuration in progress | PLL_WAIT |
| PLL_WAIT | 0x4 | Waiting for PLL lock | CLK_AON_STABLE |
| CLK_AON_STABLE | 0x6 | CLK_AON stabilizing | PD_POWERON |
| PD_POWERON | 0x5 | PD_MAIN power-on | CLK_SYS_STABLE |
| CLK_SYS_STABLE | 0x6 | CLK_SYS stabilizing | RESET_RELEASE |
| RESET_RELEASE | 0x1 | Reset de-assertion | BOOT_START |
| BOOT_START | 0x7 | Secure Boot trigger | IDLE |

### 6.2 FSM Transition Conditions

| From | To | Condition |
|------|----|-----------|
| IDLE | POR_ASSERTED | por_in == 1 |
| PLL_CONFIG | PLL_WAIT | T_pll_config elapsed |
| PLL_WAIT | CLK_AON_STABLE | pll_locked == 1 |
| CLK_AON_STABLE | PD_POWERON | clk_aon_stable == 1 |
| PD_POWERON | CLK_SYS_STABLE | pd_main_ready == 1 |
| CLK_SYS_STABLE | RESET_RELEASE | clk_sys_stable == 1 |
| RESET_RELEASE | BOOT_START | reset_main_out == 0 |
| BOOT_START | IDLE | boot_start == 1, sequence_done |

## 7. Design Considerations

### 7.1 Reset Glitch Protection

- All reset inputs have glitch filters
- Minimum pulse width: 2 CLK_AON cycles
- Deglitch circuit for async resets

### 7.2 Reset Priority

```
Priority Order (Highest to Lowest):
1. POR (Global, overrides all)
2. WDT_RESET (PD_MAIN, safety critical)
3. SW_RESET (PD_MAIN, software controlled)
```

### 7.3 Reset Verification Requirements

| Check | Method | Coverage Target |
|-------|--------|-----------------|
| Sequence timing | Simulation | 100% paths |
| CDC analysis | STA tool | 100% cross-domain |
| FSM transitions | Formal | All states reachable |
| Reset coverage | Simulation | All registers initialized |

## 8. Dependencies

### 8.1 Module Dependencies

| Module | Dependency Type | Signal |
|--------|-----------------|--------|
| M06 Clock Manager | Input | pll_locked, clk_aon_stable, clk_sys_stable |
| M05 Power Manager | Input | pd_main_ready, wdt_reset_in |
| M14 Secure Boot | Output | boot_start |
| M00-M04, M08-M14 | Output | reset_main_out |
| M15-M16 | Output | reset_io_out |

### 8.2 Clock Dependencies

| Clock | Usage | Notes |
|-------|-------|-------|
| CLK_AON | Main FSM clock | Always-on, never gated |
| CLK_SYS | Sync reset logic | Sampled via CDC |

## 9. Verification Checklist

- [ ] Reset sequence timing verified
- [ ] All reset sources tested (POR, SW_RESET, WDT_RESET)
- [ ] CDC paths analyzed
- [ ] FSM state coverage >= 100%
- [ ] Register reset values verified
- [ ] Glitch protection tested
- [ ] Boot sequence integration tested