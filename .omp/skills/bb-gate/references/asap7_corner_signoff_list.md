# ASAP7 PD Signoff Corners

## Signoff Corner List

| Corner | Type | Temp | Voltage | Description |
|--------|------|------|---------|-------------|
| ss_0p72v_100c | Worst | 100C | 0.72V | Slow-slow, high temp, low voltage |
| ff_0p88v_m40c | Best | -40C | 0.88V | Fast-fast, low temp, high voltage |
| tt_0p77v_25c | Typical | 25C | 0.77V | Typical-typical, nominal |

## Signoff Requirements
- Setup: must meet timing at ss_0p72v_100c
- Hold: must meet timing at ff_0p88v_m40c
- All corners WNS >= 0 for signoff
