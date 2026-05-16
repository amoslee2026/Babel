# MatMul 算子

## 功能

矩阵乘法 - Transformer中最核心的算子，占用90%+计算时间。

---

## 操作形式

```
W (d, n) @ x (n,) → xout (d,)

其中:
- W: 权重矩阵
- x: 输入向量
- xout: 输出向量
```

---

## stories260K中的MatMul调用

| 权重 | 形状 | FLOPs | 调用频率 |
|------|------|-------|----------|
| wq | (64, 64) | 4,096 | 每层×1 |
| wk | (64, 32) | 2,048 | 每层×1 |
| wv | (64, 32) | 2,048 | 每层×1 |
| wo | (64, 64) | 4,096 | 每层×1 |
| w1 | (256, 64) | 16,384 | 每层×1 |
| w3 | (256, 64) | 16,384 | 每层×1 |
| w2 | (64, 256) | 16,384 | 每层×1 |
| wcls | (512, 64) | 32,768 | 最后×1 |

**每层总计**: 7次 × ~60K FLOPs
**5层+classifier总计**: 36次 MatMul

---

## 代码实现

```c
// run.c:217-229
void matmul(float* xout, float* x, float* w, int n, int d) {
    // W (d,n) @ x (n,) -> xout (d,)
    #pragma omp parallel for private(i)
    for (int i = 0; i < d; i++) {
        float val = 0.0f;
        for (int j = 0; j < n; j++) {
            val += w[i * n + j] * x[j];
        }
        xout[i] = val;
    }
}
```

---

## 内存布局

权重矩阵按行存储（Row-major）：

```
W[i, j] 的地址 = W + i * n + j

例如 wq (64, 64):
  wq[0, 0] → offset 0
  wq[0, 63] → offset 63
  wq[1, 0] → offset 64
  wq[i, j] → offset i * 64 + j
```

---

## 计算复杂度

| 矩阵大小 | FLOPs公式 | 260K示例 |
|----------|-----------|----------|
| (d, n) | 2 × d × n | (64,64) = 8,192 |
| (d, n) @ (n,) | d × (n mul + n-1 add) | 约 d × n |

**注意**: 每个输出元素需要 n次乘法 + (n-1)次加法

---

## 优化技术

### 1. OpenMP并行化

```c
#pragma omp parallel for
// 将d个输出元素分配给多个线程
```

### 2. SIMD优化 (未实现，可添加)

```c
// 使用NEON/AVX加速
for (int j = 0; j < n; j += 4) {
    // 4个乘法并行执行
}
```

### 3. 循环展开

```c
// 手动展开减少循环开销
for (int j = 0; j < n; j += 4) {
    val += w[i*n+j] * x[j];
    val += w[i*n+j+1] * x[j+1];
    val += w[i*n+j+2] * x[j+2];
    val += w[i*n+j+3] * x[j+3];
}
```

---

## 硬件实现要点

### 基础实现

```
每个输出元素:
  - n个乘法
  - n-1个加法
  - 可流水线执行

总并行度:
  - d个输出可完全并行
  - 每个输出的n次乘加可流水线
```

### 矩阵加速器设计

```
输入: 
  - x向量 (n elements)
  - W矩阵 (d rows × n cols)
  
输出:
  - xout向量 (d elements)

结构:
  - d个MAC单元
  - 每个MAC: n cycles完成一行
  - 总时间: n cycles (并行d行)
```

### 内存带宽分析

```
每次MatMul需要:
  - 读取W: d × n floats
  - 读取x: n floats
  - 写入xout: d floats

例如 w1 (256, 64):
  - 读W: 256 × 64 × 4B = 64KB
  - 读x: 64 × 4B = 256B
  - 写xout: 256 × 4B = 1KB
  - 总带宽: ~65KB

36次MatMul总带宽: ~2.3MB/forward
```

---

## 性能瓶颈分析

MatMul是Transformer的主要瓶颈：

| 因素 | 影响 |
|------|------|
| 内存带宽 | 权重读取占用大量带宽 |
| 计算量 | 占90%+时间 |
| Cache效率 | 大矩阵可能超出Cache |

**解决方案**:
- 权重量化 (int8) 减少4倍带宽
- 矩阵分块 (tiling) 提升Cache命中率
- SIMD加速提升计算吞吐