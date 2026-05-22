# Lab 1: 写一个 Skill — `/check-clock-domain`

> **目标**：写一个 skill，扫描 SystemVerilog 文件，统计 `always @(posedge ...)` 出现的时钟信号，输出 markdown 表格。用于 CDC 风险初筛。
>
> **预计时长**：30 分钟
>
> **学到什么**：
> - SKILL.md 的 frontmatter 与目录布局
> - Progressive disclosure：何时把内容放主体、何时放 `references/`
> - skill 如何接收参数（`$ARGUMENTS`）
> - 如何让 LLM 既能"自动"调用又能"用户手动"调用

## 前置

- 当前目录是 `/home/lxx/wrk/Babel`
- 已读完主报告第 2.3 节（Skill 概念）

## Step 1: 创建目录

```bash
mkdir -p .claude/skills/check-clock-domain
```

## Step 2: 写 SKILL.md

新建 `.claude/skills/check-clock-domain/SKILL.md`��

```markdown
---
name: check-clock-domain
description: "扫描 SystemVerilog 文件统计 always 块使用的时钟信号，输出 markdown 表格用于 CDC 风险初筛。触发：用户说『检查时钟域』『有几个时钟』『CDC 初筛』，或提到 RTL 文件路径并问 clock 数量。"
---

# check-clock-domain

## 用途

快速识别 RTL 中的所有时钟信号，统计每个时钟的 `always @(posedge ...)` 出现次数，用于：
- CDC 风险初筛（>1 个时钟就有跨域可能）
- 综合前的时钟规划核对
- 设计 review 时的快速分布检查

## 何时使用

- 用户提供一个 RTL 文件或目录，问『几个时钟』『时钟域』『CDC 风险』
- 综合前的 sanity check
- **不**适用于：精确的 CDC 违例检查（请用 bb-check-cdc）

## 输入

`$ARGUMENTS` 第一个 token 是文件路径或 glob 模式。例如：
- `designs/foo/rtl/top.sv`
- `designs/foo/rtl/**/*.sv`

## 工作流程

1. 解析 `$ARGUMENTS` 取出路径/glob。
2. 用 `Bash` 执行：
   ```bash
   grep -hoP '@\s*\(\s*posedge\s+\K\w+' <files> | sort | uniq -c | sort -rn
   ```
3. 把结果整理成 markdown 表格。
4. 如果时钟数 > 1，附加一段警告："存在 N 个时钟域，跨域信号需 2ff-sync。"

## 输出格式

```markdown
## 时钟域扫描结果：<file/glob>

| 时钟信号 | always 块数量 |
|---------|--------------|
| clk_100m | 12 |
| clk_apb  | 5 |

总计 **2** 个时钟域。⚠️ 存在跨时钟域可能，请确认所有跨域信号已加 2ff-sync。
```

## 错误处理

| 场景 | 处理 |
|------|------|
| 路径不存在 | 报错：`File not found: <path>` 并退出，不要 fallback |
| grep 无匹配 | 输出 `未检测到 posedge clock`，仍然成功退出 |
| 多个 glob 无文件 | 同上 |

## 检查清单（验收）

- [ ] description 含具体触发关键词
- [ ] 输入参数明确（$ARGUMENTS 第一个 token）
- [ ] 输出 markdown 可被 chat 直接渲染
- [ ] >1 时钟域有醒目警告
```

## Step 3: 测试

在 Claude Code 里直接试：

```
/check-clock-domain designs/tinystories_npu/rtl/**/*.sv
```

或让 LLM 自动调用：

```
帮我看看 designs/tinystories_npu/rtl/M09_AttentionUnit.sv 有几个时钟
```

LLM 应该会基于 description 中的"检查时钟域 / 有几个时钟"自动触发这个 skill。

## Step 4: 进阶（选做）

把 grep 命令封装到 `scripts/scan_clocks.sh`，让 SKILL.md 主体更短：

```bash
mkdir scripts
cat > scripts/scan_clocks.sh <<'EOF'
#!/usr/bin/env bash
set -eu
files="$*"
[ -z "$files" ] && { echo "Usage: scan_clocks.sh <files...>" >&2; exit 1; }
echo "时钟信号 always_blocks"
grep -hoP '@\s*\(\s*posedge\s+\K\w+' $files 2>/dev/null | sort | uniq -c | sort -rn |
  awk '{printf "%s %s\n", $2, $1}'
EOF
chmod +x scripts/scan_clocks.sh
```

然后在 SKILL.md 主体里只写：

```
2. 执行：`bash scripts/scan_clocks.sh <files>`
```

这是 progressive disclosure 的典型应用——把"实现细节"放进 scripts/ 子文件，SKILL.md 只描述意图与流程。

## 反思问题（讨论）

1. 这个 skill 应该设 `disable-model-invocation: true` 吗？为什么？
   <details><summary>参考答案</summary>
   不应该。它是只��、幂等、无副作用的诊断工具。让 LLM 在 RTL 讨论时自动调用是有益的。
   </details>

2. 如果 RTL 用了 `always_ff @(posedge clk_a or negedge rst_n)`，当前的 grep 还能识别 clk_a 吗？
   <details><summary>参考答案</summary>
   能。`@\s*\(\s*posedge\s+\K\w+` 只匹配第一个 posedge 后的标识符。但 `negedge` 时钟会被漏掉——属于 known limitation，应在 SKILL.md 的"何时不适用"中明示。
   </details>

3. 如果用户传的是 module name 而不是文件路径，skill 该怎么响应？
   <details><summary>参考答案</summary>
   错误退出更安全。猜测路径容易踩坑（用户可能写错）。"Don't guess, escalate"——这是 Babel 项目的硬规则。
   </details>
