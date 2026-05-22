## 第 8 章 · 动手实验

> **完整 step-by-step 实验材料见 `labs/` 目录**。本章给出每个实验的目标和最小代码骨架。

### Lab 1: 写一个 Skill — `/check-clock-domain`

**目标**：写一个 skill，输入 RTL 文件路径，调用 grep 统计每个 `always @(posedge ...)` 出现的时钟域，输出 markdown 表格。

最小骨架：

```yaml
---
name: check-clock-domain
description: "扫描 SystemVerilog 文件统计 always 块使用的时钟域，输出 markdown 表格。触发：用户问『这个 RTL 有几个时钟域』或想做 quick CDC 自查。"
---

# check-clock-domain

## 用途
快速识别 RTL 中的时钟域，用于 CDC 风险初筛。

## 工作流程
1. 解析参数：第一个 token 是文件路径或 glob。
2. 用 Bash 跑 `grep -oP 'posedge \K\w+' <files> | sort -u`。
3. 把结果整理成 markdown 表格输出。

## 输出格式
| 时钟信号 | 出现次数 |
|---------|---------|
| clk_100m | 12 |
| clk_apb  | 5 |
```

完整文件见 `labs/lab1-skill/`。

### Lab 2: 写一个 Hook — 禁止综合阶段写 RTL

**目标**：当 sub-agent `bba-guru-synthesis` 正在跑时，PreToolUse 拦截任何对 `designs/*/rtl/**.sv` 的 Write/Edit，因为 RTL 应在更上游就冻结。

```bash
#!/usr/bin/env bash
# .claude/hooks/bb-hook-synthesis-rtl-freeze.sh
set -eu
INPUT="$(cat || true)"
TARGET="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))')"
AGENT="$(printf '%s' "$INPUT" | python3 -c \
  'import sys,json; d=json.load(sys.stdin); print(d.get("agent_type",""))')"

case "$AGENT:$TARGET" in
  bba-guru-synthesis:*designs/*/rtl/*.sv)
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "RTL frozen at synthesis stage. Bounce back via rtl-needs-fix."
      }
    }'
    exit 0
    ;;
  *) exit 0 ;;
esac
```

注册到 `.claude/settings.json`：

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Write|Edit",
        "hooks": [ { "type": "command",
                     "command": ".claude/hooks/bb-hook-synthesis-rtl-freeze.sh" } ] }
    ]
  }
}
```

完整文件见 `labs/lab2-hook/`。

### Lab 3: 写一个 Sub-agent — `qor-watcher`

**目标**：一个**只读、后台运行**的 sub-agent，监控 `designs/*/synth/` 下的 yosys log，发现 WNS<0 / area 暴涨 时自动开 issue。

```yaml
---
name: qor-watcher
description: "Monitors yosys synth logs for QoR regressions (WNS<0, area>baseline×1.2) and opens an issue. PROACTIVELY check after every synthesis run."
tools: ["Read", "Grep", "Glob", "Skill"]
disallowedTools: ["Write", "Edit", "Bash"]   # 只读，绝不改文件
model: haiku                                  # 便宜的小模型够用
color: green
background: true
memory: project
---

## Role
You are the QoR Watcher. Whenever yosys finishes, you:
1. Glob `designs/*/synth/*.log`.
2. Extract WNS, area, errors.
3. Compare against `designs/<name>/synth/baseline.json`.
4. If WNS<0 OR area>baseline×1.2 OR errors>0:
   - Invoke /bb-create-issue with label `qor-regression`, artifact=log path.
5. Else: stay silent.

## Constraints
- READ-ONLY. Never modify any file.
- Output must be a one-line summary per design.
```

完整文件见 `labs/lab3-subagent/`。

### Lab 4: 组合实验 — `/precheck-rtl` pipeline

把 Lab 1 (skill) + Lab 2 (hook) + Lab 3 (sub-agent) 串成一条短流水线：

```
user: /precheck-rtl designs/foo
  └─> skill: check-clock-domain  ──► clock_domains.md
  └─> hook: 检查文件位置          ──► permit / deny
  └─> Agent: qor-watcher          ──► 历史 QoR baseline 比对
  └─> markdown report 输出
```

### Lab 5: 写一个 MCP server（选做）

把内部 EDA 调度系统（LSF/SLURM）暴露给 Claude Code，让 agent 能 `submit_job` / `query_job_status`。参考模板 `templates/mcp-server-skeleton/`。

