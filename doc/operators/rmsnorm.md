# RMSNorm 算子

## 功能

Root Mean Square Normalization - 归一化激活向量，稳定训练和推理。

---

## 公式

$$\text{RMSNorm}(x) = \frac{x}{\sqrt{\frac{1}{n}\sum_{i=1}^n x_i^2 + \epsilon}} \cdot w$$

---

## 参数 (stories260K)

| 参数 | 值 |
|------|-----|
| size (dim) | 64 |
| epsilon | 1e-5 |
| 调用频率 | 每层×2 = 10次/forward |

---

## 代码实现

```c
// run.c:182-195
void rmsnorm(float* o, float* x, float* weight, int size) {
    // Step 1: 计算平方和
    float ss = 0.0f;
    for (int j = 0; j < size; j++) {
        ss += x[j] * x[j];
    }
    ss /= size;
    ss += 1e-5f;
    ss = 1.0f / sqrtf(ss);

    // Step 2: 归一化并缩放
    for (int j = 0; j < size; j++) {
        o[j] = weight[j] * (ss * x[j]);
    }
}
```

---

## 计算步骤分解

```
输入: x[64], weight[64]

Step 1: 计算平方和
  ss = Σ(x[i]^2) for i=0..63
  ss = ss / 64           // 均值
  ss = ss + 1e-5         // epsilon防止除零
  ss = 1 / sqrt(ss)      // 归一化因子

Step 2: 归一化+缩放
  for i in 0..63:
    o[i] = weight[i] * ss * x[i]
```

---

## 计算复杂度

| 操作 | FLOPs (size=64) |
|------|-----------------|
| 平方和 | 64 × (mul + add) = 128 |
| 除法 | 1 |
| 加法 | 1 |
| sqrt | 1 |
| 除法倒数 | 1 |
| 归一化×缩放 | 64 × 2 = 128 |
| **总计** | **~260 FLOPs** |

---

## 与LayerNorm对比

| 特性 | RMSNorm | LayerNorm |
|------|---------|-----------|
| 均值计算 | 无 | 有 |
| 计算量 | 少 | 多 |
| 参数 | scale (w) | scale + bias |
| 效果 | 相当 | 相当 |

**RMSNorm优势**: 计算更简单，硬件实现更容易。

---

## 硬件实现要点

### 并行化方案

```
Step 1: 64个平方并行计算
Step 2: 树形加法 (64→32→16→8→4→2→1)
Step 3: sqrt可查表近似
Step 4: 64个乘法并行执行
```

### 优化建议

1. **预计算平方**: 64个乘法并行执行
2. **树形加法**: 7级流水线完成求和
3. **sqrt查表**: 用查找表近似sqrt运算
4. **合并乘法**: 预计算 `weight * rms`