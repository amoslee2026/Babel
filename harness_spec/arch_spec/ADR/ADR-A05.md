---
id: ADR-A05
status: Accepted
date: 2026-05-16
resolves: v1.1-issue H6
---

# ADR-A05 — History Eviction Policy = FIFO + Priority-Pin

## Status
Accepted (2026-05-16)

## Context
v1.1-issue H6：design_state.json 含 `history: []` 与 `history_capacity: 200` ring buffer 上限，但未定义 eviction 策略（FIFO? LRU? importance-weighted?）。直接 FIFO 会丢失关键事件（如 max_iter_reached, manual_override）。

## Decision
1. 默认策略：**FIFO**（先入先出）
2. 增强：事件可标记 `pinned: true`，pinned 事件不参与 eviction
3. 自动 pin 的事件类型（由 M004 写入时打标）：
   - `max_iter_reached`
   - `manual_override_detected`
   - `signoff`（每 phase 一条）
   - `state_schema_violation`
4. Cap：pinned 事件上限 = capacity / 4（50 @ capacity=200），超出则按 ts 最旧 pinned 转为非 pinned
5. event schema 增 `pinned: boolean default false` 字段

## Trade-offs
| 维度 | 纯 FIFO | LRU | FIFO + pin |
|------|---------|-----|-----------|
| 实现复杂度 | 低 | 中 | 低 |
| 关键事件保留 | ❌ | 部分 | ✅ |
| 内存占用 | 固定 | 固定 | 固定 |
| **选择** | ❌ | ❌ | ✅ |

## Consequences
- (+) max_iter / manual override 不会被覆盖
- (+) 用户可手动 pin 任意事件（通过 event payload）
- (-) 极端长会话下 pinned 满 → 旧 pinned 转非 pinned 时丢失，需文档警示
- (-) history 含 pinned/非 pinned 两类，过滤查询需注意

## Affected
- `schemas_seed.md` design_state.schema / event.schema 增 `pinned` 字段
- `architecture_specification.md` M301 history_eviction 配置
