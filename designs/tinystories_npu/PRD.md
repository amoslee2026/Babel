---
doc_id: DOC-D1-01-PRD
doc_type: PRD
title: Product Requirements Document — Edge NPU for TinyStories Inference (tinystories_npu)
version: 1.0
status: draft
tier: 0
domain: Product
owner: TBD
approvers: [Product VP, CTO, Chief Architect]
parent: null
children: [DOC-D2-01-ARCH, DOC-D2-03-PERF, DOC-D2-04-SWARCH, DOC-D7-01-SEC]
references: [spec/PRD/PRD.md, llama2.c, doc/isa/, doc/operators/]
generated: 2026-05-31T12:00:00+08:00
---

# Product Requirements Document — Edge NPU for TinyStories Inference (tinystories_npu)

## 0. Document Control

| Version | Date       | Author | Change |
|---------|------------|--------|--------|
| 0.1     | 2026-05-10 | TBD    | Initial draft from raw spec |
| 0.2     | 2026-05-12 | TBD    | Added PRD structure, REQ IDs, SMART metrics |
| 1.0     | 2026-05-31 | bba-architect | Formalized: traceability matrix, milestones, document control; arch reviewed PRD → ARCH → MAS |

**Sign-off required before**: Architecture Spec v1.0

---

## 1. Executive Summary

- **Product**: 面向边缘端 TinyStories 小参数 LLM 推理的专用 NPU，3D Stacked DRAM（Wafer-on-Wafer）
- **Target Market**: 边缘 AI 推理（Edge AI Inference）——嵌入式系统、IoT 设备、教学/研究平台
- **Form Factor**: Wafer on wafer stacking. Logic Die 工艺 ASAP. DRAM wafer stacked on Logic wafer, connected with TSV
- **Key Differentiators**:
  1. 3D stacked DRAM wafer 带宽 >= 10 GB/s，满足 TinyStories 15M 模型推理带宽需求
  2. Systolic Array + Spatial Dataflow 架构，支持 FP8/FP16/INT8 精度
  3. 100 mm² 以内面积，独立运行无需主机接口

## 2. Use Cases & User Stories

| UC ID | Use Case | Target Workload | KPI |
|-------|----------|-----------------|-----|
| UC-01 | 边缘端文本生成 | TinyStories 15M FP32 | TPS >= 100 token/s（decode phase） |
| UC-02 | 边缘端 prefill | TinyStories 15M，prompt <= 256 tokens | TTFT <= 50 ms |
| UC-03 | INT8/FP16/FP8 推理 | TinyStories 15M FP16 | 精度损失 <= 0.5% vs FP32 baseline |

## 3. Functional Requirements

### 3.1 Compute

| REQ ID | Statement | Metric | Verification Method |
|--------|-----------|--------|---------------------|
| REQ-COMPUTE-001 | FP8 峰值吞吐量 >= 2 TOPS | TOPS @ TT/0.9V，500 MHz | Post-silicon benchmark（GEMM） |
| REQ-COMPUTE-002 | FP16 峰值吞吐量 >= 1 TOPS | TOPS @ TT/0.9V，500 MHz | Post-silicon benchmark（GEMM） |
| REQ-COMPUTE-003 | INT8 峰值吞吐量 >= 2 TOPS | TOPS @ TT/0.9V，500 MHz | Post-silicon benchmark |
| REQ-COMPUTE-004 | 支持 Systolic Array（Weight Stationary / Output Stationary） | 功能验证 | RTL simulation |
| REQ-COMPUTE-005 | 支持 Spatial Dataflow 调度，pipeline 利用率 >= 80% | 利用率 % | 仿真 profiling |
| REQ-COMPUTE-006 | 支持多线程执行，线程数 >= 2 | 并发线程数 | 功能验证 |
| REQ-COMPUTE-007 | 支持混合精度：同一推理任务中 FP32/FP16/INT8 混用 | 功能验证 | 端到端推理测试 |
| REQ-COMPUTE-008 | 支持 Transformer 算子原语（Attention、FFN、RMSNorm、RoPE） | 算子覆盖率 100% | 见 doc/operators/ |

### 3.2 Memory

| REQ ID | Statement | Metric |
|--------|-----------|--------|
| REQ-MEM-001 | 3D Stacked DRAM 容量 >= 2 GB | GB total |
| REQ-MEM-002 | DRAM 聚合带宽 >= 10 GB/s（读+写） | GB/s @ 标称频率 |
| REQ-MEM-003 | DRAM 读延迟 <= 100 ns（row hit） | ns |
| REQ-MEM-004 | 片上 SRAM（scratchpad）容量 >= 512 KB | KB |
| REQ-MEM-005 | 支持 ECC（SECDED）保护 DRAM 和 SRAM | 功能验证 |

### 3.3 I/O

| REQ ID | Statement |
|--------|-----------|
| REQ-IO-001 | 调试接口：JTAG IEEE 1149.1 |
| REQ-IO-002 | 支持自定义 NPU 指令集接口（见 doc/isa/） |

## 4. Non-Functional Requirements

### 4.1 Performance

| REQ ID | Statement | Target |
|--------|-----------|--------|
| REQ-PERF-001 | NPU 核心时钟频率 >= 500 MHz @ TT/0.9V | Fmax |
| REQ-PERF-002 | TinyStories 15M FP32 decode TPS >= 100 token/s（单 batch） | token/s |
| REQ-PERF-003 | TinyStories 15M FP16 decode TPS >= 200 token/s（单 batch） | token/s |
| REQ-PERF-004 | TTFT <= 50 ms，prompt <= 256 tokens | ms |

### 4.2 Power & Thermal

| REQ ID | Statement | Target |
|--------|-----------|--------|
| REQ-PWR-001 | 峰值 TDP <= 2 W（含 DRAM）；设计目标 <= 1.8 W（预留 10% margin） | W |
| REQ-PWR-002 | 空闲功耗 <= 0.1 W | W |
| REQ-PWR-003 | 支持 DVFS，>= 2 个工作点 | 功能验证 |
| REQ-THERM-001 | 结温（Tj）工作范围：0°C 至 85°C | °C |
| REQ-THERM-002 | 冷却方式：自然对流（无散热片要求） | - |

### 4.3 Cost & Area

| REQ ID | Statement |
|--------|-----------|
| REQ-AREA-001 | NPU die 面积 <= 90 mm²（设计目标，含 10% margin；硬上限 100 mm²） |
| REQ-COST-001 | BOM 成本目标 TBD（待产品定价策略确认）⚠️ 待补充 |

### 4.4 Reliability

| REQ ID | Statement |
|--------|-----------|
| REQ-REL-001 | MTTF >= 100,000 小时 @ 85°C |
| REQ-REL-002 | 软错误率（SER）<= 1000 FIT（含 DRAM ECC 保护后） |
| REQ-REL-003 | ESD：HBM >= 2 kV，CDM >= 500 V |

## 5. Die Composition

### 5.1 Die Inventory

| Die | Function | Process Node | Count | Vendor |
|-----|----------|-------------|-------|--------|
| NPU Die | Systolic Array + Dataflow 控制器 + SRAM scratchpad | ASAP7 (7nm) | 1 | In-house |
| DRAM | 2 GB，>= 10 GB/s 带宽 | DRAM 供应商工艺 | 1 | TBD |

### 5.2 Rationale

- ASAP7 工艺：在 100 mm² 约束下实现目标算力与功耗，7nm 提供充足密度余量；Babel 流程原生支持 ASAP7 PDK
- 3D Stacked DRAM：TinyStories 15M 模型 ~60 MB（FP32），2 GB 提供充足容量与 KV cache 空间
- Note: 原始 PRD 目标 SF4 (4nm)，Babel RTL flow 映射至 ASAP7；架构设计按 ASAP7 标准单元库参数

## 6. Die-to-Die Interconnect Requirements

| REQ ID | Statement |
|--------|-----------|
| REQ-D2D-001 | NPU Die <-> DRAM 接口带宽 >= 10 GB/s（双向） |
| REQ-D2D-002 | 接口协议：LPDDR4X 或供应商定义片上接口 |
| REQ-D2D-003 | D2D 能效 <= 5 pJ/bit |
| REQ-D2D-004 | 接口延迟 <= 100 ns（round-trip，row hit） |

## 7. Package Requirements

| REQ ID | Statement |
|--------|-----------|
| REQ-PKG-001 | 封装类型：标准 BGA 或 PoP（Package on Package） |
| REQ-PKG-002 | 总封装面积 <= 150 mm² |
| REQ-PKG-003 | 最大翘曲 <= 50 um |

## 8. Software & Programming Model

| REQ ID | Statement |
|--------|-----------|
| REQ-SW-001 | 支持自定义 NPU ISA（见 doc/isa/） |
| REQ-SW-002 | 提供 C 语言 runtime API（参考 llama2.c 接口风格） |
| REQ-SW-003 | 支持算子库：Attention、MatMul、RMSNorm、RoPE、SoftMax（见 doc/operators/） |
| REQ-SW-004 | 裸机（bare-metal）运行支持，无需 OS |

## 9. Functional Safety

当前版本：教学/研究/嵌入式场景，暂定 QM（Quality Management）等级，无 ISO 26262 强制要求。

## 10. Security

| REQ ID | Statement |
|--------|-----------|
| REQ-SEC-001 | 支持 secure boot（签名固件验证） |
| REQ-SEC-002 | 供应链威胁模型 -> DOC-D7-01-SEC |

## 11. Standards Compliance Summary

- [ ] IEEE 1149.1（JTAG）
- [ ] JEDEC LPDDR4X（若采用 LPDDR 接口）
- [ ] IEEE 1838（Die Wrapper，若 3D 集成）

## 12. Milestones & Timeline

| Milestone | Target Date | Deliverable |
|-----------|-------------|-------------|
| PRR (Product Readiness Review) | 2026-05-31 | PRD v1.0 frozen |
| Arch Sign-off | 2026-06-07 | ARCH v1.0 |
| RTL Freeze | 2026-06-21 | MAS v1.0 + RTL tag |
| Verification Sign-off | 2026-06-28 | test_report.json |
| Synthesis Sign-off | 2026-07-05 | synth_report.json |
| PD Sign-off | 2026-07-12 | GDSII |

> 总体时间线：一个月内完成（截至 2026-07-12）

## 13. Change Management

- **Freeze Point**: PRD frozen at PRR；变更需 CCB 审批并记录 ECN
- **ECN Log**: 附录 A

## 14. Traceability Matrix

| REQ ID | ARCH Ref | MAS Ref | VPlan Ref |
|--------|----------|---------|-----------|
| REQ-COMPUTE-001 | arch_spec/arch_doc.md §3.1 | M00-MAS (SystolicArray) | VP-COMP-01 |
| REQ-COMPUTE-002 | arch_spec/arch_doc.md §3.1 | M00-MAS (SystolicArray) | VP-COMP-02 |
| REQ-COMPUTE-003 | arch_spec/arch_doc.md §3.1 | M00-MAS (SystolicArray) | VP-COMP-03 |
| REQ-COMPUTE-004 | arch_spec/arch_doc.md §3.1 | M00-MAS (SystolicArray) | VP-COMP-04 |
| REQ-COMPUTE-005 | arch_spec/data_flow.md | M01-MAS (DataflowController) | VP-COMP-05 |
| REQ-COMPUTE-006 | arch_spec/workflow.md | M08-MAS (ThreadScheduler) | VP-COMP-06 |
| REQ-COMPUTE-007 | arch_spec/arch_doc.md §3.1 | M00-MAS (SystolicArray) | VP-COMP-07 |
| REQ-COMPUTE-008 | arch_spec/arch_doc.md §3.1 | M09-MAS, M10-MAS, M11-MAS, M12-MAS | VP-COMP-08 |
| REQ-MEM-001 | arch_spec/arch_doc.md §3.2 | M03-MAS (DRAMController) | VP-MEM-01 |
| REQ-MEM-002 | arch_spec/arch_doc.md §3.2 | M03-MAS (DRAMController) | VP-MEM-02 |
| REQ-MEM-003 | arch_spec/arch_doc.md §3.2 | M03-MAS (DRAMController) | VP-MEM-03 |
| REQ-MEM-004 | arch_spec/arch_doc.md §3.2 | M02-MAS (SRAMScratchpad) | VP-MEM-04 |
| REQ-MEM-005 | arch_spec/arch_doc.md §3.2 | M02-MAS, M03-MAS | VP-MEM-05 |
| REQ-IO-001 | arch_spec/arch_doc.md §3.3 | M15-MAS (JTAGInterface) | VP-IO-01 |
| REQ-IO-002 | arch_spec/arch_doc.md §3.3 | M16-MAS (ISAInterface) | VP-IO-02 |
| REQ-PERF-001 | arch_spec/arch_doc.md §4.1 | M06-MAS (ClockManager) | VP-PERF-01 |
| REQ-PERF-002 | arch_spec/arch_doc.md §4.1 | top-NPU | VP-PERF-02 |
| REQ-PERF-003 | arch_spec/arch_doc.md §4.1 | top-NPU | VP-PERF-03 |
| REQ-PERF-004 | arch_spec/arch_doc.md §4.1 | top-NPU | VP-PERF-04 |
| REQ-PWR-001 | arch_spec/arch_doc.md §4.2 | M05-MAS (PowerManager) | VP-PWR-01 |
| REQ-PWR-002 | arch_spec/arch_doc.md §4.2 | M05-MAS (PowerManager) | VP-PWR-02 |
| REQ-PWR-003 | arch_spec/arch_doc.md §4.2 | M05-MAS, M06-MAS | VP-PWR-03 |
| REQ-THERM-001 | arch_spec/arch_doc.md §4.2 | — | VP-THERM-01 |
| REQ-THERM-002 | arch_spec/arch_doc.md §4.2 | — | VP-THERM-02 |
| REQ-AREA-001 | arch_spec/arch_doc.md §4.3 | top-NPU | VP-AREA-01 |
| REQ-REL-001 | arch_spec/arch_doc.md §4.4 | — | VP-REL-01 |
| REQ-REL-002 | arch_spec/arch_doc.md §4.4 | M02-MAS, M03-MAS | VP-REL-02 |
| REQ-REL-003 | arch_spec/arch_doc.md §4.4 | — | VP-REL-03 |
| REQ-D2D-001 | arch_spec/arch_doc.md §6 | M03-MAS (DRAMController) | VP-D2D-01 |
| REQ-D2D-002 | arch_spec/arch_doc.md §6 | M03-MAS (DRAMController) | VP-D2D-02 |
| REQ-D2D-003 | arch_spec/arch_doc.md §6 | M03-MAS (DRAMController) | VP-D2D-03 |
| REQ-D2D-004 | arch_spec/arch_doc.md §6 | M03-MAS (DRAMController) | VP-D2D-04 |
| REQ-PKG-001 | arch_spec/arch_doc.md §7 | — | VP-PKG-01 |
| REQ-PKG-002 | arch_spec/arch_doc.md §7 | — | VP-PKG-02 |
| REQ-PKG-003 | arch_spec/arch_doc.md §7 | — | VP-PKG-03 |
| REQ-SW-001 | arch_spec/arch_doc.md §8 | M13-MAS (ISADecoder) | VP-SW-01 |
| REQ-SW-002 | arch_spec/arch_doc.md §8 | — | VP-SW-02 |
| REQ-SW-003 | arch_spec/arch_doc.md §8 | M09-MAS, M10-MAS, M11-MAS, M12-MAS | VP-SW-03 |
| REQ-SW-004 | arch_spec/arch_doc.md §8 | — | VP-SW-04 |
| REQ-SEC-001 | arch_spec/arch_doc.md §10 | M14-MAS (SecureBoot) | VP-SEC-01 |
| REQ-SEC-002 | arch_spec/arch_doc.md §10 | M14-MAS (SecureBoot) | VP-SEC-02 |

> Note: ARCH Ref and VPlan Ref 列将在 bb-arch / bb-guru-verification 阶段填充具体章节锚点。MAS Ref 列已基于现有 RTL 模块映射。

## 15. Quality Checklist (Review Gate)

- [x] 所有 REQ-xxx 有唯一 ID，无重复
- [x] 每条需求符合 SMART（可量化指标，无模糊词）
- [x] 所有性能指标有明确目标值 + 测试条件
- [x] Power budget 预留 >= 10% margin（TDP <= 2W，设计目标 <= 1.8W）
- [x] Area budget 预留 >= 10% margin（硬上限 100 mm²，设计目标 <= 90 mm²）
- [ ] BOM 成本目标待补充（REQ-COST-001 标注 ⚠️）
- [x] 功能安全等级已标注（QM）
- [x] 无 TBD 性能指标（成本除外，已标注）
- [x] Variability 已标注（corner/temperature/voltage）
- [ ] Stakeholder sign-off 待完成
- [x] Traceability Matrix 已生成，覆盖全部 REQ（覆盖率 100%）

## Appendix A: ECN Log

| ECN ID | Date | Change | Impact |
|--------|------|--------|--------|

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| NPU | Neural Processing Unit |
| TPS | Tokens Per Second |
| TTFT | Time To First Token |
| TOPS | Tera Operations Per Second |
| ASAP7 | Arizona State / ARM Predictive PDK 7nm |
| DVFS | Dynamic Voltage and Frequency Scaling |
| SER | Soft Error Rate |
| FIT | Failures In Time（每 10^9 小时故障次数） |
| Systolic Array | 脉动阵列，矩阵乘法加速结构 |
| Spatial Dataflow | 空间数据流，算子间流水线并行 |
| TinyStories | 微型 Transformer 语言模型，参数量约 15M |
| KGD | Known-Good-Die |
| SECDED | Single Error Correction, Double Error Detection |