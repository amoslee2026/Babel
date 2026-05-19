# Babel `.claude/` 配置规约（v1.3 — fix M-08 / L-01 / L-06）

本文件作为 `.claude/` 内所有 agents/skills/hooks 的一致性补丁规约。

## 0. 破折号使用规范（fix L-06）

| 字符 | 用途 | 示例 |
|------|------|------|
| `-` (U+002D, ASCII hyphen) | 标识符、文件名、kebab-case、复合形容词 | `bb-invoke-yosys`, `file_list.f`, `fail-soft`, `8-bit` |
| `—` (U+2014, em-dash) | 英文/中文 prose 分隔符、参数说明 | `Phase 1 — render_tcl`, `verilator 5.012 — wraps the upstream binary` |

混排不算"未统一"——上述两类用途**故意不同**，是排版正确。审查工具或人不应批量替换两者。


## 1. SKILL.md scripts/references/Gotcha 状态标签（fix M-08）

每个 SKILL.md 的「资源索引」中引用的 `scripts/*.py` / `references/*.md` / `assets/*` / `Gotcha/*.md`，按以下规则标注：

- **未加注释** = v1.3 必备，agent 调用时若不存在则走 fallback（Bash + 内联 Python）
- **`(PLANNED v1.4)`** = 规划中，不必影响 v1.3 流水线运行
- **`(TODO: ���)`** = 已识别需求，需要后续 issue 跟进

agent / skill 自身不应阻塞在尚未实装的 reference 文件上。所有 fallback 路径必须可独立工作。

## 2. 超时覆盖（fix L-01）

skill 内硬编码的 `timeout <N>` 默认值可通过环境变量覆盖：

```
BB_TIMEOUT_<SKILL>=<seconds>     # 单个 skill 的覆盖
BB_TIMEOUT_DEFAULT=<seconds>     # 全局兜底
```

例：

```bash
export BB_TIMEOUT_BB_INVOKE_YOSYS=1200      # yosys 综合从 600s 提到 1200s
export BB_TIMEOUT_BB_INVOKE_QROUTER=7200    # qrouter 大设计提到 2h
```

各 skill 在 Phase 2 `run_script` 内读取相应 env var；缺失时使用 SKILL.md 文档中的默认值。

## 3. 文件名/路径规范

- hook 文件统一 `bb-hook-<purpose>.sh`（fix H-05）
- skill 目录统一 `bb-<purpose>` 或 `ic-<purpose>`
- schema 文件 `.claude/schemas/<name>.schema.json`（fix C-04）
- references 文件 `.claude/references/<topic>.md`

## 4. ASAP7 corner 命名

强制使用 `<process>_0p<voltage>v_<temp>c` 格式（小写）；完整规则与禁止拼写见 `.claude/references/asap7_corners.md`（fix L-08）。

## 5. Schema 一致性

所有 producer/consumer 同名字段必须严格按 `.claude/schemas/*.json` 定义；`test_report.json` 的覆盖率字段使用 **嵌套** `code_coverage.{line,branch,toggle}`（fix C-01）。

## 6. Hook 注册

所有 hook 必须在 `.claude/settings.json` 的 `hooks` 段注册才会生效。settings 不注册 = dead code（fix C-03）。
