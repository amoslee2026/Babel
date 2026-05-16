# Transformer 算子详细文档

> stories260K 模型（dim=64, 5层）所有算子的详细实现分析
>
> **说明**：本文档基于 stories260K 参考模型进行分析，用于简化设计。实际目标为 TinyStories 15M 推理，算子覆盖一致。

---

## 目录

| 算子 | 文档 | 功能 |
|------|------|------|
| [Embedding](embedding.md) | Token查找 | 输入token ID → 嵌入向量 |
| [RMSNorm](rmsnorm.md) | 归一化 | 稳定激活值分布 |
| [MatMul](matmul.md) | 矩阵乘法 | 核心线性变换 |
| [RoPE](rope.md) | 旋转位置编码 | 相对位置信息注入 |
| [Attention](attention.md) | 多头注意力 | 序列关系建模 |
| [Softmax](softmax.md) | 归一化分布 | 概率计算 |
| [SwiGLU](swiglu.md) | FFN激活 | 门控非线性变换 |
| [Residual](residual.md) | 残差连接 | 梯度流稳定 |
| [Sampling](sampling.md) | 采样策略 | 输出token生成 |

---

## 算子分类

### 1. 前端算子（输入处理）

| 算子 | 调用频率 | 内存特性 |
|------|----------|----------|
| Embedding Lookup | 每个token | 只读，查表 |

### 2. 核心算子（占90%计算时间）

| 算子 | 调用频率 | 复杂度 | 可优化点 |
|------|----------|--------|----------|
| MatMul | 每层×多个 | O(n²) | SIMD, 并行化 |
| Attention Score | 每头×每位置 | O(seq_len) | Flash Attention |

### 3. 归一化算子

| 算子 | 调用频率 | 特点 |
|------|----------|------|
| RMSNorm | 每层×2 | 无均值计算，比LayerNorm快 |
| Softmax | 每头×采样 | 数值稳定性关键 |

### 4. 激活函数

| 算子 | 调用频率 | 特点 |
|------|----------|------|
| RoPE | 每层×Q,K | 无参数位置编码 |
| SwiGLU | 层FFN | 门控机制，三个投影 |

### 5. 辅助算子

| 算子 | 调用频率 | 特点 |
|------|----------|------|
| Residual Add | 每层×2 | 简单向量加法 |

---

## stories260K 算子调用统计

### 单次Forward Pass（生成1个token）

| 算子 | 调用次数 | 总操作量 |
|------|----------|----------|
| Embedding | 1 | dim=64 查表 |
| RMSNorm | 10 | 5层×2 |
| MatMul | 36 | 见下表详细 |
| RoPE | 10 | 5层×Q,K旋转 |
| Attention Score | 40 | 8头×5层×累积pos |
| Softmax | 40 | 8头×5层 |
| SwiGLU | 5 | FFN激活 |
| Residual Add | 10 | 5层×2 |

### MatMul 详细调用

```
每层 MatMul 调用:
- wq: 1次 (dim×dim = 64×64)
- wk: 1次 (dim×kv_dim = 64×32)
- wv: 1次 (dim×kv_dim = 64×32)
- wo: 1次 (dim×dim = 64×64)
- w1: 1次 (dim×hidden = 64×256)
- w3: 1次 (dim×hidden = 64×256)
- w2: 1次 (hidden×dim = 256×64)

每层总计: 7次 MatMul
5层总计: 35次 MatMul
+ embedding classifier: 1次
总计: 36次 MatMul/forward
```

---

## 计算复杂度分析

### 时间复杂度（per token）

| 算子 | 公式 | 260K数值 |
|------|------|----------|
| MatMul (wq) | dim² | 64² = 4,096 FLOPs |
| MatMul (wk/wv) | dim×kv_dim | 64×32 = 2,048 FLOPs |
| MatMul (wo) | dim² | 64² = 4,096 FLOPs |
| Attention Score | n_heads×pos×head_size | 8×pos×8 FLOPs |
| MatMul (w1/w3) | dim×hidden | 64×256 = 16,384 FLOPs |
| MatMul (w2) | hidden×dim | 256×64 = 16,384 FLOPs |

### 总FLOPs估算

```
每token生成 (假设pos=256):
- Embedding: 64 reads
- 5层 Attention: ~5 × (4096×2 + 2048×2 + pos×64) ≈ 50K FLOPs
- 5层 FFN: ~5 × (16384×2 + 16384) ≈ 245K FLOPs
- Classifier: 512×64 = 32K FLOPs

总计: ~330K FLOPs/token
```

---

## 内存分析

### 权重大小 (FP32)

| 权重 | 形状 | 260K大小 |
|------|------|----------|
| token_embedding | (512, 64) | 128KB |
| rms_att | (5, 64) | 1.28KB |
| wq | (5, 64, 64) | 80KB |
| wk | (5, 64, 32) | 40KB |
| wv | (5, 64, 32) | 40KB |
| wo | (5, 64, 64) | 80KB |
| rms_ffn | (5, 64) | 1.28KB |
| w1 | (5, 256, 64) | 320KB |
| w2 | (5, 64, 256) | 320KB |
| w3 | (5, 256, 64) | 320KB |
| rms_final | (64,) | 256B |
| wcls | (512, 64) | 128KB (共享时=0)

**总权重: ~1.05MB**

### 运行内存

| Buffer | 形状 | 大小 |
|--------|------|------|
| x, xb, xb2, q | 4×(64,) | 1KB |
| hb, hb2 | 2×(256,) | 2KB |
| att | (8, 512) | 16KB |
| logits | (512,) | 2KB |
| key_cache | (5, 512, 32) | 320KB |
| value_cache | (5, 512, 32) | 320KB |

**总运行内存: ~661KB**

---

## 算子依赖图

```
Token ID
    │
    ▼
┌─────────────┐
│ Embedding   │ Lookup: vocab[token] → dim向量
└─────────────┘
    │
    ▼
┌─────────────┐
│ RMSNorm     │ 每2个算子之间
└─────────────┘
    │
    ├──────────┐
    │          │
    ▼          ▼
┌────────┐ ┌────────┐
│MatMul  │ │ MatMul │ Q,K,V并行计算
│(wq,wk, │ │ (wv)   │
│wv)     │ │        │
└────────┘ └────────┘
    │          │
    ▼          │
┌─────────────┤
│ RoPE        │ 仅Q,K旋转
└─────────────┘
    │
    ▼
┌─────────────┐
│ Attention   │ Score + Softmax + 加权求和
│ Score       │
└─────────────┘
    │
    ▼
┌─────────────┐
│ MatMul(wo)  │ Output projection
└─────────────┘
    │
    ▼
┌─────────────┐
│ Residual    │ x += wo_output
└─────────────┘
    │
    ▼
┌─────────────┐
│ RMSNorm     │ FFN前归一化
└─────────────┘
    │
    ├──────────┐
    │          │
    ▼          ▼
┌────────┐ ┌────────┐
│MatMul  │ │ MatMul │ w1, w3并行
│(w1)    │ │ (w3)   │
└────────┘ └────────┘
    │          │
    ▼          │
┌─────────────┤
│ SwiGLU      │ SiLU(w1) × w3
└─────────────┘
    │
    ▼
┌─────────────┐
│ MatMul(w2)  │ Down projection
└─────────────┘
    │
    ▼
┌─────────────┐
│ Residual    │ x += ffn_output
└─────────────┘
    │ (重复5层)
    ▼
┌─────────────┐
│ RMSNorm     │ Final归一化
└─────────────┘
    │
    ▼
┌─────────────┐
│ MatMul(wcls)│ Classifier → logits
└─────────────┘
    │
    ▼
┌─────────────┐
│ Sampling    │ Argmax/Top-p采样
└─────────────┘
    │
    ▼
  Next Token
```

---

## 硬件实现建议

### 优先级排序

1. **MatMul** - 最高优先，占用90%时间
2. **Softmax** - 数值稳定性关键
3. **RMSNorm** - 简单但频繁调用
4. **RoPE** - 可预计算cos/sin表
5. **Attention Score** - 可合并优化
6. **SwiGLU** - 三个MatMul可并行

### 加速方法

| 算子 | 加速方法 | 预期收益 |
|------|----------|----------|
| MatMul | SIMD/矩阵加速器 | 10-100x |
| Softmax | 查表exp近似 | 2-3x |
| RMSNorm | 并行计算平方和 | 2x |
| RoPE | 预计算旋转表 | 省计算 |
| Attention | Flash Attention | 省内存 |

---

## 参考实现

所有算子的参考实现在 `llama2.c/run.c` 中：

| 算子 | 代码位置 |
|------|----------|
| RMSNorm | run.c:182-195 |
| Softmax | run.c:197-215 |
| MatMul | run.c:217-229 |
| RoPE | run.c:265-279 |
| Attention | run.c:281-319 |
| SwiGLU | run.c:338-345 |
| Sampling | run.c:691-714 |