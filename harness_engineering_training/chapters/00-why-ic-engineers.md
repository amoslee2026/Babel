## 第 0 章 · 为什么 IC 工程师要学 Harness Engineering

| 传统脚本流（Makefile / TCL） | Agent Harness |
|------------------------------|---------------|
| 确定输入 → 确定输出           | 自然语言意图 → LLM 推理 + tool 调用 → 工程产物 |
| 失败靠 `exit 1`               | 失败有多种形态：错答案、空输出、错路径、空转 |
| 边界靠权限位/目录              | 边界靠 hook + permission + sub-agent isolation |
| 调试看 stderr                  | 调试看 transcript + tool log + hook log |
| 复用靠 include                 | 复用靠 skill / sub-agent / MCP server |

**Harness Engineering** 就是把"不确定的 LLM 行为"放进"确定的工程外壳"里——给它**手**（tools）、**眼**（context）、**护栏**（hooks）、**专家分工**（sub-agents）、**可复用知识**（skills）。

EDA 流程为什么尤其需要这个？

- **代价高**：综合一次几十分钟，PD 一次几小时；agent 走错路成本巨大。
- **签核严格**：DRC/LVS/timing 任何一条违例就报废，必须**门禁化**而非"事后审查"。
- **跨工具异构**：Yosys / Verilator / OpenSTA / Magic 输入输出格式各异，需要适配层。
- **可恢复性是硬约束**：芯片设计文件不允许被 `rm` 误删——hook 必须把这条护栏钉死。

