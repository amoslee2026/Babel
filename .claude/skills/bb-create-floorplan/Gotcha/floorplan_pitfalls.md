# Floorplan Pitfalls — ASAP7 7nm

## 1. Die Area Too Small
Utilization > 70% causes routing congestion. Target ≤ 70%.

## 2. IO Pad Ordering Mismatch
Pad order must match netlist port declarations, not spec order.

## 3. Magic `load` vs `readspice`
`load` reads .mag files. Use `readspice` for gate-level netlists.

## 4. Margin Too Tight for IO Ring
margin ≥ max(pad_height, 5um) + 2um routing channel.

## 5. Clock Source Not Constrained
Place clock source pad at die edge center for optimal CTS.

## 6. Aspect Ratio Extreme
Target 0.8–1.2 for balanced routing resources.
