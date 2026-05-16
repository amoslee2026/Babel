# Softmax 算子

## 功能

将向量转换为概率分布（所有元素非负，总和为1）。

---

## 公式

$$\text{softmax}(x_i) = \frac{e^{x_i}}{\sum_j e^{x_j}}$$

---

## 代码实现

```c
// run.c:197-215
void softmax(float* x, int size) {
    // 找最大值（数值稳定性）
    float max_val = x[0];
    for (int i = 1; i < size; i++) {
        if (x[i] > max_val) max_val = x[i];
    }
    // exp和求和
    float sum = 0.0f;
    for (int i = 0; i < size; i++) {
        x[i] = expf(x[i] - max_val);
        sum += x[i];
    }
    // 归一化
    for (int i = 0; i < size; i++) {
        x[i] /= sum;
    }
}
```

---

## 数值稳定性

减最大值防止exp溢出：exp(1000)溢出，但exp(1000-1000)=1安全

---

## 计算复杂度 (size=256)

| 操作 | 数量 |
|------|------|
| 找最大 | 256比较 |
| exp | 256次 |
| 求和 | 256次 |
| 除法 | 256次 |

---

## stories260K调用

- Attention: 40次/forward (8头×5层)
- Sampling: 1次/forward (vocab=512)

---

## 硬件实现

1. **查表exp**: 256 entries = 1KB
2. **并行化**: exp和除法可并行
3. **流水线**: O(size)而非O(size²)