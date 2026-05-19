---
name: sync-fifo
content_hash: "PLACEHOLDER_HASH"
version: 0.1.0
---

# Sync FIFO (Synchronous First-In First-Out)

## Overview

Parameterized synchronous FIFO. Single clock domain for both write and read. For cross-clock FIFOs use `async-fifo` (TBD) or pair this CBB with `2ff-sync` on full/empty status.

## Interface

| name | direction | width | description |
|------|-----------|-------|-------------|
| clk | input | 1 | Clock |
| rst_n | input | 1 | Async active-low reset |
| wr_en | input | 1 | Write enable |
| wr_data | input | WIDTH | Write data |
| rd_en | input | 1 | Read enable |
| rd_data | output | WIDTH | Read data (combinational from FIFO head) |
| full | output | 1 | FIFO is full (writes ignored) |
| empty | output | 1 | FIFO is empty (rd_data invalid) |
| count | output | log2(DEPTH)+1 | Current occupancy (optional) |

## Parameters

| name | default | description |
|------|---------|-------------|
| WIDTH | 8 | Data width |
| DEPTH | 16 | FIFO depth (power-of-2 recommended) |

## Behavior

- Write when `wr_en && !full` → push to tail
- Read when `rd_en && !empty` → pop from head, advance pointer
- Concurrent read+write at same cycle allowed (count unchanged)

## Timing

- All signals synchronous to `clk`
- 0-cycle read latency (`rd_data` shows current head)
- 1-cycle write-then-read pipelining if needed (TBD parameter `WRITE_FIRST`)

## Common Pitfalls

- `full`/`empty` must be registered, NOT combinational — otherwise downstream sees flags toggling within the same cycle
- DEPTH non-power-of-2 requires comparator-based occupancy (more area than pointer-diff)
- Reset MUST clear both pointers; do not assume X-state is harmless

## Reuse Tag

Set `mas.modules[i].reuse = "sync-fifo"` to mark a module as a verbatim instantiation.
