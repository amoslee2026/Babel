---
id: ADR-A06
status: Accepted (v2)
date: 2026-05-16
resolves: Multi-Session 冲突
---

# ADR-A06 — Multi-Session 锁 (Filesystem-based PID Lock)

## Status
Accepted (2026-05-16, arch_spec v2)

## Context
v1.3 design_doc §12.3 / §13.3 要求防止两个 babel 进程同时操作同 design_id。
sequential pipeline 本身就只允许单 agent 同时跑，但仍需阻拦用户误启第二实例。

## Decision
- **锁文件**: `designs/<design_id>/.babel_session.lock`
- **内容**: JSON `{ pid, acquired_at_iso8601, design_id, host }`
- **acquire 协议**:
  1. 启动 try-write 锁文件
  2. 已存在 → check `kill -0 <pid>`
     - 存活 → 拒绝启动 + 友好错误（含 PID / 启动时间 / 释放指引）
     - 不存活 + lock mtime > 10min → 抢占 + 警告
- **release**: 正常退出 + Python atexit + 异常处理器三重保险
- **scope**: 同 host + 同 design_id 才冲突；跨 host 通过 host 字段识别（NFS 共享盘）

## Trade-offs
| 维度 | filesystem PID lock | sqlite global | systemd unit |
|------|---------------------|---------------|--------------|
| NFS 支持 | ✅ (含 host 字段) | ✅ | ❌ |
| 崩溃恢复 | ✅ (10min 抢占) | ✅ | ✅ |
| 实现成本 | 低 | 中 | 高 |
| **选择** | ✅ | (overkill) | ❌ |

## Consequences
- (+) 防误启第二实例
- (+) 用户友好错误（PID + 解锁方式）
- (-) 跨 host 同 design_id 仍需用户协调（多用户共享盘）
- (-) 10min 抢占阈值是经验值，可配置

## Affected
- M303 session_lock
- `user_manual.md` §8
- `workflow_diagrams.md` §5
