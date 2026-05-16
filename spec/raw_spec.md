---
title: "idea of NPU spec"
type: architecture
purpose: ""
audience: both
direction: output
status: approved
section_meta: "@meta"
---

# idea of NPU spec

# 使用场景

* 用于边缘段小参数LLM推理(参考 ./llam2.c)
* 三星4nm工艺
* 3D stacking DRAM
* 芯片面积 100mm^2
* DRAM 容量 2.5GB
* DRAM 带宽 1TB/s

# 性能参数要求
* 支持 FP8，INT8,BF16
* TPS(Token Per Second) 大于 100/s

# 支持的算子和指令集
* 支持算子列表 ./doc/isa/
* 支持指令集列表 ./doc/operators/

# 架构
* 支持Systolic Array ，Dataflow架构
* 支持多线程
* 支持稀疏矩阵
* Spatial Dataflow
* 支持混合精度
* 支持Transformer架构


