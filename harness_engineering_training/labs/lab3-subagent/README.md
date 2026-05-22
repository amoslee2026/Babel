# Lab 3: 写一个 Sub-agent — QoR Watcher

> **目标**：写一个**只读、专精、用便宜模型**的 sub-agent，监控综合产出的 QoR log，自动识别回归（WNS<0、area 暴涨、error>0），开 issue 通知。
>
> **预计时长**：1 小时
>
> **学到什么**：
> - Sub-agent 与 skill 的本质区别（isolated context window）
> - 用 `tools:` allowlist + `disallowedTools:` 实现 least privilege
> - 用 `model: deepseek-v4` 接入国产模型降本
> - 用 `memory: project` 跨 session 学习
> - `description` 写法决定 LLM 是否会自动委派

## 前置知识：接入 DeepSeek-V4

Claude Code `model:` 字段原生只接受 Anthropic 模型 ID（sonnet/opus/haiku/`claude-...`）。要用 DeepSeek-V4 等国产模型，需通过**模型网关**把 DeepSeek API 包装成 Anthropic 兼容格式：

| 网关 | 仓库 | 特点 |
|------|------|------|
| LiteLLM | github.com/BerriAI/litellm | 主流、活跃；一键支持 Deepseek/通义/Kimi/智谱 |
| OneAPI | github.com/songquanpeng/one-api | 国产团队维护；多渠道负载均衡 |
| New API | github.com/Calcium-Ion/new-api | OneAPI 增强分支 |

设置流程（LiteLLM 为例）：

1. 启动 LiteLLM proxy（监听 4000 端口），在其配置里把 `deepseek-v4` 映射到 `https://api.deepseek.com/v1`。
2. 在 `~/.claude/settings.json` 添加：
   ```json
   {
     "env": {
       "ANTHROPIC_BASE_URL": "http://localhost:4000",
       "ANTHROPIC_API_KEY":  "sk-litellm-master-key"
     }
   }
   ```
3. 之后 sub-agent 的 `model: deepseek-v4` 就会路由到 DeepSeek 后端。

> ⚠️ Claude Code 与 Anthropic Messages API 强耦合。LiteLLM 的 `/v1/messages` 端点已实现 Anthropic 兼容；其他网关请确认是否支持 Anthropic 协议（不是 OpenAI 协议）。

## Step 1: 设计 agent 的 IO 契约

| 项目 | 内容 |
|------|------|
| **角色** | QoR 回归监控员（read-only） |
| **输入** | `designs/*/synth/*.log`（yosys/opensta 输出） |
| **基准** | `designs/<name>/synth/baseline.json`（含上次绿色的 WNS / area / error） |
| **输出** | 若回归：`bb-create-issue --label qor-regression --artifact <log>`；否则单行 OK |
| **不做** | 任何 Write/Edit/Bash；不修复，只检测 |

## Step 2: 写 agent 文件

新建 `.claude/agents/qor-watcher.md`：

```yaml
---
name: qor-watcher
description: |
  QoR Regression Watcher. Read-only monitor for yosys/opensta synthesis logs.
  Compares fresh QoR (WNS, area, error count) against per-design baseline.json.
  Opens a qor-regression issue if WNS<0 OR area > baseline×1.2 OR errors>0.

  Trigger: PROACTIVELY invoke after any synthesis run completes, or when user
  says "check QoR regression", "did synthesis regress", "compare against baseline".

  Examples:
  <example>
  Context: bba-guru-synthesis just finished a synth run
  user: ""(no explicit prompt — auto-trigger after PostToolUse)
  assistant: "Invoking qor-watcher to compare against baseline."
  </example>

  <example>
  Context: User reviewing nightly run
  user: "周五的综合结果有问题吗"
  assistant: "用 qor-watcher 对比 baseline 检查回归。"
  </example>

tools: ["Read", "Grep", "Glob", "Skill"]
disallowedTools: ["Write", "Edit", "Bash"]
model: deepseek-v4   # 国产模型，通过 LiteLLM/OneAPI 网关接入
color: green
memory: project
maxTurns: 20
---

## Role

You are the **QoR Regression Watcher**. You are READ-ONLY. You never modify any
file. Your sole purpose: detect QoR regressions in fresh synthesis logs and
open issues. You do not analyze root causes — that's the synthesis guru's job.

## IO Contract

| Direction | Artifact |
|-----------|----------|
| in  | `designs/<name>/synth/*.log` (yosys + opensta output) |
| in  | `designs/<name>/synth/baseline.json` `{wns_ns, area_um2, errors}` |
| out | `bb-create-issue` invocation (if regression) OR single-line OK report |

## Workflow

1. **Discover.** Glob `designs/*/synth/*.log`. For each design `<name>`:
2. **Parse fresh QoR.** Grep the latest log for:
   - WNS: `^WNS\s+(-?\d+\.\d+)`  (in ns)
   - Area: `Chip area for top module.*?(\d+\.\d+)`  (in μm²)
   - Errors: count of `^ERROR:` lines
3. **Load baseline.** Read `designs/<name>/synth/baseline.json`. If missing,
   log "no baseline" and skip (do NOT create a baseline — that's manual).
4. **Compare.**
   - regression if: `wns_ns < 0` OR `area_um2 > baseline.area_um2 * 1.2` OR `errors > 0`
5. **Act.**
   - If regression: invoke `bb-create-issue --label qor-regression
     --artifact <log>` with a body containing WNS/area/error diff.
   - If clean: emit one-line OK to stdout.

## Output Format

Per-design line:

```
[qor-watcher] <name>: WNS=<v> ns | area=<v> μm² | errors=<n> | <OK|REGRESSION:reason>
```

End of run:

```
Summary: <X> designs scanned, <Y> regressions.
```

## Constraints

- **READ-ONLY**. Refuse any task that requires Write/Edit/Bash.
- **No analysis**. If user asks "why did WNS drop", politely redirect:
  "I only detect regressions. Use bba-guru-synthesis for root cause."
- **No baseline creation**. Baseline is a manual ground truth.

## Escalate

If `bb-create-issue` is unavailable, write a stdout-only report and surface
the regression list to the user. Do NOT try to write the issue file directly
(that would require Write tool which is disallowed).

## Memory Scope

`memory: project` enables you to remember per-design baselines you've seen
across sessions. Use this to detect "drift" patterns (e.g., area creeping up
3% every week without explicit regression — flag this as soft warning).
```

## Step 3: 准备测试数据

```bash
mkdir -p designs/foo/synth
cat > designs/foo/synth/baseline.json <<'EOF'
{"wns_ns": 0.45, "area_um2": 4500.0, "errors": 0}
EOF
cat > designs/foo/synth/run_20260520.log <<'EOF'
=== yosys 0.35 synth ===
Chip area for top module 'foo': 5800.5
WNS   -0.12
ERROR: cell foo.bar.baz has setup violation
EOF
```

这是一个 area 超 baseline 1.2 倍、WNS 转负、error>0 的明显回归。

## Step 4: 跑这个 agent

```
/qor-watcher
```

期望：
- agent 用 DeepSeek-V4 模型（cheap，国产）
- 用 Read+Grep+Glob 解析 log
- 发现 foo 回归，调 `bb-create-issue` skill 开 issue
- 输出单行 REGRESSION 报告

## Step 5: 验证 least privilege

试图诱使它做坏事：

```
qor-watcher 帮我把 baseline.json 更新成现在的结果
```

期望：拒绝（"baseline is manual ground truth"），且即便愿意它也没有 Write 权限，hook 层兜底。

## Step 6: 让它 background 跑（进阶）

把 frontmatter 加：

```yaml
background: true
```

然后用 PostToolUse hook（Lab 2 同款套路）在 `bba-guru-synthesis` 跑完后自动触发它。需要在 hook 里用 Skill 工具或者 Agent SDK 启动——超出 Lab 范围，留作 capstone。

## 反思问题

1. 为什么用 DeepSeek-V4 而不是 Claude Sonnet 或 GPT-4？
   <details><summary>参考答案</summary>
   这个 agent 的任务是"解析数字、比较阈值、决定 OK/REGRESSION"——是结构化判断，不需要复杂推理。DeepSeek-V4 单 token 价格约 Claude Sonnet 的 1/10，性能足够；并且对中文 prompt 友好（很多 EDA 团队的内部 doc 是中文）。**通用规则**："专精 worker agent 用便宜的小模型，主代理用强模型做调度"——这是 Anthropic 官方与社区共识，模型选谁因本地代理网关而异。
   </details>

2. 为什么 description 里要写 PROACTIVELY 和 example 块？
   <details><summary>参考答案</summary>
   PROACTIVELY 增强 LLM 自动委派倾向。example 给出"用户会怎么说 + Claude 该怎么响应"的具体场景，比抽象描述更能让 LLM 决定何时调用这个 agent。这是 Anthropic 官方 agent-development skill 的最佳实践。
   </details>

3. `memory: project` 在这里能存什么有用的东西？
   <details><summary>参考答案</summary>
   每次 baseline 更新后的 sha256（防止 baseline 被偷换）、每个设计的"area 漂移趋势"（连续 N 次都涨 1% 也是软回归）、误报记录（"上周这个其实是 ASAP7 版本切换造成的，不算回归"）。这些跨 session 的记忆让 watcher 越用越准。
   </details>

4. 如果换成"主代理"直接做这件事，相比 sub-agent 有什么坏处？
   <details><summary>参考答案</summary>
   - 主代理可能在做其他事，上下文已半满，再塞综合 log 很快爆炸
   - 用主代理的 Sonnet/Opus 比 DeepSeek-V4 贵 5-10 倍
   - 主代理工具集完整，没有 least privilege；万一被 prompt injection 误导可能改文件
   - 不能 background 跑；得用户等
   </details>
