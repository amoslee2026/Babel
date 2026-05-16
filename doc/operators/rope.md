# RoPE 算子

## 功能

Rotary Position Embedding - 旋转位置编码，将位置信息注入Query和Key向量。

---

## 原理

将位置编码为旋转角度，应用于向量：

```
频率: freq = 1 / 10000^(dim/head_size)
角度: θ = position × freq
旋转: [x0, x1] → [x0×cosθ - x1×sinθ, x0×sinθ + x1×cosθ]
```

---

## 参数 (stories260K)

| 参数 | 值 |
|------|-----|
| head_size | 8 (dim/n_heads = 64/8) |
| base | 10000 |
| 应用对象 | Q和K向量 |
| 调用频率 | 每层×2 = 10次/forward |

---

## 代码实现

```c
// run.c:265-279
for (int i = 0; i < dim; i+=2) {
    int head_dim = i % head_size;
    float freq = 1.0f / powf(10000.0f, head_dim / (float)head_size);
    float val = pos * freq;
    float fcr = cosf(val);
    float fci = sinf(val);

    // 对Q和K应用旋转
    int rotn = i < kv_dim ? 2 : 1;
    for (int v = 0; v < rotn; v++) {
        float* vec = v == 0 ? s->q : s->k;
        float v0 = vec[i];
        float v1 = vec[i+1];
        vec[i]   = v0 * fcr - v1 * fci;
        vec[i+1] = v0 * fci + v1 * fcr;
    }
}
```

---

## 计算步骤

```
对于每对相邻元素 (i, i+1):

1. 计算频率
   head_dim = i % head_size  (0-7循环)
   freq = 1 / 10000^(head_dim/head_size)

2. 计算旋转角度
   θ = position × freq

3. 计算cos和sin
   cosθ = cos(θ)
   sinθ = sin(θ)

4. 应用旋转 (2D旋转矩阵)
   x0' = x0 × cosθ - x1 × sinθ
   x1' = x0 × sinθ + x1 × cosθ
```

---

## 频率表 (head_size=8)

| head_dim | freq | 说明 |
|----------|------|------|
| 0 | 1.0000 | 最高频率 |
| 1 | 0.3162 | |
| 2 | 0.1000 | |
| 3 | 0.0316 | |
| 4 | 0.0100 | |
| 5 | 0.0032 | |
| 6 | 0.0010 | |
| 7 | 0.0003 | 最低频率 |

---

## 计算复杂度

对于dim=64的向量：

| 操作 | 数量 |
|------|------|
| pow | 4次 |
| cos/sin | 8次 |
| 乘法 | 64×4 = 256次 |
| 加减法 | 64×2 = 128次 |

**总计**: ~400 FLOPs/向量

---

## 优化: 预计算表

```c
// 可预计算cos/sin表，避免实时计算
// 存储: seq_len × head_size/2 × 2 = 512 × 4 × 2 = 4096 floats = 16KB
```

---

## 硬件实现要点

1. **预计算表**: 查表代替实时计算cos/sin
2. **复数乘法器**: 旋转本质是复数乘法
3. **并行执行**: 32对元素可并行旋转

---

## RoPE优势

| 特性 | RoPE | 绝对位置编码 |
|------|------|--------------|
| 参数 | 无 | 需位置嵌入 |
| 长度 | 任意 | 有最大限制 |
| 相对位置 | 自然编码 | 需额外处理 |