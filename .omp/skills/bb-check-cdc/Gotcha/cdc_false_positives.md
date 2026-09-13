# CDC False Positives

## Common False Positive Sources

### 1. Handshake Protocols
Req/ack handshake protocols are inherently safe for CDC but static analysis tools flag them.
Look for: `req`, `ack`, `valid`, `ready` signal pairs with proper protocol.

### 2. Gray Code Counters
FIFO pointers encoded in Gray code change only one bit at a time, making them safe
for CDC without explicit synchronizers. Tools may flag individual bits.

### 3. Quasi-Synchronous Domains
Clocks derived from the same PLL (e.g., 500MHz and 250MHz from divide-by-2) have
deterministic phase relationship. These are not true async crossings.

### 4. Test/Debug Signals
JTAG and debug signals (TCK domain) are low-frequency and have inherent setup/hold
margins. Flagging these creates noise.

### 5. Reset Synchronizers
Properly implemented async-assert/sync-deassert resets appear as CDC paths but are
the correct pattern. Verify the synchronizer structure instead.

### 6. Multi-Bit Synchronous Interfaces
Buses that are registered on both sides with a handshake do not need per-bit
synchronizers. Tools may flag individual data bits.

## Waiver Strategy
- Document each waiver with justification
- Group waivers by category (handshake, gray_code, quasi_sync)
- Re-evaluate waivers at each design iteration
- Never waive true async crossings without synchronizer verification
