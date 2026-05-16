---
type: module_tree
status: complete
generated: 2026-05-12T09:15:00Z
---

# TinyStories NPU 模块树

## 模块层次

```
NPU (Top)
├── M00_SystolicArray        [compute]      Systolic Array 矩阵乘法加速
├── M01_DataflowController   [compute]      Dataflow 调度控制器
├── M02_SRAM                 [storage]      512 KB Scratchpad SRAM
├── M03_DRAMController       [storage]      2 GB DRAM 控制器 @D2D
├── M04_SystemBus            [interconnect] AXI 系统总线
├── M05_PowerManager         [io]           电源管理 DVFS
├── M06_ClockManager         [io]           时钟生成与分配
└── M07_ResetManager         [io]           复位控制
```

## 模块索引

| Module ID | Name | Type | Clock | Power Domain | 依赖 |
|-----------|------|------|-------|--------------|------|
| M00 | Systolic Array | compute | CLK_SYS 500MHz | PD_MAIN | M01, M02, M04 |
| M01 | Dataflow Controller | compute | CLK_SYS 500MHz | PD_MAIN | M04 |
| M02 | SRAM Scratchpad | storage | CLK_SYS 500MHz | PD_MAIN | M04 |
| M03 | DRAM Controller | storage | CLK_SYS 500MHz | PD_MAIN | M04 @D2D |
| M04 | System Bus | interconnect | CLK_SYS 500MHz | PD_MAIN | M06 |
| M05 | Power Manager | io | CLK_AON 32KHz | PD_AON | M06 |
| M06 | Clock Manager | io | CLK_AON 32KHz | PD_AON | - |
| M07 | Reset Manager | io | CLK_AON 32KHz | PD_AON | M06 |

## 实现顺序（叶子优先）

1. **第一批（无依赖）**：M06_ClockManager, M07_ResetManager
2. **第二批**：M05_PowerManager, M04_SystemBus
3. **第三批**：M02_SRAM, M03_DRAMController
4. **第四批**：M01_DataflowController
5. **第五批（顶层）**：M00_SystolicArray
