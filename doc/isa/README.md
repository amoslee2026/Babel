# TinyStories NPU ISA 文档索引

面向 TinyStories 15M LLM 推理的专用处理器指令集架构。

> **设计说明**：ISA 基于 stories260K (dim=64, 5层) 参考模型进行详细设计，用于简化分析。实际目标为 TinyStories 15M 推理，算子覆盖一致。

## 文档结构

| 文件 | 内容 |
|------|------|
| [overview.md](overview.md) | 设计目标、寄存器文件、内存模型、编码格式 |
| [instructions.md](instructions.md) | 全部32条指令详细规范 |
| [examples.md](examples.md) | TinyStories forward pass 伪汇编示例 |

## 快速参考

- 指令总数：32条
- 向量宽度：64×FP32（256字节）
- 数据类型：FP32（主），INT8（可选量化）
- 核心指令：`MMUL`（MatMul）、`VDOT`（Attention点积）、`EMBED`（Embedding查表）
