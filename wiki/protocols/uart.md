---
name: uart
content_hash: "PLACEHOLDER_HASH"
version: 0.1.0
---

# UART (Universal Asynchronous Receiver / Transmitter)

## Overview

Async serial protocol: 1 start + 5-9 data + optional parity + 1/1.5/2 stop bits. v1.3 MVP supports the **16550-compatible** subset.

## Frame Format

- 8N1: 1 start + 8 data + 0 parity + 1 stop (most common)
- Baud rates: 9600 / 19200 / 38400 / 57600 / 115200 / 230400 / 460800 / 921600
- Internal baud generator: 16x or 8x oversample

## Interface

| name | direction | width | description |
|------|-----------|-------|-------------|
| clk | input | 1 | System clock |
| rst_n | input | 1 | Async active-low reset |
| rx | input | 1 | Receive data line |
| tx | output | 1 | Transmit data line |
| tx_data | input | 8 | TX byte to send |
| tx_valid | input | 1 | TX data valid |
| tx_ready | output | 1 | TX FIFO has room |
| rx_data | output | 8 | RX byte received |
| rx_valid | output | 1 | RX byte ready |
| rx_ready | input | 1 | Consumer reads RX byte |
| baud_div | input | 16 | Baud divisor (clk_freq / (16 × baud)) |

## Parameters

| name | default |
|------|---------|
| DATA_BITS | 8 |
| PARITY | "none" |
| STOP_BITS | 1 |
| FIFO_DEPTH | 16 |

## Timing

- TX shift register clocked at baud_rate
- RX oversample at 16 × baud_rate, sample at middle of bit period
- CDC: if `clk` ≠ baud source, instantiate `2ff-sync` on `rx` input (see `wiki/cbb/2ff-sync.md`)
