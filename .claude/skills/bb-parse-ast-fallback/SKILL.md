---
name: bb-parse-ast-fallback
description: "当 pyverilog 失败时切到 verible-verilog-syntax 或 slang 作为备用 AST 解析器，输出归一化 JSON。触发场景：(1) bb-parse-ast 返回 UNSUPPORTED_SV_SYNTAX；(2) 显式 /bb-parse-ast-fallback。"
---

# bb-parse-ast-fallback

## 职责

pyverilog 失败的兜底：调用 verible 或 slang 解析 RTL，输出与 bb-parse-ast 同 schema 的 JSON，对下游透明。

- 调用者：`bb-guru-synthesis`、`bb-check-cdc`
- 上游：`bb-parse-ast`（失败时）
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| file_list | path | true | — | `file_list.f` |
| design_name | string | true | — | — |
| backend | enum | false | `verible` | `verible` \| `slang` |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/ast/ast_fallback_<stamp>.json` |
| `script_path` | `designs/<name>/ast/parse_fallback_<stamp>.sh` |
| `log_path` | `designs/<name>/ast/parse_fallback_<stamp>.log` |
| `backend_used` | str |
| `modules` | list[str] |
| `valid` | bool |
| `error` | string\|null |

## 4-Phase 执行

### Phase 1 — render_fallback_sh

`scripts/render_fallback_sh.py` 按 backend：

```bash
# backend=verible
for f in $(cat <file_list>); do
  verible-verilog-syntax --export_json "$f" >> <raw_out>
done
python3 <bb-parse-ast-fallback>/scripts/normalize_verible.py \
  --input <raw_out> --output <artifact_path>
```

```bash
# backend=slang
slang --ast-json <raw_out> $(cat <file_list>)
python3 <bb-parse-ast-fallback>/scripts/normalize_slang.py \
  --input <raw_out> --output <artifact_path>
```

### Phase 2 — run_fallback

`scripts/run_fallback.py`：

1. `source ~/wrk/eda_opensources/eda_env.sh`
2. `timeout 600 bash <script_path> > <log_path> 2>&1`
3. log 末尾追加 `exit:<rc>`

backend=verible 失败时自动重试 slang（两次串行）。

### Phase 3 — parse_fallback_output

`scripts/parse_fallback_output.py`：

- `artifact_path` 存在且 schema 验证通过 → `valid=true`
- 列出 `modules`
- 记录实际生效的 `backend_used`

### Phase 4 — return

返回 JSON。下游 `bb-check-cdc` 等无需感知 backend 差异。

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| verible 通过 | `backend_used=verible` |
| verible 失败 → slang 通过 | `backend_used=slang` |
| 两者均失败 | `valid=false, error="all AST backends failed"` → 人工介入 |

## 资源索引

- `scripts/render_fallback_sh.py`、`scripts/run_fallback.py`、`scripts/parse_fallback_output.py`
- `scripts/normalize_verible.py`、`scripts/normalize_slang.py` — schema 归一化
- `references/ast_schema.md` — 统一 AST JSON schema（与 bb-parse-ast 一致）
- `Gotcha/backend_diffs.md` — verible/slang 在 typedef/interface 上的差异
