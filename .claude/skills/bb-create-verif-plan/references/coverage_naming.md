# Coverage Naming Conventions

## Covergroup Naming
- Format: `cg_<module>_<feature>`
- Example: `cg_m00_state`, `cg_axi_handshake`

## Coverpoint Naming
- Format: `cp_<signal_name>`
- Example: `cp_valid`, `cp_ready`, `cp_state`

## Bin Naming
- Format: `bin_<description>`
- Example: `bin_idle`, `bin_active`, `bin_overflow`

## Cross Coverage Naming
- Format: `cx_<signal1>_x_<signal2>`
- Example: `cx_valid_x_ready`, `cx_state_x_mode`

## Naming Rules
1. Use lowercase with underscores
2. Prefix covergroups with `cg_`
3. Prefix coverpoints with `cp_`
4. Prefix bins with `bin_`
5. Prefix cross coverage with `cx_`
6. Keep names under 40 characters
7. Use module name as first qualifier after prefix
