# TinyStories NPU Block Diagram

## System Overview

```mermaid
graph TB
    subgraph PD_MAIN["Power Domain: Main"]
        M00[M00: Systolic Array]
        M01[M01: Dataflow Controller]
        M02[M02: SRAM 512KB]
        M03[M03: DRAM Controller]
        M04[M04: System Bus]
    end
    
    subgraph PD_AON["Power Domain: Always-On"]
        M05[M05: Power Manager]
        M06[M06: Clock Manager]
        M07[M07: Reset Manager]
    end
    
    DRAM[DRAM 2GB] --> M03
    M03 --> M04
    M00 --> M04
    M01 --> M00
    M02 --> M04
    M06 --> PD_MAIN
    M05 --> PD_MAIN
```

## Module Index

| Module ID | Name | Clock Domain | Power Domain |
|-----------|------|--------------|--------------|
| M00 | Systolic Array | CLK_SYS | PD_MAIN |
| M01 | Dataflow Controller | CLK_SYS | PD_MAIN |
| M02 | SRAM Scratchpad | CLK_SYS | PD_MAIN |
| M03 | DRAM Controller | CLK_SYS | PD_MAIN |
| M04 | System Bus | CLK_SYS | PD_MAIN |
| M05 | Power Manager | CLK_AON | PD_AON |
| M06 | Clock Manager | CLK_AON | PD_AON |
| M07 | Reset Manager | CLK_AON | PD_AON |
