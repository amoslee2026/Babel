# SwiGLU 算子

## 功能

SwiGLU激活函数 - FFN中的门控非线性变换。

---

## 公式

$$\text{SwiGLU}(x) = \text{SiLU}(xW_1) \odot (xW_3) \cdot W_2$$

---

## 参数 (stories260K)

| 参数 | 值 |
|------|-----|
| dim | 64 |
| hidden_dim | 256 |
| 调用频率 | 5次/forward |

---

## 结构图

```
       x
      /|\
     / | \
    W1 W3  (并行)
    |  |
   SiLU identity
     \ |
      ⊙  (乘法)
      |
      W2
```

---

## 计算复杂度

| 操作 | FLOPs |
|------|-------|
| MatMul(w1,w3) | 32,768 |
| SiLU | 768 |
| MatMul(w2) | 16,384 |
| **总计** | ~50K |

---

## 硬件实现

1. **并行投影**: w1和w3并行
2. **sigmoid查表**: SiLU中的sigmoid可查表
3. **三个MatMul**: 占主要时间