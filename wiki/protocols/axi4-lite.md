---
name: axi4-lite
content_hash: "PLACEHOLDER_HASH"
version: 0.1.0
---

# AXI4-Lite

## Overview

Simplified AXI4 subset: single-beat (no burst), per-channel valid/ready, 32-bit or 64-bit data, no caching/protection signals required.

## Channels (5)

1. **AW** — Write Address: `awaddr / awvalid / awready / awprot`
2. **W**  — Write Data:    `wdata / wstrb / wvalid / wready`
3. **B**  — Write Response: `bresp / bvalid / bready`
4. **AR** — Read Address:  `araddr / arvalid / arready / arprot`
5. **R**  — Read Data:     `rdata / rresp / rvalid / rready`

## Interface

| name | direction | width | description |
|------|-----------|-------|-------------|
| aclk | input | 1 | AXI clock |
| aresetn | input | 1 | AXI active-low reset |
| awaddr | input | ADDR_W | Write address |
| awvalid | input | 1 | AW valid |
| awready | output | 1 | AW ready |
| awprot | input | 3 | AXI protection (ignored in MVP) |
| wdata | input | DATA_W | Write data |
| wstrb | input | DATA_W/8 | Write byte strobes |
| wvalid | input | 1 | W valid |
| wready | output | 1 | W ready |
| bresp | output | 2 | Write response (OKAY=00, SLVERR=10) |
| bvalid | output | 1 | B valid |
| bready | input | 1 | B ready |
| araddr | input | ADDR_W | Read address |
| arvalid | input | 1 | AR valid |
| arready | output | 1 | AR ready |
| arprot | input | 3 | AXI protection |
| rdata | output | DATA_W | Read data |
| rresp | output | 2 | Read response |
| rvalid | output | 1 | R valid |
| rready | input | 1 | R ready |

## Parameters

| name | default |
|------|---------|
| ADDR_W | 32 |
| DATA_W | 32 |

## Timing

- Single clock domain (`aclk`)
- Per-channel handshake: data captured when `valid && ready`
- No interlock between channels — AW and W can complete in any order

## Common Pitfalls

- `aresetn` is active-LOW (asynchronous assert, synchronous deassert recommended)
- `wstrb` must mask partial writes; full-write = all-ones
- Address alignment: `awaddr & (DATA_W/8 - 1) == 0`
