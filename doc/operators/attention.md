# Attention 算子

## 功能

Multi-Head Attention - 多头注意力机制，建模序列中不同位置的关系。

---

## 公式

$$\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}}\right) V$$

---

## 参数 (stories260K)

| 参数 | 值 |
|------|-----|
| n_heads | 8 |
| n_kv_heads | 4 (Multi-Query) |
| head_size | 8 |
| kv_dim | 32 |
| seq_len | 512 |
| kv_mul | 2 (每2个Query共享1个KV) |

---

## 计算步骤

### Step 1: 计算Score

每个头对每个历史位置计算score: Q·K/sqrt(head_size)

### Step 2: Softmax

每个头独立softmax归一化

### Step 3: 加权求和

用attention权重加权Value向量

---

## Multi-Query Attention

stories260K使用MQA优化：

```
n_heads = 8 (Query头)
n_kv_heads = 4 (KV头)

每个KV头被2个Query头共享:
  Head 0,1 → KV Head 0
  Head 2,3 → KV Head 1
  Head 4,5 → KV Head 2
  Head 6,7 → KV Head 3

KV Cache大小减半!
```

---

## 计算复杂度 (pos=256)

| 步骤 | FLOPs |
|------|-------|
| Score | n_heads × pos × head_size × 2 = 32,768 |
| Softmax | n_heads × pos × 3 = 6,144 |
| 加权求和 | n_heads × pos × head_size × 2 = 32,768 |
| **总计/层** | ~71K |
| **5层** | ~355K |

---

## KV Cache结构

```
key_cache: (5, 512, 32) = 320KB
value_cache: (5, 512, 32) = 320KB
总计: 640KB
```

---

## 硬件实现要点

1. **Score计算**: pos次向量点积
2. **Softmax**: 数值稳定性关键
3. **加权求和**: pos次向量加权
4. **Flash Attention**: 分块计算，省内存