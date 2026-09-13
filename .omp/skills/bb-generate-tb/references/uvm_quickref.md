# UVM Quick Reference

## Test Hierarchy
```
uvm_test -> uvm_env -> uvm_agent -> uvm_driver/monitor/sequencer
```

## Key Classes
- `uvm_test`: Top-level test, configures env
- `uvm_env`: Contains agents, scoreboard
- `uvm_agent`: Contains driver, monitor, sequencer
- `uvm_driver`: Drives DUT from sequence items
- `uvm_monitor`: Observes DUT, sends to scoreboard
- `uvm_scoreboard`: Compares expected vs actual

## Phase Execution Order
build -> connect -> run -> extract -> check -> report -> final
