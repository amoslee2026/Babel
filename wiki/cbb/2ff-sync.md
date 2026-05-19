---
name: 2ff-sync
content_hash: "PLACEHOLDER_HASH"
version: 0.1.0
---

# 2FF Synchronizer (Two Flip-Flop Synchronizer)

## Overview

The minimal cross-clock-domain synchronizer for single-bit signals. Two cascaded flip-flops in the destination clock domain reduce metastability MTBF to acceptable levels for moderate frequencies.

## Interface

| name | direction | width | description |
|------|-----------|-------|-------------|
| clk_dst | input | 1 | Destination clock |
| rst_n | input | 1 | Async active-low reset (dst domain) |
| d_async | input | 1 | Source-domain signal (free-running) |
| q_sync | output | 1 | Synchronized signal in dst domain (2 cycles latency) |

## Parameters

None.

## Behavior

```
always_ff @(posedge clk_dst or negedge rst_n)
  if (!rst_n) {q_sync, q_meta} <= 2'b00;
  else        {q_sync, q_meta} <= {q_meta, d_async};
```

## When to Use

- Cross-clock-domain single-bit signal
- Source clock period ≥ 2× destination clock period (otherwise pulse may be missed; use handshake or gray-code path instead)

## When NOT to Use

- Multi-bit buses (use gray-code counter + 2ff per bit, or async-FIFO)
- Combinational paths spanning clock domains
- Path with timing-critical assertions (2 cycles latency is non-negligible)

## Reuse Tag

Set `mas.modules[i].reuse = "2ff-sync"` in MAS.
