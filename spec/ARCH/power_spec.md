# Power Architecture

## Power Domains

| Domain | Voltage | Modules | Gating |
|--------|---------|---------|--------|
| PD_AON | 0.9 V | M05-M07 | Never |
| PD_MAIN | 0.9 V | M00-M04 | Software |
| PD_IO | 1.8 V | JTAG, ISA | Never |

## Power Estimate

| Domain | Total | Notes |
|--------|-------|-------|
| PD_MAIN | 1.7 W | 500 MHz 满载 |
| PD_AON | 7 mW | Always on |
| Total | 1.722 W | < 1.8 W 目标 |

## Power Modes

| Mode | Active Domains |
|------|----------------|
| Active | All |
| Sleep | AON, IO |
| Deep Sleep | AON only |
