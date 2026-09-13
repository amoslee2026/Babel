# RTL Review Dimensions

## 1. Correctness
- Logic matches specification
- Edge cases handled (reset, overflow, underflow)
- State machines have valid transitions
- No combinational loops

## 2. Safety
- No unintended latches
- All signals assigned in all branches
- Reset covers all registers
- Clock domain crossings properly synchronized

## 3. Traceability
- @requirement annotations present
- @spec_hash matches current spec
- REQ_ID references valid and unique
- Module header matches MAS definition

## 4. Performance
- Critical path minimization
- No unnecessary pipeline stages
- Resource sharing where appropriate
- Power gating opportunities identified

## 5. Style
- Naming follows coding style guide
- Consistent formatting
- No dead code
- Comments explain non-obvious decisions
