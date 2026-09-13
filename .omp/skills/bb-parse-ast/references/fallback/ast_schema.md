# Babel Standard AST Schema

## Top-Level Structure
```json
{
  "modules": ["module_name"],
  "ports": {"module_name": [{"name": "clk", "direction": "input", "width": 1}]},
  "instances": {"module_name": [{"name": "u_sub", "module": "submod", "parameters": {}}]},
  "parameters": {"module_name": [{"name": "WIDTH", "type": "integer", "default": 32}]},
  "status": "pass"
}
```

## Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| modules | string[] | yes | Module names found |
| ports | {mod: port[]} | yes | Port declarations per module |
| instances | {mod: inst[]} | yes | Module instantiations per module |
| parameters | {mod: param[]} | no | Parameter declarations |
| status | string | yes | "pass", "partial", or "fail" |

## Port Object: `{name, direction, width}`
- direction: "input", "output", "inout"
- width: integer (1 for single-bit)

## Instance Object: `{name, module, parameters}`
- name: instance name
- module: instantiated module name
- parameters: parameter overrides

## Status Values
- **pass**: Complete AST, all elements found
- **partial**: Incomplete extraction
- **fail**: Parser failed, no usable AST

## Parser Compatibility
| Parser | Status | Notes |
|--------|--------|-------|
| pyverilog | pass | Full SV |
| slang | pass | Modern SV |
| verible | pass | Google |
| regex | partial | Basic only |
