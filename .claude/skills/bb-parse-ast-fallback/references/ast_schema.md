# Unified AST JSON Schema

This schema is shared between `bb-parse-ast` (pyverilog) and `bb-parse-ast-fallback`
(verible / slang). All downstream consumers expect this format.

## Top-Level Structure

```json
{
  "modules": [
    {
      "name": "module_name",
      "ports": [
        {
          "name": "clk",
          "direction": "input",
          "width": "1"
        }
      ],
      "items": [ ... ]
    }
  ],
  "top_module": "top_module_name",
  "node_count": 1234,
  "serialized": true,
  "backend": "pyverilog | verible | slang",
  "design_name": "design_name",
  "source_files": ["file1.sv", "file2.sv"]
}
```

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `modules` | list | List of module definitions |
| `top_module` | string or null | Name of the first/top module |
| `node_count` | int | Total AST node count |
| `serialized` | bool | Always true for valid output |

## Module Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Module name |
| `ports` | list | yes | Port declarations |
| `items` | list | no | Internal items (assignments, always blocks, etc.) |

## Port Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Port signal name |
| `direction` | string | yes | `input`, `output`, or `inout` |
| `width` | string | no | Bit width (e.g., "32", "[7:0]") |

## AST Node Object (items children)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | Node type (e.g., "Assign", "Always", "Instance") |
| `name` | string | no | Node name (for named constructs) |
| `value` | string | no | Node value (for literals) |
| `width` | string | no | Bit width |
| `direction` | string | no | Signal direction |
| `children` | list | no | Child AST nodes |

## Node Types

| Type | Description |
|------|-------------|
| `Assign` | Continuous assignment (`assign x = y`) |
| `Always` | Always block (combinational or sequential) |
| `Instance` | Module instantiation |
| `Wire` | Wire/net declaration |
| `Reg` | Register/variable declaration |
| `Parameter` | Parameter definition |
| `IfStatement` | Conditional statement |
| `CaseStatement` | Case/switch statement |
| `Function` | Function definition |
| `Task` | Task definition |
| `Typedef` | Type alias |
| `GenerateIf` | Generate-if block |
| `GenerateFor` | Generate-for block |

## Validation

Use `parse_fallback_output.py` to validate:
1. File exists and is valid JSON
2. Required top-level keys present
3. Each module has `name` and `ports`
4. `node_count` > 0

## Backend-Specific Notes

- **pyverilog**: `backend` field may be absent (legacy)
- **verible**: Width may be in range notation `[7:0]`
- **slang**: Width is always decimal integer string
