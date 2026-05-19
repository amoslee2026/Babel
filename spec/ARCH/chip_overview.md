# TinyStories NPU Chip Overview

## Executive Summary

面向 TinyStories 15M 参数 LLM 推理的专用 NPU，3D Stacked DRAM（Wafer-on-Wafer），三星 SF4（4nm）工艺，独立运行无需主机接口，支持 Secure Boot。

## Key Features

| Feature | Specification | Notes |
|---------|---------------|-------|
| Compute | FP8 >= 1 TOPS / FP16 >= 0.5 TOPS / INT8 >= 1 TOPS | REQ-COMPUTE-001~003 |
| Systolic Array | Weight Stationary / Output Stationary 双模式 | REQ-COMPUTE-004 |
| Spatial Dataflow | Pipeline 利用率 >= 80% | REQ-COMPUTE-005 |
| Multi-threading | 线程数 >= 2 | REQ-COMPUTE-006 |
| Mixed Precision | FP32/FP16/INT8/FP8 混用 | REQ-COMPUTE-007 |
| Transformer Ops | Attention, FFN, RMSNorm, RoPE, SoftMax | REQ-COMPUTE-008 |
| Memory | 2 GB DRAM + 512 KB SRAM | 3D Stacked (Wafer-on-Wafer) |
| Bandwidth | >= 10 GB/s DRAM (读+写) | REQ-MEM-002 |
| DRAM Latency | <= 100 ns (row hit) | REQ-MEM-003 |
| ECC | SECDED 保护 DRAM/SRAM | REQ-MEM-005 |
| Clock | 500 MHz @ TT/0.9V | REQ-PERF-001 |
| DVFS | >= 2 工作点 | REQ-PWR-003 |
| Power | TDP <= 2 W（设计目标 1.8 W） | REQ-PWR-001 |
| Idle Power | <= 0.1 W | REQ-PWR-002 |
| Temperature | 0°C 至 85°C 工作范围 | REQ-THERM-001 |
| Cooling | 自然对流（无散热片） | REQ-THERM-002 |
| Reliability | MTTF >= 100k h @ 85°C | REQ-REL-001 |
| SER | <= 1000 FIT (含 ECC) | REQ-REL-002 |
| ESD | HBM >= 2 kV, CDM >= 500 V | REQ-REL-003 |
| Technology | 三星 SF4（4nm） | |
| Area | <= 90 mm²（硬上限 100 mm²） | REQ-AREA-001 |
| Package | BGA 或 PoP | <= 150 mm² |
| Security | Secure Boot（签名固件验证） | REQ-SEC-001 |

## Target Applications

| UC ID | Use Case | Target Workload | KPI |
|---|---|---|---|
| UC-01 | 边缘端文本生成 | TinyStories 15M FP32 | TPS >= 50 token/s (decode) |
| UC-02 | 边缘端 prefill | TinyStories 15M, prompt <= 256 | TTFT <= 100 ms |
| UC-03 | INT8/FP16/FP8 推理 | TinyStories 15M FP16 | 精度损失 <= 0.5% vs FP32 |

## Performance Targets

| Metric | FP32 | FP16 | INT8 | FP8 |
|--------|------|------|------|-----|
| Decode TPS | >= 50 | >= 100 | - | - |
| Peak TOPS | - | >= 0.5 | >= 1 | >= 1 |
| TTFT (256 tokens) | <= 100 ms | - | - | - |

## Design Philosophy

**功耗优先 + 独立运行 + 安全启动**：面向边缘端场景，优化功耗与面积，无需外部主机接口，支持裸机运行，Secure Boot 保护固件安全。

## Software Support

| Component | Description |
|-----------|-------------|
| ISA | 自定义 NPU 指令集（见 doc/isa/） |
| Runtime API | C 语言接口（参考 llama2.c）REQ-SW-002 |
| Operator Library | Attention, MatMul, RMSNorm, RoPE, SoftMax REQ-SW-003 |
| Bare-metal | 无需 OS 支持 REQ-SW-004 |

## Die-to-Die Interconnect

| Parameter | Target | REQ |
|-----------|--------|-----|
| Bandwidth | >= 10 GB/s (双向) | REQ-D2D-001 |
| Protocol | LPDDR4X 或供应商定义 | REQ-D2D-002 |
| Energy Efficiency | <= 5 pJ/bit | REQ-D2D-003 |
| Latency | <= 100 ns (round-trip, row hit) | REQ-D2D-004 |
