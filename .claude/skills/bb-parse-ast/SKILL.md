---
name: bb-parse-ast
description: "用 pyverilog 解析 SystemVerilog RTL 为 AST JSON，供 CDC 检查 / signal path tracing / module dep 分析。主解析器；失败时切换 bb-parse-ast-fallback。触发场景：(1) bba-guru-synthesis CDC 检查前；(2) bb-trace-signal-path / bb-find-module-deps 之前；(3) 显式 /bb-parse-ast。"
---

# bb-parse-ast

## 职责

用 pyverilog（主解析器）把 RTL 转为 AST JSON，供下游静态分析消费。

- 调用者：`bba-guru-synthesis`、`bb-check-cdc`、`bb-trace-signal-path`、`bb-find-module-deps`
- Fallback：`bb-parse-ast-fallback`（verible / slang）
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| file_list | path | true | — | `file_list.f` |
| design_name | string | true | — | — |
| output_format | enum | false | `json` | `json` \| `pickle` |
| stamp | string | false | `<auto YYYYMMDD-HHMMSS>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/ast/ast_<stamp>.json` |
| `script_path` | `designs/<name>/ast/parse_ast_<stamp>.py` |
| `log_path` | `designs/<name>/ast/parse_ast_<stamp>.log` |
| `modules` | list[str] |
| `valid` | bool |
| `error` | string\|null（解析失败时为 `UNSUPPORTED_SV_SYNTAX` 等） |

## 4-Phase 执行

### Phase 1 — render_parser_py

`scripts/render_parser_py.py` 渲染：

```python
import json
from pyverilog.vparser.parser import parse
from <bb-parse-ast>/lib/ast_serializer import serialize_ast

filelist = [l.strip() for l in open("<file_list>") if l.strip()]
ast, _ = parse(filelist)
out = serialize_ast(ast)
json.dump(out, open("<artifact_path>", "w"), indent=2)
print("modules:", [m["name"] for m in out["modules"]])
```

### Phase 2 — run_parser

`scripts/run_parser.py`：

1. `uv run python <script_path> > <log_path> 2>&1`
2. log 末尾追加 `exit:<rc>`
3. timeout 600s

### Phase 3 — parse_ast_output

`scripts/parse_ast_output.py`：

- JSON 文件存在且非空 → `valid=true`
- 读 `modules` 字段
- log 含 `pyverilog.vparser` Exception → `valid=false`，识别为 `UNSUPPORTED_SV_SYNTAX`

写 `parse_summary_<stamp>.json`。

### Phase 4 — return

返回 JSON。调用方据 `valid` 决定是否走 fallback。

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| valid=true | 直接消费 ast.json |
| valid=false & UNSUPPORTED_SV_SYNTAX | 调用方切到 `bb-parse-ast-fallback` |
| Phase 2 timeout（600s） | `error="AST_TIMEOUT"` |

## 资源索引

- `scripts/render_parser_py.py`、`scripts/run_parser.py`、`scripts/parse_ast_output.py`
- `lib/ast_serializer.py` — pyverilog AST → JSON 序列化器
- `references/pyverilog_quickref.md`
- `Gotcha/sv_syntax_unsupported.md` — pyverilog 不支持的 SV 构造
