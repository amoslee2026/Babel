# TinyStories NPU Chip Overview

## Executive Summary

面向 TinyStories 15M 参数 LLM 推理的专用 NPU，3D Stacked DRAM（Wafer-on-Wafer），三星 SF4（4nm）工艺，独立运行无需主机接口。

## Key Features

| Feature | Specification | Notes |
|---------|---------------|-------|
| Compute | 0.5 TOPS FP32 / 1 TOPS FP16 / 2 TOPS INT8 | Systolic Array |
| Memory | 2 GB DRAM + 512 KB SRAM | 3D Stacked (Wafer-on-Wafer) |
| Bandwidth | >= 10 GB/s DRAM | 满足推理需求 |
| Clock | 500 MHz @ TT/0.9V | 主频 |
| Power | TDP <= 2 W（设计目标 1.8 W） | 含 DRAM |
| Technology | 三星 SF4（4nm） | |
| Area | <= 90 mm²（硬上限 100 mm²） | 含 10% margin |
| Package | BGA 或 PoP | <= 150 mm² |

## Target Applications

1. 嵌入式 AI 推理（IoT 设备、边缘服务器）
2. 教学/研究平台（LLM 架构学习）
3. 低功耗文本生成应用

## Design Philosophy

**功耗优先 + 独立运行**：面向边缘端场景，优化功耗与面积，无需外部主机接口，支持裸机运行。
