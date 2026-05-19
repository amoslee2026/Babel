---
name: bb-gate-rtl-quality
description: "RTL 质量门禁：lint 0 error + file_list.f 顶层在最后 + rtl_artifact.json schema 合法。通过才允许 commit / 开 issue。触发场景：(1) bba-guru-rtl 写完 RTL；(2) 显式 /bb-gate-rtl-quality。"
---

# bb-gate-rtl-quality

## 职责

综合 lint 结果 + 拓扑序 + artifact schema 三项判定，blocking gate。

- 调用者：`bba-guru-rtl`
- 上游：`bb-check-lint`、`bb-find-module-deps`
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| rtl_dir | path | true | — | `designs/<name>/rtl/` |
| file_list | path | true | — | `file_list.f` |
| rtl_artifact | path | true | — | `rtl_artifact.json` |
| design_name | string | true | — | — |
| stamp | string | false | `<auto>` | — |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/rtl/quality_gate_<stamp>.json` |
| `script_path` | `designs/<name>/rtl/quality_gate_<stamp>.py` |
| `lint_clean` | bool |
| `file_list_order_valid` | bool |
| `artifact_schema_valid` | bool |
| `pass` | bool（三项全 true） |
| `details` | str（失败原因） |
| `valid` | bool |

## 4-Phase 执行

### Phase 1 — render_gate_py

`scripts/render_gate_py.py`：

```python
# 1. 调 bb-check-lint：取 errors == []
# 2. 校验 file_list.f：顶层模块文件在最后行
# 3. jsonschema validate rtl_artifact.json
```

### Phase 2 — run_gate

`timeout 300 uv run python <script_path> > <log> 2>&1`

### Phase 3 — parse_gate

`scripts/parse_gate.py`：合并三项布尔，`pass = AND(...)`，否则收集 details。

### Phase 4 — return

返回 JSON。`pass=false` → bba-guru-rtl 修复后重试。

## 通过标准

| 项 | 条件 |
|----|------|
| lint_clean | verible 0 error，无 waive |
| file_list_order_valid | top_module 文件最后一行 |
| artifact_schema_valid | rtl_artifact.json ↔ schema |

## 资源索引

- `scripts/render_gate_py.py`、`scripts/run_gate.py`、`scripts/parse_gate.py`
- `assets/rtl_artifact.schema.json`

**项目级 Coding Style 参考**：
- `wiki/codingstyle/systemverilog_styleguide.md` — SystemVerilog Style Guide (systemverilog.io)
- `wiki/codingstyle/freescale_verilog_standard.md` — Freescale Verilog HDL Coding Standard SRS V3.2
