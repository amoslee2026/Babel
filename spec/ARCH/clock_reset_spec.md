# Clock & Reset Architecture

## Clock Sources

| Source | Frequency | Purpose |
|--------|-----------|---------|
| EXT_CLK | 50 MHz | 外部晶振 |
| PLL_MAIN | 500 MHz | 主系统时钟 |
| CLK_AON | 1 MHz | Always-on |

## Clock Domains

| Domain | Frequency | Modules |
|--------|-----------|---------|
| CLK_SYS | 500 MHz | M00-M04 |
| CLK_AON | 1 MHz | M05-M07 |

## CDC Strategy

| From | To | Method |
|------|-----|--------|
| CLK_SYS | CLK_AON | 2-stage sync |
| CLK_AON | CLK_SYS | Handshake |

## Reset Sources

| Source | Type | Scope |
|--------|------|-------|
| POR | Async | Global |
| SW_RESET | Sync | Main |
