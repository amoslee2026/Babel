---
type: requirements_registry
version: 1.0.0
created: 2026-05-30
updated: 2026-05-30
status: superseded
superseded_by: traceability/requirements_matrix.csv
spec: harness_spec/arch_spec/spec-code-traceability.md v2.0.0
---

# Requirements Registry

> **⚠️ Superseded**: 本文件已被 CSV-based traceability matrix 替代。
> 机器可读源: `traceability/requirements_matrix.csv`
> 规范: `harness_spec/arch_spec/spec-code-traceability.md` v2.0.0
> 本文件保留为人类可读参考，REQ_ID 初始分配示例。

> REQ ID 双向链接的权威索引。MAS 为权威源，此注册表为索引和状态追踪。
> 编码规范见 `harness_spec/arch_spec/spec-code-traceability.md`

## M00 — SystolicArray

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M00-R001 | SA_CTRL: start, soft_rst, precision, dataflow_mode | [regmap.md §2.1](M00_SystolicArray/regmap.md) | rtl/M00/src/M00_SystolicArray_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M00-R002 | SA_STATUS: busy, done, stall, fsm_state | [regmap.md §2.2](M00_SystolicArray/regmap.md) | rtl/M00/src/M00_SystolicArray_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M00-R003 | SA_DIM_CFG: dim_m, dim_n, dim_k | [regmap.md §2.3](M00_SystolicArray/regmap.md) | rtl/M00/src/M00_SystolicArray_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M00-R004 | SA_PERF_CNT: 计算周期计数器 | [regmap.md §2.4](M00_SystolicArray/regmap.md) | rtl/M00/src/M00_SystolicArray_regmap_assertions.sv | ⬜ PLANNED |

## M01 — DataflowController

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M01-F001 | IF - Instruction Fetch | [datapath.md §2](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-F002 | ID - Instruction Decode | [datapath.md §2](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-F003 | IS - Issue/Dispatch | [datapath.md §2](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-F004 | EX - Execute (M00 delegation) | [datapath.md §2](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-F005 | WB - Writeback | [datapath.md §2](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-P001 | M00 Handshake Protocol | [datapath.md §4](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-C001 | 500MHz Timing Closure | [datapath.md §4](M01_DataflowController/datapath.md) | — | ⬜ PLANNED |
| REQ-M01-I001 | Scan Chain SC0 (FSM) | [DFT.md §1](M01_DataflowController/DFT.md) | — | ⬜ PLANNED |
| REQ-M01-I002 | Scan Chain SC1 (Thread CTX) | [DFT.md §1](M01_DataflowController/DFT.md) | — | ⬜ PLANNED |
| REQ-M01-I003 | Scan Chain SC2 (OP_QUEUE) | [DFT.md §1](M01_DataflowController/DFT.md) | — | ⬜ PLANNED |
| REQ-M01-I004 | Scan Chain SC3 (PERF+IRQ) | [DFT.md §1](M01_DataflowController/DFT.md) | — | ⬜ PLANNED |
| REQ-M01-R001 | CTRL: 全局使能、软复位、调度模式 | [regmap.md §2.1](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R002 | STATUS: IDLE/BUSY、当前 TID、流水线阶段 | [regmap.md §2.2](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R003 | THREAD_CFG0: 线程 0 精度、算子掩码 | [regmap.md §2.3](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R004 | THREAD_CFG1: 线程 1 配置 | [regmap.md §2.4](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R005 | OP_QUEUE: 队列基地址、深度 | [regmap.md §2.5](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R006 | PERF_CNT0: 线程 0 完成算子计数 | [regmap.md §2.6](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R007 | PERF_CNT1: 线程 1 完成算子计数 | [regmap.md §2.7](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R008 | PERF_UTIL: 流水线利用率 | [regmap.md §2.8](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R009 | IRQ_MASK: 中断使能掩码 | [regmap.md §2.9](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M01-R010 | IRQ_STATUS: 中断状态 (W1C) | [regmap.md §2.10](M01_DataflowController/regmap.md) | rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv | ⬜ PLANNED |

## M02 — SRAM

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M02-R001 | SRAM_CTRL: 使能、ECC、Bank 模式 | [regmap.md §2.1](M02_SRAM/regmap.md) | rtl/M02/src/M02_SRAM_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M02-R002 | ECC_STATUS: SEC/DED 计数 | [regmap.md §2.2](M02_SRAM/regmap.md) | rtl/M02/src/M02_SRAM_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M02-R003 | ECC_ADDR: 最近 ECC 错误地址 | [regmap.md §2.3](M02_SRAM/regmap.md) | rtl/M02/src/M02_SRAM_regmap_assertions.sv | ⬜ PLANNED |

## M03 — DRAMController

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M03-R001 | DRAM_CTRL: 使能、自刷新、ECC | [regmap.md §2.1](M03_DRAMController/regmap.md) | rtl/M03/src/M03_DRAMController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M03-R002 | TIMING_CFG: tRCD、tCL、tRP、tRAS | [regmap.md §2.2](M03_DRAMController/regmap.md) | rtl/M03/src/M03_DRAMController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M03-R003 | ECC_STATUS: SBE/DBE 标志 (W1C) | [regmap.md §2.3](M03_DRAMController/regmap.md) | rtl/M03/src/M03_DRAMController_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M03-R004 | PERF_CNT: 内存访问周期计数 | [regmap.md §2.4](M03_DRAMController/regmap.md) | rtl/M03/src/M03_DRAMController_regmap_assertions.sv | ⬜ PLANNED |

## M04 — SystemBus

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M04-R001 | BUS_CTRL: 总线使能、仲裁模式 | [regmap.md §2.1](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M04-R002 | ARB_CFG: 仲裁优先级配置 | [regmap.md §2.2](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M04-R003 | BUS_STATUS: 当前 master、busy、deadlock | [regmap.md §2.3](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M04-R004 | BW_COUNTER_M00: M00 带宽计数器 | [regmap.md §2.4](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M04-R005 | BW_COUNTER_M01: M01 带宽计数器 | [regmap.md §2.5](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M04-R006 | BW_COUNTER_M02: M02 带宽计数器 | [regmap.md §2.6](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M04-R007 | BW_COUNTER_M03: M03 带宽计数器 | [regmap.md §2.7](M04_SystemBus/regmap.md) | rtl/M04/src/M04_SystemBus_regmap_assertions.sv | ⬜ PLANNED |

## M05 — PowerManager

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M05-R001 | PWR_CTRL: 电源请求、睡眠使能、唤醒源 | [regmap.md §2.1](M05_PowerManager/regmap.md) | rtl/M05/src/M05_PowerManager_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M05-R002 | DVFS_CFG: 电压/频率稳定计数、DVFS 模式 | [regmap.md §2.2](M05_PowerManager/regmap.md) | rtl/M05/src/M05_PowerManager_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M05-R003 | PWR_STATUS: FSM 状态、DVFS 工作点、PMIC PG | [regmap.md §2.3](M05_PowerManager/regmap.md) | rtl/M05/src/M05_PowerManager_regmap_assertions.sv | ⬜ PLANNED |

## M06 — ClockManager

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M06-R001 | CLK_CTRL: PLL 使能、时钟门控 | [regmap.md §2.1](M06_ClockManager/regmap.md) | rtl/M06/src/M06_ClockManager_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M06-R002 | PLL_CFG: 倍频系数、环路带宽 | [regmap.md §2.2](M06_ClockManager/regmap.md) | rtl/M06/src/M06_ClockManager_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M06-R003 | CLK_STATUS: PLL 锁定、时钟稳定 | [regmap.md §2.3](M06_ClockManager/regmap.md) | rtl/M06/src/M06_ClockManager_regmap_assertions.sv | ⬜ PLANNED |

## M07 — ResetManager

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| REQ-M07-R001 | RST_CTRL: 软件复位、复位范围、WDT 使能 | [regmap.md §2.1](M07_ResetManager/regmap.md) | rtl/M07/src/M07_ResetManager_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M07-R002 | RST_STATUS: 复位源标志、当前复位状态 | [regmap.md §2.2](M07_ResetManager/regmap.md) | rtl/M07/src/M07_ResetManager_regmap_assertions.sv | ⬜ PLANNED |
| REQ-M07-R003 | WDT_CFG: 超时周期、喂狗、锁定 | [regmap.md §2.3](M07_ResetManager/regmap.md) | rtl/M07/src/M07_ResetManager_regmap_assertions.sv | ⬜ PLANNED |

## M99 — Top (NPU_top)

| REQ ID | Description | MAS Source | RTL Location | Status |
|--------|-------------|------------|--------------|--------|
| | | | | |
