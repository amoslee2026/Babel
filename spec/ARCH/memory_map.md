# Memory Architecture

## Memory Types

| Type | Size | Purpose |
|------|------|---------|
| DRAM | 2 GB | 模型权重、KV cache |
| SRAM | 512 KB | Scratchpad |

## Memory Map

| Base | Size | Type | Access |
|------|------|------|--------|
| 0x0000_0000 | 2 GB | DRAM | RW |
| 0x1000_0000 | 512 KB | SRAM | RW |
| 0x4000_0000 | 4 KB | Registers | RW |
