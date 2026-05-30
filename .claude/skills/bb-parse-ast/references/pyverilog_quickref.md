# PyVerilog Quick Reference

Install: `pip install pyverilog`

## Basic Parsing
```python
from pyverilog.vparser.parser import parse
ast = parse(['module.sv', 'tb.sv'])
ast = parse(['top.sv'], include=['./inc'], preprocess_define=['SYNTHESIS'])
```

## AST Traversal
```python
def walk(node, depth=0):
    print('  ' * depth + type(node).__name__)
    for child in node.children():
        walk(child, depth + 1)
```

## Key Node Types
| Node | Description |
|------|-------------|
| `ModuleDef` | Module definition |
| `Port` | Port declaration |
| `Instance` | Module instantiation |
| `Assign` | Continuous assignment |
| `Always` | Always block |
| `NonblockingSubstitution` | <= assignment |
| `BlockingSubstitution` | = assignment |

## Extract Modules
```python
from pyverilog.vparser.ast import ModuleDef
for item in ast.description.defs:
    if isinstance(item, ModuleDef):
        print(f"Module: {item.name}")
```

## Extract Instances
```python
def find_instances(module):
    return [{'name': inst.name, 'module': item.module}
            for item in module.items if isinstance(item, InstanceList)
            for inst in item.instances]
```

## Generate JSON AST
```python
def ast_to_dict(node):
    result = {'type': type(node).__name__}
    if hasattr(node, 'name'): result['name'] = node.name
    if hasattr(node, 'children'):
        result['children'] = [ast_to_dict(c) for c in node.children()]
    return result
```

## Tips
- Use `str(node)` to get Verilog representation
- Check `isinstance()` before accessing attributes
- Use `node.children()` for generic traversal
