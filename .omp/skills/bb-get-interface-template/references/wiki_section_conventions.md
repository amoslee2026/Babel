# Wiki Section Conventions

## Standard Sections in Protocol Docs
1. **Overview** — Protocol summary, use cases
2. **Signal List** — Table of all interface signals (name, direction, width, description)
3. **Timing Diagram** — Waveform descriptions (ASCII or Mermaid)
4. **Transaction Format** — Data/command packet structures
5. **Configuration** — Parameterization and customization
6. **Integration Guide** — How to instantiate and connect

## Table Format
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk | input | 1 | System clock |
| rst_n | input | 1 | Active-low reset |
