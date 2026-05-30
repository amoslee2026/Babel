# SV/UVM Testbench Pitfalls

## Common Issues
1. **Race conditions**: Use non-blocking assignments (<=) for sequential, blocking (=) for combinational
2. **Missing reset**: Always initialize all DUT inputs before deasserting reset
3. **Clock domain issues**: Testbench clock must match DUT clock exactly
4. **Coverage holes**: Functional coverage bins may miss corner cases -- use `cross` coverage
5. **Timeout**: Always add watchdog timer to prevent infinite simulation
6. **Memory leaks**: UVM objects must use factory, not `new()` directly
7. **Phase objections**: Raise/lower objections correctly in test sequences
