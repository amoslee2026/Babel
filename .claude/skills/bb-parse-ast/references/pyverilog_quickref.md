# pyverilog Quick Reference

## Installation

```bash
uv add pyverilog
```

## Core API

### Parsing

```python
from pyverilog.vparser.parser import parse

# Parse file list
ast, directives = parse(["top.sv", "sub.sv"])

# Parse with include dirs
ast, directives = parse(files, preprocess_include=["./inc"])

# Parse with defines
ast, directives = parse(files, preprocess_define={"WIDTH": "32"})
```

### AST Node Types

| Node Type | Description | Key Attributes |
|-----------|-------------|----------------|
| `ModuleDef` | Module definition | `name`, `items` |
| `Port` | Port declaration | `name`, `direction`, `width` |
| `Decl` | Signal declaration | `list` (of Var/Reg/Wire) |
| `Always` | always block | `sens_list`, `statement` |
| `Assign` | Continuous assignment | `left`, `right` |
| `Subst` | Procedural assignment | `left`, `right` |
| `Instance` | Module instantiation | `name`, `module`, `portlist` |
| `IfStatement` | Conditional | `cond`, `true_statement`, `false_statement` |
| `CaseStatement` | Case block | `comp`, `caselist` |

### Walking the AST

```python
from pyverilog.vparser.ast import Node

def walk(node, depth=0):
    print("  " * depth + type(node).__name__)
    for child in node.children():
        walk(child, depth + 1)
```

### Extracting Module Info

```python
from pyverilog.dataflow.visit import NodeVisitor

class ModuleCollector(NodeVisitor):
    def __init__(self):
        self.modules = []

    def visit_ModuleDef(self, node):
        self.modules.append(node.name)
        self.visit_children(node)
```

## Limitations

- No SystemVerilog `interface` support
- No `class` / `package` parsing
- Limited `typedef` support
- `struct` / `union` partially supported
- See `Gotcha/sv_syntax_unsupported.md` for full list

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `SyntaxError` | Unsupported SV construct | Use bb-parse-ast-fallback |
| `ImportError` | pyverilog not installed | `uv add pyverilog` |
| `FileNotFoundError` | Missing include file | Check include paths |
