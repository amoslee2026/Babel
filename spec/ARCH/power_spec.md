# Power Architecture

## Power Domains

| Domain | Voltage Range | Modules | Gating | REQ |
|--------|---------------|---------|--------|-----|
| PD_AON | 0.6-0.9 V | M05-M07 | Never | Always-on |
| PD_MAIN | 0.7-0.9 V | M00-M04, M08-M14 | Software | REQ-PWR-003 |
| PD_IO | 1.8 V | M15-M16 | Never | IO interface |

## Power Estimate

| Domain | Power @ OP0 | Power @ OP1 | Power @ OP2 | Notes |
|--------|-------------|-------------|-------------|-------|
| PD_MAIN | 1.7 W | 0.55 W | 0 W (gated) | 500 MHz 满载 |
| PD_AON | 7 mW | 7 mW | 7 mW | Always on |
| PD_IO | 15 mW | 10 mW | 0.5 mW | JTAG + ISA IF |
| DRAM | 80 mW | 40 mW | 10 mW | 3D Stacked |
| **Total** | **1.79 W** | **0.61 W** | **0.09 W** | < 1.8 W 目标 REQ-PWR-001 |

## DVFS Operating Points

| OP | VDD_MAIN | CLK_SYS | Power | Use Case |
|----|----------|----------|-------|----------|
| OP0 | 0.9 V | 500 MHz | 1.79 W | Active inference REQ-PERF-001 |
| OP1 | 0.7 V | 250 MHz | 0.61 W | Light load |
| OP2 | 0.6 V (AON) | 1 MHz (AON) | 0.09 W | Deep sleep REQ-PWR-002 |

## Power Modes

| Mode | Active Domains | DVFS OP | Wakeup Time | REQ |
|------|----------------|---------|-------------|-----|
| Active | All | OP0 | - | 正常运行 |
| Sleep | AON, IO | OP1 | < 1 ms | 低功耗待机 |
| Deep Sleep | AON only | OP2 | < 10 ms | REQ-PWR-002 |

## Low Power Techniques

| Technique | Target | Implementation | Savings |
|-----------|---------|----------------|---------|
| Clock Gating | All logic | Software-controlled CG cells | 30% dynamic |
| Power Gating | PD_MAIN | Header/footer switches | 95% PD_MAIN leakage |
| DVFS | CLK_SYS | PLL + Voltage regulator | 65% @ OP1 |

## Temperature Range

| Parameter | Value | REQ |
|-----------|-------|-----|
| Operating Tj | 0°C 至 85°C | REQ-THERM-001 |
| Storage Tj | -40°C 至 125°C | - |
| Cooling | 自然对流（无散热片） | REQ-THERM-002 |

## Thermal Design

| Scenario | Tj Estimate | Ambient | Power |
|----------|-------------|---------|-------|
| Active @ 85°C ambient | 85°C (limit) | 85°C | 1.79 W |
| Active @ 25°C ambient | 45°C | 25°C | 1.79 W |
| Sleep @ 85°C ambient | 85°C | 85°C | 0.09 W |

## Reliability Targets

| Metric | Target | Test Condition | REQ |
|--------|--------|----------------|-----|
| MTTF | >= 100,000 h | 85°C continuous | REQ-REL-001 |
| SER (Soft Error Rate) | <= 1000 FIT | With ECC enabled | REQ-REL-002 |
| ESD HBM | >= 2 kV | All IO pins | REQ-REL-003 |
| ESD CDM | >= 500 V | All pins | REQ-REL-003 |

## SER Mitigation

| Protection | Coverage | Method |
|------------|----------|--------|
| DRAM ECC | SECDED | Hardware auto-correct REQ-MEM-005 |
| SRAM ECC | SECDED | Hardware auto-correct REQ-MEM-005 |
| Logic SER | - | Design margin |

## Power Management Module (M05)

| Function | Description |
|----------|-------------|
| DVFS Controller | 频率/电压切换 REQ-PWR-003 |
| Power Mode FSM | Active/Sleep/Deep Sleep 状态机 |
| Wakeup Controller | 外部唤醒信号处理 |
| Power Estimator | 实时功耗估算 |

## Voltage Regulator Requirements

| Regulator | Range | Step | Response Time |
|-----------|-------|------|---------------|
| VDD_MAIN | 0.7-0.9 V | 50 mV | < 100 us |
| VDD_AON | 0.6-0.9 V | Fixed | - |
| VDD_IO | 1.8 V | Fixed | - |
