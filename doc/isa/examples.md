# 伪汇编示例：TinyStories Forward Pass

> **参考模型**：以下示例基于 stories260K (dim=64, n_heads=8, n_kv_heads=4, n_layers=5) 参数演示，与 TinyStories 15M 算子逻辑一致。

stories260K 参数：dim=64, n_heads=8, n_kv_heads=4, n_layers=5, vocab=512, seq_len=512

## 寄存器分配约定

| 寄存器 | 用途 |
|--------|------|
| s2 | token_id |
| s3 | 当前位置 pos |
| s4 | 临时标量（归约结果） |
| s5 | 临时标量 |
| s6 | 循环计数 |
| s7 | 循环上界 |
| v4 | 主激活向量 x |
| v5 | 权重向量（rmsnorm w） |
| v6 | 归一化后激活 x_norm |
| v7 | 临时向量 |
| v8 | Q向量 |
| v9 | K向量 |
| v10 | V向量 |
| v11 | cos向量（RoPE） |
| v12 | sin向量（RoPE） |
| v13 | Attention输出累加 |
| v14–v20 | FFN临时 |

---

## Step 1: Embedding

```asm
; token_id 在 s2
EMBED   v4, s2          ; v4 = embedding_table[token_id], 64×FP32
```

---

## Step 2: Transformer Layer（展开1层，共5层循环）

### 2a: RMSNorm（Attention前）

```asm
; 保存输入用于残差
VCOPY   v7, v4              ; v7 = x（残差备份）

; 计算平方和
VMUL    v6, v4, v4          ; v6[i] = x[i]^2
VSUM    s4, v6              ; s4 = sum(x^2)

; 计算 1/sqrt(sum/64 + 1e-5)
; s_inv64 = 1/64（预存常量）
SMUL    s5, s4, s_inv64     ; s5 = sum/64
; 标量路径：用特殊函数单元处理标量（广播到向量第0元素）
VSQRT_INV s4, s5            ; s4 = 1/sqrt(s5)

; 归一化 + 缩放
VLD     v5, [RMS_ATT_W]     ; v5 = rmsnorm权重 w[0..63]
VSMUL   v6, v4, s4          ; v6 = x * (1/rms)
VMUL    v6, v6, v5          ; v6 = x_norm = x_normalized * w
```

### 2b: QKV投影

```asm
MSET_DIM 64
MMUL    v8,  v6, W_Q        ; v8  = Q = W_Q(64×64) @ x_norm，64周期
MSET_DIM 32
MMUL    v9,  v6, W_K        ; v9  = K = W_K(32×64) @ x_norm，32周期
MMUL    v10, v6, W_V        ; v10 = V = W_V(32×64) @ x_norm，32周期
```

### 2c: RoPE位置编码

```asm
; 从预计算表加载 cos/sin（各64元素）
ROPE_LD v11, v12, s3        ; v11=cos(pos*freq), v12=sin(pos*freq)

; 对Q应用旋转（复数乘法：偶数维×cos - 奇数维×sin）
; 注：实际需要奇偶维度重排，此处简化为逐元素操作示意
VMUL    v14, v8,  v11       ; Q * cos
VMUL    v15, v8,  v12       ; Q * sin（需旋转配对，略去重排细节）
VSUB    v8,  v14, v15       ; Q_rope

; 对K应用旋转（仅前kv_dim=32维）
VMUL    v14, v9,  v11       ; K * cos
VMUL    v15, v9,  v12       ; K * sin
VSUB    v9,  v14, v15       ; K_rope
```

### 2d: 写入KV Cache

```asm
KV_WRITE v9, v10            ; kv_cache[head_id][pos] = (K, V); kv_ptr++
```

### 2e: Multi-Head Attention（8头，循环）

```asm
; 初始化输出累加器
VCOPY   v13, v0             ; v13 = zeros（v0硬连线为零向量）

; 外层循环：8个注意力头
; s6 = 0（头计数），s7 = 8
; （head_id寄存器由软件写入，控制KV_READ选择哪个KV分区）

head_loop:
    ; 内层循环：对所有已有token计算注意力分数
    ; s8 = 0（seq计数），s9 = pos+1（序列长度）
    ; scores暂存到激活SRAM的临时区域

    seq_score_loop:
        KV_READ v14, v15, s8        ; v14=K[t], v15=V[t]
        VDOT    s4, v8, v14         ; s4 = Q·K[t] / sqrt(head_size)
        ; 注：除以sqrt(8)=2.83，可预乘Q实现
        SST     s4, [SCORE_BUF + s8*4]  ; 存入score缓冲
        SADD    s8, s8, s_one
        VSUB    s5, s9, s8
        BNZ     s5, seq_score_loop

    ; Softmax(scores[0..pos])
    VLD     v16, [SCORE_BUF]        ; 加载scores向量
    VMAX    s4, v16                 ; s4 = max(scores)
    VSMUL   v16, v16, s_neg1        ; 取负（用于减max：x - max = x + (-max)）
    ; 实际：VSUB v16, v16, broadcast(s4)（需广播标量到向量）
    VEXP    v16, v16                ; v16[i] = exp(scores[i] - max)
    VSUM    s5, v16                 ; s5 = sum(exp)
    SDIV    s5, s_one, s5           ; s5 = 1/sum
    VSMUL   v16, v16, s5            ; v16 = softmax(scores)

    ; 加权求和 V
    ; s8 = 0，重置seq计数
    seq_attn_loop:
        KV_READ v14, v15, s8        ; v15 = V[t]
        SLD     s4, [SCORE_BUF + s8*4]  ; s4 = attn_weight[t]
        VSMUL   v17, v15, s4        ; v17 = weight * V[t]
        VADD    v13, v13, v17       ; v13 += weight * V[t]
        SADD    s8, s8, s_one
        VSUB    s5, s9, s8
        BNZ     s5, seq_attn_loop

    SADD    s6, s6, s_one
    VSUB    s5, s7, s6
    BNZ     s5, head_loop

; 输出投影 W_O
MSET_DIM 64
MMUL    v13, v13, W_O       ; v13 = W_O(64×64) @ attn_out

; 残差连接
VADD    v4, v7, v13         ; x = x_residual + attn_out
```

### 2f: RMSNorm（FFN前）

```asm
VCOPY   v7, v4              ; 保存残差
VMUL    v6, v4, v4
VSUM    s4, v6
SMUL    s5, s4, s_inv64
VSQRT_INV s4, s5
VLD     v5, [RMS_FFN_W]
VSMUL   v6, v4, s4
VMUL    v6, v6, v5          ; v6 = x_norm（FFN输入）
```

### 2g: SwiGLU FFN

```asm
; 并行投影 W1 和 W3
MSET_DIM 256
MMUL    v14, v6, W1         ; v14 = W1(256×64) @ x_norm，256周期
MMUL    v15, v6, W3         ; v15 = W3(256×64) @ x_norm，256周期

; SiLU(v14) = v14 * sigmoid(v14)
VSIGMOID v16, v14           ; v16 = sigmoid(v14)
VMUL    v14, v14, v16       ; v14 = SiLU(W1*x)

; 门控乘法
VMUL    v14, v14, v15       ; v14 = SiLU(W1*x) ⊙ (W3*x)

; 输出投影 W2
MSET_DIM 64
MMUL    v14, v14, W2        ; v14 = W2(64×256) @ hidden，64周期

; 残差连接
VADD    v4, v7, v14         ; x = x_residual + ffn_out
```

---

## Step 3: 最终 RMSNorm + Classifier

```asm
; 最终归一化
VMUL    v6, v4, v4
VSUM    s4, v6
SMUL    s5, s4, s_inv64
VSQRT_INV s4, s5
VLD     v5, [RMS_FINAL_W]
VSMUL   v6, v4, s4
VMUL    v6, v6, v5

; Classifier: logits = W_cls(512×64) @ x_norm
MSET_DIM 512
MMUL    v18, v6, W_CLS      ; v18 = logits[0..511]，512周期
```

---

## Step 4: Sampling（贪心解码）

```asm
; vocab=512，向量宽度64，需8次循环
; s6 = 0（块计数），s7 = 8，s8 = 全局最大值索引，s9 = 全局最大值

; 注：VARGMAX返回局部64元素内的argmax
; 需要8次循环找全局argmax

argmax_loop:
    ; 加载logits的第s6块（64元素）
    VLD     v19, [LOGITS_BUF + s6*256]
    VMAX    s4, v19                 ; s4 = 本块最大值
    ; 与全局最大值比较，更新s8/s9（需标量比较指令，此处简化）
    SADD    s6, s6, s_one
    VSUB    s5, s7, s6
    BNZ     s5, argmax_loop

; s8 = next_token_id
HALT
```

---

## 关键性能数据（stories260K，单token推理）

| 阶段 | 主要指令 | 估算周期 |
|------|---------|---------|
| Embedding | EMBED×1 | 4 |
| RMSNorm×10 | VMUL+VSUM+VSQRT_INV+VSMUL | ~100 |
| MatMul×36 | MMUL（各种维度） | ~7,000 |
| RoPE×10 | ROPE_LD+VMUL+VSUB | ~200 |
| Attention×5层 | VDOT×pos + VEXP + VMAC | ~pos×500 |
| SwiGLU×5 | VSIGMOID+VMUL+MMUL | ~3,000 |
| Sampling | VLD+VMAX×8 | ~100 |
| **合计（pos=256）** | | **~140K周期** |

MatMul占主导（~50%），与算子分析中"90%计算量"一致。
