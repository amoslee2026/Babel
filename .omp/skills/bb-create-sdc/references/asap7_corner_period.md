# ASAP7 Corner-Specific Clock Periods

## Process Corners

| Corner ID      | Description              | Vdd   | Temp  | Speed Factor |
|---------------|--------------------------|-------|-------|--------------|
| tt_0p77v_25c  | Typical-Typical          | 0.77V | 25C   | 1.0x         |
| ss_0p70v_100c | Slow-Slow                | 0.70V | 100C  | 0.7x         |
| ff_0p84v_-40c | Fast-Fast                | 0.84V | -40C  | 1.3x         |
| sf_0p77v_25c  | Slow-NMOS / Fast-PMOS   | 0.77V | 25C   | 0.85x        |
| fs_0p77v_25c  | Fast-NMOS / Slow-PMOS   | 0.77V | 25C   | 0.85x        |

## Recommended Margins by Corner

| Corner          | Setup Margin | Hold Margin | Clock Uncertainty |
|----------------|-------------|-------------|-------------------|
| tt_0p77v_25c   | 10%         | 5%          | 0.05 ns           |
| ss_0p70v_100c  | 20%         | 10%         | 0.10 ns           |
| ff_0p84v_-40c  | 5%          | 15%         | 0.03 ns           |

## Period Calculation
```
target_period = 1000 / target_freq_mhz    # ns
ss_period = target_period / 0.7           # slow corner needs longer period
ff_period = target_period / 1.3           # fast corner can use shorter period
```

## Usage Notes
- Synthesis typically uses `ss_0p70v_100c` for setup and `ff_0p84v_-40c` for hold
- For first-run synthesis, use typical corner with relaxed margins
- Multi-corner multi-mode (MCMM) analysis requires separate SDC per corner
