# Backend Differences: verible vs slang vs pyverilog

## Feature Support Matrix

| Feature | pyverilog | verible | slang |
|---------|-----------|---------|-------|
| Basic Verilog | Excellent | Good | Excellent |
| SystemVerilog `interface` | No | Yes | Yes |
| `package` | No | Yes | Yes |
| `typedef` | Partial | Yes | Yes |
| `struct packed` | No | Yes | Yes |
| `enum` (typed) | No | Yes | Yes |
| `class` | No | Partial | Yes |
| `generate for` | Partial | Yes | Yes |
| `unique/priority case` | No | Yes | Yes |
| `covergroup` | No | Partial | Yes |
| Preprocessor | Basic | Good | Excellent |

## AST Structure Differences

### Module Representation

**pyverilog**:
```json
{"type": "ModuleDef", "name": "top", "children": [...]}
```

**verible**:
```json
{"tag": "kModuleDeclaration", "children": [
  {"tag": "SymbolIdentifier", "text": "top"},
  ...
]}
```

**slang**:
```json
{"kind": "InstanceDefinitionBodySymbol", "name": "top", "members": [...]}
```

### Port Direction

| Backend | Direction Values |
|---------|-----------------|
| pyverilog | `"input"`, `"output"`, `"inout"` |
| verible | `"input"`, `"output"`, `"inout"` (from text) |
| slang | `"In"`, `"Out"`, `"InOut"` (mapped by normalizer) |

### Width Representation

| Backend | Example |
|---------|---------|
| pyverilog | `"32"` or `"[31:0]"` |
| verible | `"[31:0]"` (range notation) |
| slang | `"32"` (integer bitWidth) |

## Known Quirks

### verible
- Outputs one JSON object per file (not a single tree)
- Token-level detail can be very verbose
- `--export_json` flag required
- May not handle deeply nested generate blocks

### slang
- `--ast-json` outputs the entire design as one JSON
- Uses internal symbol names that need mapping
- Better type resolution than verible
- May require `--` to separate options from files

### pyverilog
- Fastest for basic Verilog
- No SystemVerilog extensions
- Preprocessor is limited
- Best documentation of the three

## Normalization Strategy

The normalizer scripts (`normalize_verible.py`, `normalize_slang.py`) handle
these differences by:

1. **Type mapping**: Backend-specific node types -> common types
2. **Direction mapping**: Backend-specific direction strings -> common strings
3. **Width normalization**: All widths -> string representation
4. **Tree restructuring**: Backend-specific nesting -> common hierarchy

## When to Use Which

| Scenario | Recommended Backend |
|----------|-------------------|
| Basic Verilog, speed priority | pyverilog |
| SV with interfaces/packages | slang |
| SV with complex preprocessor | slang |
| Quick syntax check | verible |
| Fallback when pyverilog fails | verible (then slang) |
