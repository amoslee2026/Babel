# Sampling 算子

## 功能

从logits概率分布中选择下一个token。

---

## 参数

| 参数 | 值 |
|------|-----|
| vocab_size | 512 |
| 调用频率 | 每token生成1次 |

---

## 采样策略

### Greedy (temperature=0)

确定性采样，选择最高概率token。

### Temperature Sampling

温度调节随机性：temperature=0确定性，temperature>1更随机

### Top-p Sampling

只保留累计概率达到p的top tokens，从截断分布采样。

---

## 计算复杂度

| 方法 | FLOPs |
|------|-------|
| Greedy | 512比较 |
| Temperature | softmax开销 |

---

## 硬件实现

Greedy可用树形比较，9 cycles完成512比较。