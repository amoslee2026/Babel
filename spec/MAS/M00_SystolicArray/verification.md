---
module: M00
type: verification
status: complete
parent: MAS.md
generated: 2026-05-12T09:20:00Z
---

# M00_SystolicArray — Verification Spec

## 1. 功能覆盖点

| 覆盖点 ID | 描述 | 覆盖条件 |
|-----------|------|----------|
| COV_GEMM_FP32 | FP32 GEMM 正确性 | 随机 M×K×N，误差 < 1 ULP |
| COV_GEMM_FP16 | FP16 GEMM 正确性 | 随机 M×K×N，误差 < 2 ULP |
| COV_GEMM_INT8 | INT8 GEMM 正确性 | 随机 M×K×N，结果与参考完全一致 |
| COV_PREC_SWITCH | 精度动态切换 | FP32→FP16→INT8→FP32 连续切换无错误 |
| COV_WS_MODE | Weight Stationary 数据流 | 权重固定，多批激活值连续输入 |
| COV_OS_MODE | Output Stationary 数据流 | 部分和在 PE 内累加，多 tile 正确 |
| COV_DIM_MIN | 最小矩阵尺寸 | M=N=K=1 |
| COV_DIM_MAX | 最大矩阵尺寸 | M=N=32, K=1024 |
| COV_DIM_NON_SQUARE | 非方阵 | M≠N，K 任意 |
| COV_BACKPRESSURE | 背压处理 | result_ready=0 时 sa_stall 正确拉高 |
| COV_PIPELINE | 流水线连续输入 | DONE 后立即 sa_start，无气泡 |

## 2. 断言（SVA）

```systemverilog
// 吞吐量断言：FP32 模式下 1024 PE 每周期至少 1024 MAC
property throughput_fp32;
  @(posedge clk) disable iff (!rst_n)
  (fsm_state == COMPUTE && precision_mode == 2'b00)
  |-> (mac_count_per_cycle >= 1024);
endproperty
assert property (throughput_fp32)
  else $error("THROUGHPUT FAIL: FP32 MAC/cycle < 1024");

// 结果有效性断言：DONE 状态下 result_valid 必须为 1
property result_valid_in_done;
  @(posedge clk) disable iff (!rst_n)
  (fsm_state == DONE) |-> result_valid;
endproperty
assert property (result_valid_in_done);

// 背压断言：result_ready=0 时不丢数据
property no_data_loss_on_backpressure;
  @(posedge clk) disable iff (!rst_n)
  (result_valid && !result_ready) |=> result_valid;
endproperty
assert property (no_data_loss_on_backpressure);

// 精度切换安全断言：切换只能在 IDLE 状态
property precision_change_only_in_idle;
  @(posedge clk) disable iff (!rst_n)
  $changed(precision_mode) |-> (fsm_state == IDLE);
endproperty
assert property (precision_change_only_in_idle);
```

## 3. 仿真场景

### 场景 1：TinyStories 15M Attention GEMM（FP32）

```
矩阵规模：Q×K^T = [seq_len=64, d_head=64] × [d_head=64, seq_len=64]
精度：FP32
数据流：Weight Stationary
预期延迟：34 + 64 = 98 cycles
验证：输出与 numpy 参考实现误差 < 1e-5
```

### 场景 2：TinyStories 15M FFN GEMM（FP16）

```
矩阵规模：[64, 288] × [288, 768]（需 tiling，tile=32×32）
精度：FP16
数据流：Output Stationary
预期吞吐：≥ 1 TOPS
验证：输出与 FP32 参考实现误差 < 1e-3
```

### 场景 3：INT8 量化推理

```
矩阵规模：[32, 32] × [32, 32]（单 tile）
精度：INT8，权重和激活均量化为 INT8
数据流：Weight Stationary
验证：输出 INT32 累加结果与参考完全一致（bit-exact）
```

### 场景 4：边界与压力测试

```
- M=N=K=1（最小矩阵）
- M=32, N=32, K=1024（最大 K）
- 连续 100 次 GEMM，DONE→sa_start 无间隔
- 随机背压：result_ready 随机拉低
```

## 4. 覆盖率目标

| 类型 | 目标 |
|------|------|
| 代码覆盖率（行/分支） | ≥ 90% |
| 功能覆盖率 | 100%（所有 COV_* 点） |
| 断言通过率 | 100% |
| 精度误差 | FP32 < 1e-5，FP16 < 1e-3，INT8 bit-exact |
