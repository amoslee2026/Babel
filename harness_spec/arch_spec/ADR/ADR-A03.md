---
id: ADR-A03
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H3
---

# ADR-A03 — State Lock Backend = sqlite (NFS-Safe)

## Status
Accepted (2026-05-16)

## Context
v1.1-issue H3：design_doc.md §13.2 使用 `flock(state.json)`。chip 团队常用 NFS 共享 home，flock 在 NFS（特别是 NFSv3）上不可靠 — 锁可能被忽略或丢失，导致并发写损坏 state。

## Decision
1. State 互斥锁后端：**sqlite mutex**（POSIX advisory lock 在 sqlite 实现层处理 NFS 情况，WAL 模式更稳健）
2. lock 表 `__babel_state_lock`：`pid INTEGER, acquired_at TEXT, design_id TEXT, lock_token TEXT`
3. 仍保留 `lock_token` (UUIDv7) 在 state.json 内做乐观锁，二者互补
4. 配置项 `babel_config.state_lock_backend: sqlite | flock`，flock 仅本机 SSD 调试使用
5. Phase 1 实施时新增 `state.lock.sqlite` 文件，与 `state.json` 同目录

## Trade-offs
| 维度 | flock | sqlite mutex | etcd/redis |
|------|-------|--------------|------------|
| NFS 安全 | ❌ | ✅ (WAL+busy_timeout) | ✅ |
| 依赖 | 无 | sqlite3 (Python stdlib) | 外部服务 |
| 性能 | 极快 | ~ms | ~ms 含网络 |
| 部署 | 单机 | 单机 | 集群 |
| **选择** | (debug only) | ✅ | (overkill) |

## Consequences
- (+) NFS 部署可行（学校共享盘场景）
- (+) Python stdlib，无新依赖
- (-) 每次 lock acquire 多 ~1ms sqlite 开销
- (-) sqlite 数据库文件需 atexit cleanup

## Affected
- `architecture_specification.md` M301 state_manager
- Phase 1 实施：`state.lock.sqlite` 持久化 + busy_timeout 配置
