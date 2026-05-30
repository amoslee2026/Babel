# SystemVerilog Constructs Unsupported by pyverilog

## Completely Unsupported

These constructs cause pyverilog to raise `SyntaxError` and require fallback parsing
(`bb-parse-ast --backend verible` or `--backend slang`).

| Construct | Example | Workaround |
|-----------|---------|------------|
| `interface` | `interface axi_if; ... endinterface` | slang / verible |
| `class` | `class transaction; ... endclass` | Not synthesizable; skip |
| `package` | `package pkg; ... endpackage` | slang |
| `program` | `program test; ... endprogram` | Not synthesizable; skip |
| `covergroup` | `covergroup cg; ... endgroup` | Not synthesizable; skip |
| `constraint` | `constraint c { ... }` | Not synthesizable; skip |
| `enum` (typed) | `typedef enum logic [1:0] { ... } state_t;` | Use untyped enum or slang |
| `struct` (packed) | `typedef struct packed { ... } data_t;` | slang |
| `union` | `typedef union packed { ... } u_t;` | slang |

## Partially Supported

These may parse but with incomplete AST representation.

| Construct | Issue | Impact |
|-----------|-------|--------|
| `typedef` | Creates node but loses type info | Signal widths may be wrong |
| `parameter type` | Parsed as generic parameter | Type info lost |
| `generate for` | Parsed but children may be flat | Hierarchy unclear |
| `unique case` | `unique` qualifier dropped | No uniqueness info |
| `priority case` | `priority` qualifier dropped | No priority info |
| `inside` operator | May not parse | Use slang |

## Preprocessor Limitations

| Issue | Description |
|-------|-------------|
| `` `include`` | Resolved but path must be in include dirs |
| `` `define`` with args | Macro arguments not fully expanded |
| `` `ifdef`` nesting | Deep nesting (>10 levels) may fail |
| `` `timescale`` | Parsed but not enforced |

## Detection

When pyverilog fails, `parse_ast_output.py` detects `UNSUPPORTED_SV_SYNTAX`
in the log and signals the caller to retry with `--backend verible` or `--backend slang`.

## Migration Path

1. First attempt: pyverilog (fast, well-tested for basic Verilog)
2. On `UNSUPPORTED_SV_SYNTAX`: switch to verible (good SV coverage)
3. On verible failure: switch to slang (best SV coverage)
4. If all fail: manual intervention required
