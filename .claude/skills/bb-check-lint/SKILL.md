---
name: bb-check-lint
description: "调用 verible-verilog-lint 检查 SV 源码。src 必须可综合（零 syntax error），tb 允许 verification constructs。发现 src error 时自动修复重检（max 3 iter）。触发：(1) bb-guru-rtl 生成后；(2) RTL 修复重检；(3) 显式 /bb-check-lint。"
---

# bb-check-lint

## 职责

对 HDL 源码执行 verible lint 检查，提取所有 error / warning 至 JSON。**src 代码必须可综合**，零 error 才通过；tb 代码允许 verification constructs（covergroup 等）。不允许 waive src 错误。

- 调用者：`bb-guru-rtl`
- 禁止使用：Task / Agent / Skill

## Input Args

| arg | type | required | 默认 | 说明 |
|-----|------|----------|------|------|
| target_dir | path | false | — | 目标目录（自动扫描所有 `.sv/.v/.vh` 文件） |
| file_list | path | false | — | `file_list.f`；显式指定检查文件列表 |
| rules_config | path | false | 内置 ASAP7 default ruleset | verible rules.cfg |
| design_name | string | false | `<target_dir或file_list_basename>` | 设计名称 |
| stamp | string | false | `<auto>` | 时间戳 |
| lint_mode | string | false | `src_only` | `src_only` / `src_and_tb` / `tb_only` |

**输入优先级**：
1. 若提供 `file_list` → 使用 file_list 中列出的文件
2. 若提供 `target_dir` → 自动扫描目录下所有 HDL 文件
3. 若两者都未提供 → 报错 `valid=false`

### 自动发现 HDL 文件逻辑

```bash
# src_only mode: 仅检查可综合代码
find <target_dir> -path "*/src/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort

# src_and_tb mode: 分开检查 src 和 tb
src_files=$(find <target_dir> -path "*/src/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort)
tb_files=$(find <target_dir> -path "*/tb/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort)

# tb_only mode: 仅检查 testbench
find <target_dir> -path "*/tb/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort
```

### 合规标准

| 代码类型 | 要求 | 允许的 constructs |
|----------|------|-------------------|
| **src（RTL）** | ✅ 必须可综合，零 syntax error | 仅 synthesizable SV |
| **tb（验证）** | ⚠️ 允许 verification constructs | covergroup, coverpoint, bins, class, program |

## Output Contract

| field | 值 |
|-------|----|
| `artifact_path` | `designs/<name>/rtl/lint_<stamp>.json` |
| `script_path` | `designs/<name>/rtl/lint_<stamp>.sh` |
| `log_path` | `designs/<name>/rtl/lint_<stamp>.log` |
| `errors` | `[{file,line,col,rule,msg}]` — 仅 src 文件的 syntax errors |
| `warnings` | `[{file,line,col,rule,msg}]` |
| `src_clean` | bool（src_errors==[]） |
| `tb_clean` | bool（tb 无 blocking issues） |
| `clean` | bool（src_clean && tb_clean） |
| `valid` | bool |
| `iteration` | int（修复迭代次数，max=3） |

## 5-Phase 执行（含修复迭代）

### Phase 0 — 收集文件列表（按 lint_mode）

```bash
case "$lint_mode" in
  src_only)
    lint_files=$(find "$target_dir" -path "*/src/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort)
    ;;
  src_and_tb)
    src_files=$(find "$target_dir" -path "*/src/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort)
    tb_files=$(find "$target_dir" -path "*/tb/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort)
    ;;
  tb_only)
    lint_files=$(find "$target_dir" -path "*/tb/*" -type f \( -name "*.sv" -o -name "*.v" \) | sort)
    ;;
esac
```

### Phase 1 — render_lint_sh

```bash
#!/bin/bash
set -eo pipefail
source ~/wrk/eda_opensources/eda_env.sh

# src lint: 严格检查
verible-verilog-lint --rules_config <rules_config> $src_files 2>&1

# tb lint: 使用 waiver 跳过 verification constructs（可选）
verible-verilog-lint --rules_config <rules_config> $tb_files 2>&1
```

### Phase 2 — run_lint

`timeout 300 bash <script_path> > <log> 2>&1`，追加 `exit:<rc>`。

### Phase 3 — parse_lint

分类 errors / warnings：
- **syntax error** → 归入 `errors[]`
- **[Style:xxx]** → 归入 `warnings[]`
- 区分 src 和 tb 文件来源

### Phase 4 — fix_and_iterate（新增）

```python
# 若 src_clean=false，调用修复
if not src_clean and iteration < 3:
    # 提取 src errors 详情
    src_errors = [e for e in errors if '/src/' in e['file']]
    
    # 调用 bb-rtl-coder 修复
    fix_result = fix_rtl_errors(src_errors)
    
    # 重新 lint
    iteration += 1
    rerun_lint()
```

### Phase 5 — return

返回 JSON。

## 收敛 / 失败

| 状态 | 行动 |
|------|------|
| src_clean=true | ✅ src 合规，进 `bb-find-module-deps` |
| src_clean=false & iter<3 | 🔧 调用 `bb-rtl-coder` 修复，重新 lint |
| iter≥3 & src_clean=false | ❌ `error="lint persistent after 3 iter"`，开 `arch-needs-fix` issue |
| tb 有 verification constructs | ⚠️ 记录但不阻塞流程 |

## 资源索引

- `scripts/render_lint_sh.py`、`scripts/run_lint.py`、`scripts/parse_lint.py`
- `assets/asap7_rules.cfg` — 默认 verible 规则集
- `assets/tb_waiver.vbl` — testbench waiver（跳过 covergroup/coverpoint/bins）
- `Gotcha/verible_rule_pitfalls.md`
- `Gotcha/verible_parser_limitations.md` — verible 不支持的 SV constructs

**项目级 Coding Style 参考**：
- `wiki/codingstyle/systemverilog_styleguide.md` — SystemVerilog Style Guide (systemverilog.io)
- `wiki/codingstyle/freescale_verilog_standard.md` — Freescale Verilog HDL Coding Standard SRS V3.2
