---
name: babel-data-flow-diagrams
description: Babel 数据流图（system-level + module-level）
type: arch_spec
version: 1.0.0
created: 2026-05-16
related:
  - architecture_specification.md
---

# Babel 数据流图

> Mermaid 格式。System-level（全局视图）、module-level（M-ID 内部）。
> 边标注数据大小、schema 引用、传输介质（state / event / direct）。

---

## 1. System-Level Data Flow

```mermaid
flowchart TD
    user([User])
    spec_json[(spec.json<br/>~10KB)]
    rtl_files[(rtl/*.sv<br/>~80KB + SDC draft)]
    cdc_json[(cdc_report.json<br/>~5KB)]
    netlist[(synth/netlist.v<br/>~500KB + qor.json)]
    tb_files[(tb/*.sv + sim_results/<br/>~200KB + coverage.json)]
    state[(design_state.json<br/>~30KB)]
    events[(events/*.jsonl<br/>append-only)]
    cmem[(claude-mem<br/>跨会话记忆)]

    user -->|/babel-design prompt| M001[M001 babel-spec]
    M001 -->|spec.json| spec_json
    spec_json -->|input schema| M002[M002 babel-rtl]
    M002 -->|rtl_artifact| rtl_files
    rtl_files -->|input schema| M006[M006 babel-cdc]
    M006 -->|cdc_report| cdc_json
    rtl_files & cdc_json -->|synth_input composite| M005[M005 babel-synth]
    M005 -->|synth_report| netlist
    rtl_files & netlist -->|input schemas| M003[M003 babel-test]
    M003 -->|test_report| tb_files

    M001 & M002 & M003 & M005 & M006 -.event append.-> events
    events -.merge.-> M004[M004 babel-coord]
    M004 -->|single writer| state
    state -->|read snapshot| M001 & M002 & M003 & M005 & M006

    M001 & M002 & M003 & M005 & M006 -.experience.-> cmem
    cmem -.recall.-> M001 & M002 & M003 & M005 & M006
```

---

## 2. Spec → RTL 数据流（M001 ↔ M002）

```mermaid
flowchart LR
    prompt[user prompt NL] --> M001
    M001 -->|read| wiki_proto[(wiki/protocols/)]
    M001 -->|read| wiki_cbb[(wiki/cbb/)]
    M001 -->|write| prd[PRD.md]
    M001 -->|write| spec[spec.json<br/>schema: spec.schema]
    spec -->|validated by M201| validate_ok{schema ok?}
    validate_ok -->|yes| M002
    validate_ok -->|no| fix1[fix_request to M001]
    fix1 --> M001

    M002 -->|read CBB| wiki_cbb
    M002 -->|generate| rtl[rtl/*.sv]
    M002 -->|generate| sdc_draft[constraints/*.sdc draft]
    M002 -->|invoke M101 lint| lint_report[lint_report.json]
    lint_report -->|merge| artifact[rtl_artifact 输出]
```

---

## 3. fix_request 闭环数据流

```mermaid
flowchart LR
    M003[M003 babel-test] -->|coverage<95%| evt[event: fix_request P0]
    evt -.append.-> events[(events/*.jsonl)]
    events -.poll.-> M004[M004 babel-coord]
    M004 -->|priority desc, ts asc| sort{仲裁}
    sort -->|target=M002| dispatch[Agent tool: dispatch M002]
    dispatch --> M002[M002 babel-rtl<br/>含 fix_request hint]
    M002 -->|update rtl/*.sv| rtl[(rtl/*.sv)]
    M002 -->|event: signoff| evt2[event: signoff P0]
    evt2 -.append.-> events
    M004 -.read.-> events
    M004 -->|status: resolved| state[(design_state.json)]
    M004 -->|redispatch| M003
```

---

## 4. State 写入数据流（Single Writer）

```mermaid
flowchart TD
    agents[Agents M001-M006] -.append-only.-> elog[(events/*.jsonl)]
    M004[M004 babel-coord] -.poll.-> elog
    M004 -.last offset.-> off[(events/_merged_offset.json)]
    M004 --> sort[sort by priority desc, ts asc]
    sort --> lock{M303 acquire sqlite mutex}
    lock -->|ok| merge[merge into state]
    merge --> backup[atomic rename state to .state_backup/]
    backup --> persist[write new state.json]
    persist --> upoff[update offset.json atomic rename]
    upoff --> release[release lock]
    lock -->|busy| wait[wait / retry]
```

> 提示：crash recovery（v1.1-issue M9）— coord 启动时检测 offset.json mtime vs state.json mtime；
> 若 offset 旧于 state → 重做最后 N 秒事件（事件幂等保证可重做）。

---

## 5. claude-mem 数据流（with fallback）

```mermaid
flowchart LR
    agent[Any Agent] -.experience.-> hook[babel-hook-experience-record]
    hook -->|try| cmem_api[claude-mem API]
    cmem_api -->|ok| cmem_store[(claude-mem store)]
    cmem_api -->|fail| fallback{ADR-A04}
    fallback -->|stateless| warn[stderr warning continue]
    fallback -->|abort| halt[halt + report]

    agent -.recall on start.-> hook2[babel-hook-session-load-memory]
    hook2 --> cmem_api
    cmem_api -->|ok| recall_data[recall to agent context]
    cmem_api -->|fail| empty_recall[empty + warning]
```

---

## 6. Wiki 读取数据流

```mermaid
flowchart LR
    M001 & M002 & M006 -.pretool hook.-> M501[M501 wiki_kb]
    M501 -->|validate frontmatter| hash_check{content_hash match hashes.txt?}
    hash_check -->|ok| serve[serve wiki content]
    hash_check -->|mismatch| violation[write .integrity_violations.log fail-closed]
    violation --> abort[abort agent]
    serve --> agent[agent context]
```

---

## 7. 关联文档

| 路径 | 用途 |
|------|------|
| `architecture_specification.md` | M-ID 详细定义；§9 依赖图 |
| `workflow_diagrams.md` | 时序图（业务流程） |
| `schemas_seed.md` | 每条数据流引用的 schema |
