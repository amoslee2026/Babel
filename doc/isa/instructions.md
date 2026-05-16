# 指令详细规范

## 向量算术指令（OPCODE 0x00–0x05）

### VADD — 向量加法
- **格式**：`VADD vd, vs1, vs2`（V型，OPCODE=0x00）
- **语义**：`vd[i] = vs1[i] + vs2[i]`，i∈[0,63]
- **延迟**：2周期
- **覆盖算子**：Residual（残差连接）

### VMUL — 向量逐元素乘
- **格式**：`VMUL vd, vs1, vs2`（V型，OPCODE=0x01）
- **语义**：`vd[i] = vs1[i] * vs2[i]`
- **延迟**：2周期
- **覆盖算子**：SwiGLU门控乘法、RoPE复数乘

### VSMUL — 向量标量乘
- **格式**：`VSMUL vd, vs1, sd`（VI型，OPCODE=0x02）
- **语义**：`vd[i] = vs1[i] * sd`
- **延迟**：2周期
- **覆盖算子**：RMSNorm缩放、Softmax归一化

### VMAC — 向量乘累加
- **格式**：`VMAC vd, vs1, vs2`（V型，OPCODE=0x03）
- **语义**：`vd[i] += vs1[i] * vs2[i]`
- **延迟**：2周期
- **覆盖算子**：Attention加权求和

### VSUB — 向量减法
- **格式**：`VSUB vd, vs1, vs2`（V型，OPCODE=0x04）
- **语义**：`vd[i] = vs1[i] - vs2[i]`
- **延迟**：2周期
- **覆盖算子**：Softmax数值稳定（减max）

### VCOPY — 向量复制
- **格式**：`VCOPY vd, vs1`（V型，OPCODE=0x05）
- **语义**：`vd[i] = vs1[i]`
- **延迟**：1周期

---

## 矩阵乘法指令（OPCODE 0x08–0x0A）

### MSET_DIM — 设置矩阵行数
- **格式**：`MSET_DIM imm`（S型，OPCODE=0x0A）
- **语义**：`s_dim = imm`，供MMUL使用
- **延迟**：1周期

### MLOAD — 预加载矩阵行
- **格式**：`MLOAD base, row_idx`（M型，OPCODE=0x08）
- **语义**：从地址 `base + row_idx*256` 加载64×FP32到MAC阵列行缓冲
- **延迟**：4周期

### MMUL — 矩阵向量乘（核心指令）
- **格式**：`MMUL vd, vs1, base`（V型，OPCODE=0x09）
- **语义**：
  ```
  for i in 0..s_dim-1:
      vd[i] = dot(W[i*64..(i+1)*64-1], vs1[0..63])
  ```
  权重矩阵基地址由标量寄存器 `base` 指定，行数由 `s_dim` 给出
- **延迟**：`s_dim` 周期（MAC阵列64路并行，每周期完成一行）
- **覆盖算子**：W_q/W_k/W_v/W_o投影，FFN的W1/W2/W3，Classifier

---

## 特殊函数指令（OPCODE 0x10–0x14）

所有特殊函数通过查找表ROM实现（精度≥FP16），延迟均为4周期。

### VEXP — 向量指数
- **格式**：`VEXP vd, vs1`（V型，OPCODE=0x10）
- **语义**：`vd[i] = exp(vs1[i])`
- **覆盖算子**：Softmax

### VSQRT_INV — 向量平方根倒数
- **格式**：`VSQRT_INV vd, vs1`（V型，OPCODE=0x11）
- **语义**：`vd[i] = 1.0 / sqrt(vs1[i])`
- **覆盖算子**：RMSNorm

### VSIN — 向量正弦
- **格式**：`VSIN vd, vs1`（V型，OPCODE=0x12）
- **语义**：`vd[i] = sin(vs1[i])`
- **覆盖算子**：RoPE

### VCOS — 向量余弦
- **格式**：`VCOS vd, vs1`（V型，OPCODE=0x13）
- **语义**：`vd[i] = cos(vs1[i])`
- **覆盖算子**：RoPE

### VSIGMOID — 向量Sigmoid
- **格式**：`VSIGMOID vd, vs1`（V型，OPCODE=0x14）
- **语义**：`vd[i] = 1.0 / (1.0 + exp(-vs1[i]))`
- **覆盖算子**：SwiGLU（SiLU = x * sigmoid(x)）

---

## 归约指令（OPCODE 0x18–0x1B）

### VSUM — 向量求和
- **格式**：`VSUM sd, vs1`（V型，OPCODE=0x18）
- **语义**：`sd = sum(vs1[0..63])`
- **延迟**：6周期（6级树形归约）
- **覆盖算子**：RMSNorm（平方和），Softmax（exp求和）

### VMAX — 向量最大值
- **格式**：`VMAX sd, vs1`（V型，OPCODE=0x19）
- **语义**：`sd = max(vs1[0..63])`
- **延迟**：6周期
- **覆盖算子**：Softmax数值稳定

### VDOT — 向量点积
- **格式**：`VDOT sd, vs1, vs2`（V型，OPCODE=0x1A）
- **语义**：`sd = sum(vs1[i] * vs2[i])`，i∈[0,63]
- **延迟**：4周期
- **覆盖算子**：Attention的Q·K点积

### VARGMAX — 向量argmax
- **格式**：`VARGMAX sd, vs1`（V型，OPCODE=0x1B）
- **语义**：`sd = argmax(vs1[0..63])`
- **延迟**：6周期
- **覆盖算子**：Sampling贪心解码（vocab=512时配合循环）

---

## 内存访问指令（OPCODE 0x20–0x25）

### VLD — 向量加载
- **格式**：`VLD vd, [base + offset*256]`（M型，OPCODE=0x20）
- **语义**：从256字节对齐地址加载64×FP32
- **延迟**：4周期（SRAM），8周期（ROM）

### VST — 向量存储
- **格式**：`VST vs1, [base + offset*256]`（M型，OPCODE=0x21）
- **延迟**：4周期

### SLD — 标量加载
- **格式**：`SLD sd, [base + imm]`（M型，OPCODE=0x22）
- **延迟**：4周期

### SST — 标量存储
- **格式**：`SST ss, [base + imm]`（M型，OPCODE=0x23）
- **延迟**：4周期

### EMBED — Embedding查表
- **格式**：`EMBED vd, sd`（S型，OPCODE=0x24）
- **语义**：`vd = embedding_table[sd]`，等价于 `VLD vd, [EMB_BASE + sd*256]`
- **延迟**：4周期
- **覆盖算子**：Embedding层

### ROPE_LD — 加载RoPE预计算表
- **格式**：`ROPE_LD vcos, vsin, sd`（M型，OPCODE=0x25）
- **语义**：根据位置 `sd` 从ROM加载预计算的cos/sin向量（各64元素，pos∈[0,2047]）
- **延迟**：4周期
- **覆盖算子**：RoPE

---

## KV Cache指令（OPCODE 0x28–0x2A）

### KV_WRITE — 写入KV Cache
- **格式**：`KV_WRITE vs_k, vs_v`（V型，OPCODE=0x28）
- **语义**：`kv_cache[head_id][kv_ptr] = (vs_k, vs_v); kv_ptr++`
- **延迟**：4周期

### KV_READ — 读取KV Cache
- **格式**：`KV_READ vk, vv, sd`（M型，OPCODE=0x29）
- **语义**：从 `kv_cache[head_id][sd]` 读取K和V向量
- **延迟**：4周期

### KV_RESET — 重置KV Cache指针
- **格式**：`KV_RESET`（S型，OPCODE=0x2A）
- **语义**：`kv_ptr = 0`
- **延迟**：1周期

---

## 标量/控制指令（OPCODE 0x30–0x34）

### SADD — 标量加法
- **格式**：`SADD sd, ss1, ss2`（S型，OPCODE=0x30）
- **语义**：`sd = ss1 + ss2`
- **延迟**：1周期

### SMUL — 标量乘法
- **格式**：`SMUL sd, ss1, ss2`（S型，OPCODE=0x31）
- **语义**：`sd = ss1 * ss2`
- **延迟**：2周期

### SDIV — 标量除法
- **格式**：`SDIV sd, ss1, ss2`（S型，OPCODE=0x32）
- **语义**：`sd = ss1 / ss2`
- **延迟**：8周期

### BNZ — 非零跳转
- **格式**：`BNZ ss, label`（S型，OPCODE=0x33）
- **语义**：若 `ss != 0` 则跳转（PC相对，21-bit有符号偏移）
- **延迟**：1周期（跳转时流水线刷新2周期）

### HALT — 停机
- **格式**：`HALT`（S型，OPCODE=0x34）
- **语义**：停止执行，置 `status.done=1`
- **延迟**：1周期

---

## 指令编码速查表

| OPCODE | 助记符 | 格式 | 延迟(周期) | 覆盖算子 |
|--------|--------|------|-----------|---------|
| 0x00 | VADD | V | 2 | Residual |
| 0x01 | VMUL | V | 2 | SwiGLU, RoPE |
| 0x02 | VSMUL | VI | 2 | RMSNorm, Softmax |
| 0x03 | VMAC | V | 2 | Attention加权和 |
| 0x04 | VSUB | V | 2 | Softmax |
| 0x05 | VCOPY | V | 1 | 通用 |
| 0x08 | MLOAD | M | 4 | MatMul预加载 |
| 0x09 | MMUL | V | s_dim | MatMul |
| 0x0A | MSET_DIM | S | 1 | MatMul配置 |
| 0x10 | VEXP | V | 4 | Softmax |
| 0x11 | VSQRT_INV | V | 4 | RMSNorm |
| 0x12 | VSIN | V | 4 | RoPE |
| 0x13 | VCOS | V | 4 | RoPE |
| 0x14 | VSIGMOID | V | 4 | SwiGLU |
| 0x18 | VSUM | V | 6 | RMSNorm, Softmax |
| 0x19 | VMAX | V | 6 | Softmax |
| 0x1A | VDOT | V | 4 | Attention |
| 0x1B | VARGMAX | V | 6 | Sampling |
| 0x20 | VLD | M | 4/8 | 所有 |
| 0x21 | VST | M | 4 | 所有 |
| 0x22 | SLD | M | 4 | 标量 |
| 0x23 | SST | M | 4 | 标量 |
| 0x24 | EMBED | S | 4 | Embedding |
| 0x25 | ROPE_LD | M | 4 | RoPE |
| 0x28 | KV_WRITE | V | 4 | Attention |
| 0x29 | KV_READ | M | 4 | Attention |
| 0x2A | KV_RESET | S | 1 | Attention |
| 0x30 | SADD | S | 1 | 控制 |
| 0x31 | SMUL | S | 2 | RMSNorm |
| 0x32 | SDIV | S | 8 | Softmax |
| 0x33 | BNZ | S | 1+2 | 循环控制 |
| 0x34 | HALT | S | 1 | 终止 |
