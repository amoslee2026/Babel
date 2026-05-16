---
module: M01
type: verification
status: complete
generated: 2026-05-12T09:20:00Z
---

# M01_DataflowController — Verification Specification

## 1. 功能覆盖点

### 1.1 算子覆盖率

| 覆盖组          | 覆盖点                                      | 目标 |
|-----------------|---------------------------------------------|------|
| op_code         | Attention(0x01), FFN(0x02), RMSNorm(0x03), RoPE(0x04) | 100% |
| precision       | FP32, FP16, INT8（每算子）                  | 100% |
| op × prec 交叉  | 4 算子 × 3 精度 = 12 组合                   | 100% |
| illegal_opcode  | op_code 不在 {0x01–0x04}                    | 覆盖 |

### 1.2 线程切换

| 覆盖点                          | 描述                              |
|---------------------------------|-----------------------------------|
| TID=0 → TID=1 切换              | 正常 Round-Robin                  |
| TID=1 → TID=0 切换              | 正常 Round-Robin                  |
| 单线程连续执行（另一线程 IDLE） | THREAD_CFG 禁用一个线程           |
| 切换时 IQ 非空                  | 切换后立即 FETCH_INST             |
| 切换时 IQ 空                    | 切换后进入 IDLE                   |

### 1.3 流水线利用率

| 覆盖点                  | 目标值       |
|-------------------------|--------------|
| PERF_UTIL >= 80%        | 连续 1000 算子序列 |
| 背压（IQ 满）           | IF 级暂停，不丢指令 |
| AXI 延迟注入（8 cycle） | 利用率下降可观测    |

### 1.4 混合精度

| 覆盖点                        | 描述                        |
|-------------------------------|-----------------------------|
| 同一线程连续切换精度          | FP32→FP16→INT8              |
| 两线程不同精度并发            | TID0=FP32, TID1=INT8        |
| INT8 仅限 FFN（其他算子拒绝） | 非法精度 → ERROR 状态       |

---

## 2. SVA 断言

```systemverilog
// 断言1：m00_op_valid 拉高后，必须在 256 周期内收到 m00_op_ready
property p_dispatch_timeout;
  @(posedge clk) disable iff (rst_n == 0)
  $rose(m00_op_valid) |-> ##[1:256] m00_op_ready;
endproperty
assert property (p_dispatch_timeout) else $error("DISPATCH timeout");

// 断言2：m00_done 后，下一周期 STATUS[1] 必须清零或进入 FETCH_INST
property p_done_to_wb;
  @(posedge clk) disable iff (rst_n == 0)
  $rose(m00_done) |-> ##[1:5] (state == WRITEBACK || state == FETCH_INST);
endproperty
assert property (p_done_to_wb);

// 断言3：上下文切换不超过 4 周期
property p_ctx_switch_latency;
  @(posedge clk) disable iff (rst_n == 0)
  $rose(ctx_switch_req) |-> ##[1:4] ctx_switch_done;
endproperty
assert property (p_ctx_switch_latency);

// 断言4：irq_op_done 只在 WRITEBACK 状态拉高
property p_irq_only_in_wb;
  @(posedge clk) disable iff (rst_n == 0)
  irq_op_done |-> (state == WRITEBACK);
endproperty
assert property (p_irq_only_in_wb);

// 断言5：ERROR 状态下 m00_op_valid 不得拉高
property p_no_dispatch_in_error;
  @(posedge clk) disable iff (rst_n == 0)
  (state == ERROR) |-> !m00_op_valid;
endproperty
assert property (p_no_dispatch_in_error);
```

---

## 3. 仿真场景

### 场景 S01：Attention 推理（单线程）

```
配置：TID=0, prec=FP32, op=Attention
步骤：
  1. 写 CTRL[0]=1，OP_QUEUE 填入 1 条 Attention 指令
  2. 等待 irq_op_done
  3. 检查 PERF_CNT0 == 1，STATUS[0]=1（IDLE）
预期：m00_op_code=0x01, m00_op_prec=2'b00，m00_done 后 WB 正常
```

### 场景 S02：FFN 推理（INT8）

```
配置：TID=0, prec=INT8, op=FFN
步骤：
  1. 写 THREAD_CFG0[1:0]=2'b10（INT8）
  2. OP_QUEUE 填入 FFN 指令
  3. 等待 irq_op_done
预期：m00_op_prec=2'b10，无 ERROR
```

### 场景 S03：多线程并发（Attention + FFN）

```
配置：TID=0=Attention/FP16, TID=1=FFN/INT8
步骤：
  1. OP_QUEUE 交替填入 TID=0 Attention 和 TID=1 FFN 各 8 条
  2. 运行至队列清空
  3. 读取 PERF_UTIL
预期：
  - PERF_CNT0 == 8, PERF_CNT1 == 8
  - PERF_UTIL >= 0x0CCC（80% in Q16）
  - 无 irq_err
```

### 场景 S04：错误注入

```
步骤：
  1. 注入 illegal_opcode=0xFF
  2. 检查 FSM 进入 ERROR，irq_err 拉高
  3. 写 CTRL[1]=1 复位
  4. 确认 FSM 回 IDLE，irq_err 清零
```

### 场景 S05：AXI 背压

```
步骤：
  1. 拉低 axi_arready 保持 16 周期
  2. 确认 IF 级暂停，IQ 不溢出
  3. 释放 axi_arready，确认正常恢复
```
