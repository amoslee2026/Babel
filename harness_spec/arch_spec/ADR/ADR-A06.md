---
id: ADR-A06
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H7
---

# ADR-A06 — Multi-Session 全局锁

## Status
Accepted (2026-05-16)

## Context
v1.1-issue H7：design_doc.md §12.3 "MVP 单实例单设计" 仅设计意图，无强制机制。两个 babel 进程同 design_id 会冲突；events 流双写、coord 互相覆盖。

## Decision
1. **锁文件**：`${OUTPUT_DIR}/state/.babel_session.lock`（与 sqlite state lock 互补）
2. **内容**：JSON `{pid, acquired_at_iso8601, design_id, host, babel_version}`
3. **acquire 协议**：
   - 启动时 try-write lock；如果文件已存在：
     - `kill -0 <pid>` 检查存活
     - 存活 → 拒绝启动 + 友好错误（含 PID / 启动时间 / 释放指引）
     - 不存活 + lock mtime > 10min → 抢占 + 警告
4. **release**：正常退出 + Python atexit + 异常处理器多重保险
5. **scope**：同 host + 同 design_id 才冲突；跨 host 通过 host 字段识别（NFS 共享场景）
6. 实现归属 M303 session_lock

## Trade-offs
| 维度 | PID file (本设计) | sqlite global lock | systemd unit | filesystem flag |
|------|------------------|---------------------|--------------|-----------------|
| NFS 支持 | ✅ (内含 host) | ✅ | ❌（per host） | 部分 |
| 崩溃恢复 | ✅ (10min 抢占) | ✅ | ✅ | ❌ |
| 实现成本 | 低 | 中 | 高（systemd 依赖） | 低 |
| **选择** | ✅ | (overkill) | ❌ | ❌ |

## Consequences
- (+) 防误启第二实例造成 state corruption
- (+) 用户友好错误：明确 PID + 解决方式
- (-) 跨 host 同 design_id 仍需要用户协调（多用户共享盘场景）
- (-) 10min 抢占阈值是经验值，可配置

## Affected
- `architecture_specification.md` M303 session_lock
- `user_manual.md` §8 Multi-session
- `workflow_diagrams.md` §5
