## References

> 引用格式：[Source]. (Year). Title. URL/Path. (最后访问 2026-05-20 北京时间)

### 官方文档（一手源）
1. Anthropic. (2026). *Create custom subagents*. https://docs.claude.com/en/docs/claude-code/sub-agents [Source: Exa fetch, 227KB; mirror at code.claude.com/docs/en/sub-agents.md]
2. Anthropic. (2026). *Extend Claude with skills*. https://docs.claude.com/en/docs/claude-code/skills [Source: Exa fetch]
3. Anthropic. (2026). *Hooks reference*. https://docs.claude.com/en/docs/claude-code/hooks [Source: Exa fetch]
4. Anthropic. (2026). *Settings*. https://docs.claude.com/en/docs/claude-code/settings
5. Anthropic. (2026). *Slash commands*. https://docs.claude.com/en/docs/claude-code/slash-commands
6. Anthropic. (2026). *Agent Skills overview*. https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

### Anthropic Engineering（一手）
7. Anthropic Engineering. (2025-12-11). *Claude Code power user customization: How to configure hooks*. https://claude.com/blog/how-to-configure-hooks

### Anthropic 官方 GitHub（一手代码）
8. `anthropics/claude-code`. *plugin-dev/skills/agent-development/SKILL.md*. https://github.com/anthropics/claude-code (via Context7 /anthropics/claude-code)
9. `anthropics/claude-code`. *plugin-dev/skills/hook-development/SKILL.md*. https://github.com/anthropics/claude-code
10. `anthropics/claude-code`. *plugin-dev/skills/skill-development/SKILL.md*. https://github.com/anthropics/claude-code

### 二手 / 社区（用于交叉验证）
11. JuanMaPerals. *claude-code-best-practice/best-practice/claude-subagents.md*. https://github.com/JuanMaPerals/claude-code-best-practice/blob/main/best-practice/claude-subagents.md
12. The Claude Codex. (2026-03-10). *Creating a sub-agent*. https://claude-codex.fr/en/agents/create-subagent/
13. Tinker AI. *Claude Code hooks: where they fire, what they can read, and what they can't*. https://tinker-ai.com/guides/claude-code-hooks-system/
14. AgentPatterns.ai. *Claude Code Sub-Agents for Delegating Complex Tasks*. https://agentpatterns.ai/tools/claude/sub-agents/
15. claudelint. *Hooks Configuration schema*. https://claudelint.com/api/schemas/hooks
16. GitHub Issue. (2025-12-20). *Skills consume full token count at startup instead of progressive disclosure*. https://github.com/anthropics/claude-code/issues/14882

### 本地范例（实战参考）
17. Babel project. `/home/lxx/wrk/Babel/.claude/agents/bba-architect.md` — 完整 sub-agent 定义示例
18. Babel project. `/home/lxx/wrk/Babel/.claude/agents/bba-guru-rtl.md` — 流水线下游 agent 示例
19. Babel project. `/home/lxx/wrk/Babel/.claude/settings.json` — hooks 注册示例（5 类 hook event）
20. Babel project. `/home/lxx/wrk/Babel/.claude/hooks/bb-hook-validate-bash-cmd.sh` — fail-soft PreToolUse hook
21. Babel project. `/home/lxx/wrk/Babel/.claude/hooks/bb-hook-pipeline-advance.sh` — PostToolUse pipeline advancer

