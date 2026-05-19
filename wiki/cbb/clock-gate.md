---
name: clock-gate
content_hash: "PLACEHOLDER_HASH"
version: 0.1.0
---

# Clock Gate (ICG, Integrated Clock Gating Cell)

## Overview

Latch-based clock gating cell. Enable is sampled on the **negative edge** of the clock to prevent glitches on the gated clock.

## Interface

| name | direction | width | description |
|------|-----------|-------|-------------|
| clk_in | input | 1 | Source clock |
| en | input | 1 | Enable (sampled on negedge clk_in) |
| clk_gated | output | 1 | Gated output clock |

Optional:

| name | direction | width | description |
|------|-----------|-------|-------------|
| test_en | input | 1 | DFT bypass (forces clk_gated = clk_in during scan) |

## Behavior

```
always_latch @* if (~clk_in) en_l <= en | test_en;
assign clk_gated = clk_in & en_l;
```

ASAP7 maps this to standard ICG cell `ICGx1_ASAP7` — do not hand-instantiate the latch+AND; let synthesis infer or use the explicit cell instance.

## When to Use

- Save dynamic power on modules with predictable idle windows
- DFT requires `test_en` to bypass during scan shift

## Common Pitfalls

- Combinational clock gating (en directly ANDed with clk) causes glitches — always use the latch
- DFT skip: forgetting `test_en` breaks scan coverage; declare in MAS `dft_plan_seed.md`

## Reuse Tag

Set `mas.modules[i].reuse = "clock-gate"`.
