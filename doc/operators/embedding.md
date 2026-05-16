# Embedding 算子

## 功能

将输入的 token ID 转换为对应的嵌入向量。

---

## 参数

| 参数 | stories260K值 | 说明 |
|------|---------------|------|
| vocab_size | 512 | 词表大小 |
| dim | 64 | 嵌入维度 |

---

## 实现原理

```
输入: token_id (整数, 0-511)
输出: embedding_vector (float数组, 长度64)

embedding_vector = token_embedding_table[token_id * dim]
```

本质上是一个查表操作（Lookup Table）。

---

## 代码实现

```c
// run.c:245-246
float* content_row = w->token_embedding_table + token * dim;
memcpy(x, content_row, dim * sizeof(float));
```

---

## 内存布局

```
token_embedding_table: (vocab_size, dim) = (512, 64)
总大小: 512 × 64 × 4B = 128KB (FP32)

访问模式:
- token=0 → offset 0-63
- token=1 → offset 64-127
- token=n → offset n*64 to (n+1)*64-1
```

---

## 计算复杂度

| 指标 | 值 |
|------|-----|
| FLOPs | 0 (纯查表) |
| 内存读取 | 64 floats = 256 bytes |
| 内存写入 | 64 floats = 256 bytes |

---

## 硬件实现要点

### 最简实现

```verilog
// 伪代码
module embedding_lookup (
    input [9:0] token_id,      // 512需要10bit
    output [63*32-1:0] vector  // 64个float
);
    // ROM存储嵌入表
    reg [31:0] embedding_table [0:511*64-1];
    
    // 连续读取64个float
    for (i = 0; i < 64; i++) begin
        vector[i*32 +: 32] = embedding_table[token_id * 64 + i];
    end
endmodule
```

### 优化建议

1. **ROM压缩**: 嵌入表可量化为int8，节省4倍内存
2. **并行读取**: 64个float可并行从ROM读取
3. **缓存**: 高频token可缓存到SRAM

---

## 与Classifier共享

```c
// run.c:139
w->wcls = shared_weights ? w->token_embedding_table : ptr;
```

当 `shared_weights=1` 时，embedding表与classifier共享权重，节省128KB内存。