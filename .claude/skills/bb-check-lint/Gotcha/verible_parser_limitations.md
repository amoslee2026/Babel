# Verible Parser Limitations

## Unsupported SystemVerilog Constructs

### 1. Advanced Verification Features
- `covergroup` with complex cross coverage expressions
- `property` and `sequence` (SVA) in certain contexts
- `let` declarations inside interfaces
- `rand`/`randc` class members in some configurations

### 2. Package and Import Issues
- Wildcard imports (`import pkg::*`) may trigger false positives
- Package-level parameterized types
- Hierarchical references across packages

### 3. Interface and Modport
- Modport expressions in port declarations
- Virtual interfaces in class bodies
- Interface arrays

### 4. Generate Blocks
- Complex generate-for with parameterized bounds
- Nested generate-if with parameter dependencies
- Generate blocks inside interfaces

### 5. Type System
- `typedef enum` with explicit base type
- Packed struct/unions in certain positions
- String type operations

## Workarounds
- Use `// verible-verilog-lint: off` to suppress specific lines
- Create waiver files for known false positives
- Simplify constructs where possible for lint compatibility
- Run verible with `--waiver_files` flag for project-wide waivers
