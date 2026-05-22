## Appendix A. 术语表

| 术语                    | 解释 |
|------------------------|------|
| Agent                  | 一次"LLM + tool 循环"的执行实例 |
| Sub-agent              | 在新 context 里跑的子 agent，主线只看 final result |
| Skill                  | `SKILL.md` 形式的可复用知识/流程包 |
| Slash Command          | 用户用 `/` 触发的命令——新版即"user-invocable skill" |
| Tool                   | LLM 在 turn 中能调用的函数（Read/Bash/...） |
| Hook                   | 在生命周期事件触发的本地脚本 |
| MCP                    | Model Context Protocol，外部 tool 接入协议 |
| Context Window         | 一次 LLM 调用能携带的总 token |
| Progressive Disclosure | Skill 的三级懒加载（metadata / body / resources） |
| Compaction             | 上下文压缩——LLM 总结历史以腾出空间 |
| Handoff                | sub-agent 之间通过 schema-validated artifact 传递工作 |
| Correlation ID         | `sha256(失败 artifact)`，用于 fix iter 计数防抖 |
| Worktree Isolation     | sub-agent 在临时 git worktree 里跑，主仓库不被污染 |
| Blast Radius           | 一个动作影响的范围；越小越安全 |
| Fail-soft / Fail-loud  | 失败时静默通过 vs 大声警告——前者用于不确定，后者用于确定危险 |

