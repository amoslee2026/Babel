# cocotb Quick Reference

## Basic Test Structure
```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_basic(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Test logic here
```

## Key Triggers
- `RisingEdge(signal)` -- wait for rising edge
- `FallingEdge(signal)` -- wait for falling edge
- `Timer(value, units)` -- wait for time duration
- `ClockCycles(signal, n)` -- wait for n clock cycles
- `Combine(*triggers)` -- wait for all triggers
