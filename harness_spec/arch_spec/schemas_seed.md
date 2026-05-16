---
name: babel-schemas-seed
description: 所有 JSON Schema 的字段骨架（v1.1-issue H2 解决）
type: arch_spec
version: 1.0.0
created: 2026-05-16
schema_standard: JSON Schema Draft 2020-12
location_phase1: harness_spec/arch_spec/schemas/
related:
  - architecture_specification.md
  - functional_specification.md
  - ADR/ADR-A02.md
---

# Schema Seed

> Phase 1 实施时，每个 schema 落地为独立 `.schema.json` 文件，位于 `harness_spec/arch_spec/schemas/`。
> 本文档定义字段骨架（types + constraints + descriptions），消除 v1.1-issue **H2**（schemas 全部 TBD）。
> 字段骨架以 YAML-ish 简化表达，实际 JSON Schema 由实施时落地。

---

## 索引

| Schema | 用途 | 关联 F00X / M00X |
|--------|------|------------------|
| idea.schema.json | 用户初始需求（自然语言 + 元数据） | F001 |
| spec.schema.json | spec-planner 输出，rtl-coder 输入 | F001, F002 |
| rtl_artifact.schema.json | rtl-coder 输出 | F002, F004, F005 |
| cdc_report.schema.json | cdc-guard 输出 | F004, F005 |
| synth_input.schema.json | synth composite input (rtl_artifact + cdc_report) | F005 (v1.1-issue C2 ABI 落地) |
| synth_report.schema.json | synth 输出 | F005, F006 |
| test_report.schema.json | test 输出 | F006 |
| event.schema.json | agent → coord 事件 | F007 |
| design_state.schema.json | 全局共享状态 | F007 |
| fix_request.schema.json | 修复请求 | F008 |

---

## 1. idea.schema.json

```yaml
$schema: https://json-schema.org/draft/2020-12/schema
$id: babel://schemas/idea
title: Idea Input
type: object
required: [design_name, prompt, requested_at]
properties:
  design_name:
    type: string
    pattern: ^[a-z][a-z0-9_]{1,30}$
    description: 小写下划线，作为目录名
  prompt:
    type: string
    minLength: 20
    maxLength: 4000
    description: 用户自然语言描述
  requested_at:
    type: string
    format: date-time
  user_constraints:
    type: object
    properties:
      target_freq_mhz: { type: number, minimum: 1, maximum: 5000 }
      target_area_um2: { type: number, minimum: 100 }
      target_power_mw: { type: number, minimum: 0 }
      max_iterations:  { type: integer, minimum: 1, maximum: 20, default: 3 }
  tech_node:
    type: string
    enum: [asap7]
    default: asap7
additionalProperties: false
```

---

## 2. spec.schema.json

```yaml
$id: babel://schemas/spec
title: Babel Specification (spec-planner output)
type: object
required: [design_id, top_module, interfaces, behavioral_summary]
properties:
  design_id:
    type: string
    pattern: ^design_[0-9A-HJKMNP-TV-Z]{26}$   # UUIDv7 (Crockford base32 ULID)
  top_module:
    type: string
    pattern: ^[a-z][a-z0-9_]+$
  interfaces:
    type: array
    items:
      type: object
      required: [name, protocol, direction, port_list]
      properties:
        name: { type: string }
        protocol: { type: string, enum: [axi4-lite, axi4, uart, spi, i2c, ahb, apb, ucie, custom] }
        direction: { type: string, enum: [slave, master, bidirectional] }
        port_list:
          type: array
          items:
            type: object
            required: [name, width, dir]
            properties:
              name:  { type: string }
              width: { type: integer, minimum: 1 }
              dir:   { type: string, enum: [in, out, inout] }
  clock_domains:
    type: array
    items:
      type: object
      properties:
        name:       { type: string }
        freq_mhz:   { type: number, minimum: 1 }
        reset_kind: { type: string, enum: [sync, async] }
  cbb_dependencies:
    type: array
    items:
      type: object
      properties:
        wiki_path: { type: string, pattern: ^wiki/cbb/[a-z0-9_-]+\.md$ }
        instance_count: { type: integer, minimum: 1 }
  behavioral_summary:
    type: string
    description: 行为级描述（NL，给 rtl-coder 作为上下文）
  signoff:
    type: boolean
    default: false
additionalProperties: false
```

---

## 3. rtl_artifact.schema.json

```yaml
$id: babel://schemas/rtl_artifact
title: RTL Artifact
type: object
required: [design_id, files, sdc_draft_path, lint_clean]
properties:
  design_id: { $ref: babel://schemas/spec#/properties/design_id }
  files:
    type: array
    minItems: 1
    items:
      type: object
      required: [path, sha256, language]
      properties:
        path:     { type: string, pattern: \.s?v$ }
        sha256:   { type: string, pattern: ^[0-9a-f]{64}$ }
        language: { type: string, enum: [verilog, systemverilog] }
        loc:      { type: integer, minimum: 1 }
  sdc_draft_path:
    type: string
    pattern: \.sdc$
  lint_clean:
    type: boolean
  lint_report_path:
    type: string
    pattern: lint_report\.json$
  cbb_instances:
    type: array
    items:
      type: object
      properties:
        cbb_wiki_path: { type: string }
        instance_name: { type: string }
        port_bindings: { type: object }
  signoff:
    type: boolean
    default: false
```

---

## 4. cdc_report.schema.json

```yaml
$id: babel://schemas/cdc_report
title: CDC / RDC Report
type: object
required: [design_id, scanned_at, violations, signoff]
properties:
  design_id: { $ref: babel://schemas/spec#/properties/design_id }
  scanned_at: { type: string, format: date-time }
  clock_domains:
    type: array
    items: { type: string }
  crossings:
    type: array
    items:
      type: object
      required: [src_clk, dst_clk, signal, synchronizer_kind]
      properties:
        src_clk:           { type: string }
        dst_clk:           { type: string }
        signal:            { type: string }
        synchronizer_kind: { type: string, enum: [2ff_sync, mux_handshake, async_fifo, none] }
        waived:            { type: boolean, default: false }
        waiver_adr:        { type: string }   # 若 waived=true 必须给 ADR 引用
  violations:
    type: array
    items:
      type: object
      properties:
        rule:     { type: string }
        location: { type: string }
        severity: { type: string, enum: [error, warning, info] }
  signoff:
    type: boolean
    default: false
```

---

## 5. synth_input.schema.json（解决 v1.1-issue C2）

```yaml
$id: babel://schemas/synth_input
title: Synthesis Composite Input
description: M005 babel-synth 的多 upstream 合并输入
type: object
required: [rtl_artifact, cdc_report]
properties:
  rtl_artifact:
    $ref: babel://schemas/rtl_artifact
  cdc_report:
    $ref: babel://schemas/cdc_report
  sdc_override:
    type: string
    description: 可选 SDC override 路径
additionalProperties: false
```

> 上下游约定（C2 落地）：M005 启动期 hook 把 rtl_artifact + cdc_report 打包为 synth_input，
> 再以单 schema 校验整体（vs 多 schema 各自校验）。

---

## 6. synth_report.schema.json

```yaml
$id: babel://schemas/synth_report
title: Synthesis Report
type: object
required: [design_id, netlist_path, qor, signoff]
properties:
  design_id: { $ref: babel://schemas/spec#/properties/design_id }
  netlist_path: { type: string, pattern: synth/netlist\.v$ }
  sdc_final_path: { type: string, pattern: \.sdc$ }
  qor:
    type: object
    required: [wns_ns, area_um2, cell_count]
    properties:
      wns_ns:       { type: number, description: 负值表示违例 }
      tns_ns:       { type: number }
      area_um2:     { type: number, minimum: 0 }
      cell_count:   { type: integer, minimum: 0 }
      power_est_mw: { type: number, minimum: 0 }
  yosys_log_path: { type: string }
  signoff:
    type: boolean
    default: false
```

---

## 7. test_report.schema.json

```yaml
$id: babel://schemas/test_report
title: Test Report
type: object
required: [design_id, coverage, sim_outcomes, signoff]
properties:
  design_id: { $ref: babel://schemas/spec#/properties/design_id }
  testbench_path: { type: string }
  coverage:
    type: object
    required: [functional_pct, code_pct]
    properties:
      functional_pct: { type: number, minimum: 0, maximum: 100 }
      code_pct:       { type: number, minimum: 0, maximum: 100 }
      uncovered_bins:
        type: array
        items: { type: string }
  sim_outcomes:
    type: array
    items:
      type: object
      properties:
        seed:     { type: integer }
        passed:   { type: boolean }
        cycles:   { type: integer }
        failure:  { type: string }   # 仅 passed=false 时
  signoff:
    type: boolean
    default: false
```

---

## 8. event.schema.json

```yaml
$id: babel://schemas/event
title: Babel Event (agent → coordinator append-only)
type: object
required: [event_id, ts, agent, kind, priority]
properties:
  event_id:
    type: string
    pattern: ^evt_[0-9A-HJKMNP-TV-Z]{26}$
  ts: { type: string, format: date-time }
  agent:
    type: string
    enum: [babel-spec, babel-rtl, babel-test, babel-coord, babel-synth, babel-cdc]
  kind:
    type: string
    enum:
      - signoff
      - fix_request
      - state_update
      - schema_violation
      - max_iter_reached
      - manual_override_detected
      - heartbeat
  priority:
    type: string
    enum: [P0, P1, P2]
    default: P1
  payload:
    type: object   # 由 kind 决定结构（oneOf 校验，Phase 1 实施时落地）
  schema_refs:
    type: array
    items: { type: string }
    description: 该 event 触及的 schema 路径（用于追踪）
```

---

## 9. design_state.schema.json

```yaml
$id: babel://schemas/design_state
title: Babel Design State (single-writer)
type: object
required: [format_version, design_id, babel_session_id, last_writer]
properties:
  format_version: { const: "1.1" }
  design_name: { type: string }
  design_id: { $ref: babel://schemas/spec#/properties/design_id }
  babel_session_id:
    type: string
    pattern: ^[0-9A-HJKMNP-TV-Z]{26}$
  lock_token: { type: string }
  last_writer:
    type: string
    enum: [babel-coord, user, migration_script]
  created_at: { type: string, format: date-time }
  updated_at: { type: string, format: date-time }
  cross_domain_iteration_count:
    type: integer
    minimum: 0
  babel_config:
    type: object
    properties:
      max_cross_domain_iterations: { type: integer, minimum: 1, default: 3 }
      on_max_iter_reached:
        type: string
        enum: [halt, escalate_user, force_signoff]
        default: escalate_user
      history_capacity: { type: integer, minimum: 50, default: 200 }
  pending_approval:
    oneOf:
      - { type: "null" }
      - type: object
        required: [reason, options]
        properties:
          reason:  { type: string }
          options: { type: array, items: { type: string } }
  spec:         { type: object }   # full embedding 或 $ref to spec.schema
  rtl:          { type: object }   # rtl_artifact 摘要 (lint_clean, signoff, files)
  cdc_status:   { type: object }
  synth_status: { type: object }
  test_status:  { type: object }
  babel_fix_requests:
    type: array
    items: { $ref: babel://schemas/fix_request }
  archive_fix_requests:
    type: array
    items: { $ref: babel://schemas/fix_request }
  history:
    type: array
    maxItems: 200   # 由 babel_config.history_capacity 控制，schema 留 hard cap
    items:
      type: object
      properties:
        ts:       { type: string, format: date-time }
        event_id: { type: string }
        kind:     { type: string }
        pinned:   { type: boolean, default: false }   # v1.1-issue H6: priority-pin
```

---

## 10. fix_request.schema.json

```yaml
$id: babel://schemas/fix_request
title: Fix Request
type: object
required: [id, priority, status, created_at, created_by, summary]
properties:
  id:
    type: string
    pattern: ^bfr_[0-9A-HJKMNP-TV-Z]{26}$
  priority:
    type: string
    enum: [P0, P1, P2]
  status:
    type: string
    enum: [open, in_progress, resolved, wontfix, escalated]
    default: open
  created_at: { type: string, format: date-time }
  created_by:
    type: string
    enum: [babel-test, babel-cdc, babel-synth, babel-coord, user]
  target_agent:
    type: string
    enum: [babel-spec, babel-rtl, babel-test, babel-synth, babel-cdc]
  summary: { type: string, minLength: 10 }
  # 以下 P1 字段（Phase 3 启用，v1.1-issue L3 落地）
  failure_class:
    type: string
    enum: [functional, timing, coverage, cdc, synthesis, lint, other]
  suspected_artifact:
    type: object
    properties:
      module:     { type: string }
      file:       { type: string }
      line_range: { type: array, items: { type: integer }, minItems: 2, maxItems: 2 }
  expected_behavior: { type: string }
  observed_behavior: { type: string }
  resolution:
    type: object
    properties:
      diff_summary:  { type: string }
      files_changed: { type: array, items: { type: string } }
      resolved_at:   { type: string, format: date-time }
  history:
    type: array
    items: { type: object }
```

---

## 11. Phase 1 实施 checklist

- [ ] 创建 `harness_spec/arch_spec/schemas/` 目录
- [ ] 把上述 10 个 schema 转为独立 `.schema.json` 文件
- [ ] `jsonschema-cli validate` 互验通过
- [ ] 实施 `schemas/sample_*.json` 样例（每 schema 至少 1 个 valid + 1 个 invalid）
- [ ] M201 schema_validator 包装 jsonschema CLI，集成进 hooks
- [ ] 文档化 schema 演进规则（向后兼容、format_version bump 流程）
