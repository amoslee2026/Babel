---
module: M12
type: FSM
status: complete
fsm_name: SoftMax Pipeline FSM
parent_mas: M12/MAS.md
---

# M12: SoftMax Pipeline FSM

## 1. Overview

SoftMax Pipeline FSM 是 M12 SoftMax Unit 的核心状态机，驱动 4-Stage Pipeline 计算：Max Finder → Exp Approx → Sum Acc → Normalizer。该 FSM 控制 SoftMax 概率计算的完整流程，确保数值稳定性和精度要求，实现高效的并行流水线处理。

**核心特性**：

| Feature | Description |
|---------|-------------|
| State Count | 7 states (IDLE + 4 pipeline stages + COMPLETE + ERROR) |
| Pipeline Mode | 4-stage parallel pipeline |
| Total Latency | 21 cycles (full pipeline) |
| Throughput | 1 vector per 21 cycles |
| Numerical Stability | Max subtraction before exp (overflow prevention) |

**时钟域**：CLK_SYS (250-500 MHz)
**复位策略**：同步复位，初始状态 IDLE

## 2. State Definition

### 2.1 State List

| State ID | State Name | Description | Latency |
|----------|------------|-------------|---------|
| 0 | IDLE | 空闲状态，等待 score_valid 启动 | - |
| 1 | STAGE1_MAX | Max Finder 阶段，并行树结构查找最大值 | 8 cycles |
| 2 | STAGE2_EXP | Exponential Approximator 阶段，计算 exp(x - max) | 2 cycles |
| 3 | STAGE3_SUM | Sum Accumulator 阶段，并行累加 exp 结果 | 8 cycles |
| 4 | STAGE4_NORM | Normalizer 阶段，除法归一化输出概率 | 3 cycles |
| 5 | COMPLETE | 完成状态，输出 prob_valid，更新统计计数 | 1 cycle |
| 6 | ERROR | 错误状态，处理溢出/精度异常 | - |

### 2.2 State Encoding

```verilog
// State encoding (one-hot for efficient synthesis)
localparam [6:0] S_IDLE       = 7'b0000001;
localparam [6:0] S_STAGE1_MAX = 7'b0000010;
localparam [6:0] S_STAGE2_EXP = 7'b0000100;
localparam [6:0] S_STAGE3_SUM = 7'b0001000;
localparam [6:0] S_STAGE4_NORM = 7'b0010000;
localparam [6:0] S_COMPLETE   = 7'b0100000;
localparam [6:0] S_ERROR      = 7'b1000000;
```

### 2.3 Pipeline Stage Counter

每个 pipeline stage 使用计数器控制状态转换：

| Stage | Counter Name | Max Value | Description |
|-------|--------------|-----------|-------------|
| Stage 1 | `stage1_cnt` | 7 (0-7) | Max Finder tree levels |
| Stage 2 | `stage2_cnt` | 1 (0-1) | Exp Approx cycles |
| Stage 3 | `stage3_cnt` | 7 (0-7) | Sum Acc tree levels |
| Stage 4 | `stage4_cnt` | 2 (0-2) | Newton-Raphson iterations |

## 3. State Transitions

### 3.1 Transition Diagram

```
                          +-------+
                          | IDLE  |
                          +-------+
                              |
                              | softmax_start & score_valid & score_ready
                              v
                          +-------+
                          |STAGE1 |
                          | _MAX  |
                          +-------+
                              |
                              | stage1_cnt == 7 (max_val ready)
                              v
                          +-------+
                          |STAGE2 |
                          | _EXP  |
                          +-------+
                              |
                              | stage2_cnt == 1 (exp_vec ready)
                              v
                          +-------+
                          |STAGE3 |
                          | _SUM  |
                          +-------+
                              |
                              | stage3_cnt == 7 (sum_val ready)
                              v
                          +-------+
                          |STAGE4 |
                          | _NORM |
                          +-------+
                              |
                              | stage4_cnt == 2 & prob_ready
                              v
                          +-------+
                          |COMPLETE|
                          +-------+
                              |
                              | prob_valid ack & more_vectors
                              v
                          +-------+
                          | IDLE  | (loop for next vector)
                          +-------+

Error Handling:
  Any State --[error_detected]--> ERROR --[error_clear]--> IDLE

Backpressure:
  STAGE4_NORM --[prob_ready=0]--> STAGE4_NORM (stall)
```

### 3.2 Transition Table

| Current State | Condition | Next State | Transition Cycle |
|---------------|-----------|------------|------------------|
| IDLE | `softmax_start=1 & score_valid=1 & score_ready=1` | STAGE1_MAX | 1 |
| IDLE | `softmax_start=0` | IDLE | - |
| IDLE | `score_valid=0` | IDLE | - |
| IDLE | `softmax_abort=1` | IDLE (abort) | 1 |
| STAGE1_MAX | `stage1_cnt=7 & max_valid=1` | STAGE2_EXP | 1 |
| STAGE1_MAX | `stage1_cnt<7` | STAGE1_MAX (continue) | - |
| STAGE1_MAX | `overflow_input=1` | ERROR | 1 |
| STAGE2_EXP | `stage2_cnt=1 & exp_valid=1` | STAGE3_SUM | 1 |
| STAGE2_EXP | `stage2_cnt<1` | STAGE2_EXP (continue) | - |
| STAGE2_EXP | `overflow_exp=1 or underflow_exp=1` | ERROR | 1 |
| STAGE3_SUM | `stage3_cnt=7 & sum_valid=1` | STAGE4_NORM | 1 |
| STAGE3_SUM | `stage3_cnt<7` | STAGE3_SUM (continue) | - |
| STAGE3_SUM | `sum_zero=1` | ERROR | 1 |
| STAGE4_NORM | `stage4_cnt=2 & norm_valid=1 & prob_ready=1` | COMPLETE | 1 |
| STAGE4_NORM | `prob_ready=0` | STAGE4_NORM (stall) | - |
| STAGE4_NORM | `precision_loss=1` | ERROR (warn) | 1 |
| COMPLETE | `complete_done=1 & more_vectors=1` | STAGE1_MAX | 1 |
| COMPLETE | `complete_done=1 & more_vectors=0` | IDLE | 1 |
| ERROR | `error_clear=1` | IDLE | 1 |
| Any State | `softmax_abort=1` | IDLE | 1 |
| Any State | `soft_reset=1` | IDLE | 1 |

### 3.3 Pipeline Backpressure Flow

| Stage | Stall Condition | Backpressure Propagation |
|-------|-----------------|--------------------------|
| Stage 1 | `score_valid=0` | Pipeline start stall |
| Stage 2 | None (buffer) | Continue if Stage 1 ready |
| Stage 3 | None (buffer) | Continue if Stage 2 ready |
| Stage 4 | `prob_ready=0` | Output stall, internal stages continue |

## 4. State Behaviors

### 4.1 IDLE State

**行为**：等待 SoftMax 计算启动，初始化 pipeline 配置。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `softmax_start` | 1 | SoftMax 计算启动 |
| `score_valid` | 1 | Score 数据有效 |
| `score_ready` | 1 | Score 接收就绪（输出） |
| `score_data` | 512 | Score 向量数据 |
| `score_len` | 8 | Score 向量长度 (1-256) |
| `score_seq_id` | 16 | Sequence ID 标识 |
| `score_precision` | 2 | 精度模式 (FP16/FP8) |
| `softmax_abort` | 1 | 计算中止请求 |
| `soft_reset` | 1 | 软复位请求 |

**输出信号**：

| Signal | Width | Value | Description |
|--------|-------|-------|-------------|
| `score_ready` | 1 | 1 | 接收就绪 |
| `softmax_busy` | 1 | 0 | 空闲状态 |
| `softmax_done` | 1 | 0 | 未完成 |
| `softmax_error` | 1 | 0 | 无错误 |
| `fsm_status` | 4 | 0x0 | IDLE 状态码 |

**内部逻辑**：

```verilog
// IDLE state logic
always_ff @(posedge clk_sys) begin
  if (rst_sys_n == 0 || soft_reset) begin
    fsm_state <= S_IDLE;
    stage1_cnt <= 0;
    stage2_cnt <= 0;
    stage3_cnt <= 0;
    stage4_cnt <= 0;
    error_flag <= 0;
    error_code <= 0;
  end else if (fsm_state == S_IDLE) begin
    if (softmax_abort) begin
      // Abort: stay in IDLE, clear all
      fsm_state <= S_IDLE;
    end else if (softmax_start && score_valid) begin
      // Start: load input config
      fsm_state <= S_STAGE1_MAX;
      current_len <= score_len;
      current_seq_id <= score_seq_id;
      current_precision <= score_precision;
      score_ready <= 0;  // Not ready during processing
      softmax_busy <= 1;
      stage1_cnt <= 0;
    end else begin
      score_ready <= 1;  // Ready to receive
    end
  end
end
```

### 4.2 STAGE1_MAX State

**行为**：执行 Max Finder 并行树结构，查找输入向量最大值。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `score_data` | 512 | Score 向量 (256 x FP16) |
| `current_len` | 8 | 当前向量长度 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `stage1_max` | 16 | 输出最大值 |
| `max_valid` | 1 | 最大值有效标志 |
| `overflow_input` | 1 | 输入溢出检测 |

**内部操作**：

1. **Level 0**: 256 inputs → 128 comparisons (并行)
2. **Level 1-7**: Tree reduction to single max value
3. **Total**: 8 levels, log2(256) comparisons
4. **Latency**: 8 cycles

**Max Finder 实现**：

```verilog
// Max Finder tree logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_STAGE1_MAX) begin
    stage1_cnt <= stage1_cnt + 1;
    
    // Parallel tree reduction
    case (stage1_cnt)
      0: begin
        // Level 0: 256 -> 128
        for (int i = 0; i < 128; i++) begin
          level0_max[i] = max(score_data[2*i], score_data[2*i+1]);
        end
      end
      1: begin
        // Level 1: 128 -> 64
        for (int i = 0; i < 64; i++) begin
          level1_max[i] = max(level0_max[2*i], level0_max[2*i+1]);
        end
      end
      // ... levels 2-6 similarly
      7: begin
        // Level 7: 2 -> 1 (final max)
        stage1_max <= max(level6_max[0], level6_max[1]);
        max_valid <= 1;
        
        // Overflow check
        if (stage1_max > FP16_MAX) begin
          overflow_input <= 1;
          fsm_state <= S_ERROR;
        end else begin
          fsm_state <= S_STAGE2_EXP;
          stage2_cnt <= 0;
        end
      end
    endcase
  end
end
```

**Comparator Details**：

| Parameter | Value | Description |
|-----------|-------|-------------|
| Input Width | 512 bits | 256 x FP16 elements |
| Comparator | 16-bit FP16 | IEEE 754 half-precision |
| Tree Depth | 8 levels | Parallel reduction |
| Latency | 8 cycles | Pipeline stage |

### 4.3 STAGE2_EXP State

**行为**：计算 exp(x_i - max(x))，使用 Hybrid 近似方法（LUT + Taylor）。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `score_data` | 512 | Score 向量 |
| `stage1_max` | 16 | 最大值 |
| `approx_method` | 2 | 近似方法选择 (0=LUT, 1=Taylor, 2=Hybrid) |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `stage2_exp_valid` | 512 | exp 结果向量 (256 x FP16) |
| `overflow_exp` | 1 | 指数溢出 |
| `underflow_exp` | 1 | 指数下溢 |

**内部操作**：

1. **Cycle 0**: LUT coarse approximation
   - 计算 normalized input: `x_norm = score_data[i] - max_val`
   - LUT address: `addr = clamp(x_norm * lut_scale, 0, lut_entries-1)`
   - LUT read: `exp_base = lut_table[addr]`

2. **Cycle 1**: Taylor correction (if Hybrid)
   - Residual: `residual = x_norm - lut_base_addr`
   - Taylor: `exp_correction = 1 + residual + residual^2/2`
   - Final: `exp_result = exp_base * exp_correction`

**Exp Approximator 实现**：

```verilog
// Exponential Approximator logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_STAGE2_EXP) begin
    stage2_cnt <= stage2_cnt + 1;
    
    case (stage2_cnt)
      0: begin
        // Cycle 0: LUT approximation
        for (int i = 0; i < 256; i++) begin
          // Subtract max for numerical stability
          x_norm[i] = score_data[i] - stage1_max;
          
          // Clamp to safe range [-8, 0]
          if (x_norm[i] < -8.0) x_norm[i] = -8.0;
          
          // LUT lookup
          lut_addr[i] = (x_norm[i] + 8.0) * lut_scale;
          exp_base[i] = lut_table[lut_addr[i]];
        end
      end
      
      1: begin
        // Cycle 1: Taylor correction (Hybrid method)
        for (int i = 0; i < 256; i++) begin
          if (approx_method == 2) begin // Hybrid
            // Linear interpolation between LUT entries
            lut_addr_next[i] = lut_addr[i] + 1;
            exp_next[i] = lut_table[lut_addr_next[i]];
            interp_factor[i] = fractional(x_norm[i] * lut_scale);
            exp_interpolated[i] = exp_base[i] + 
                                  (exp_next[i] - exp_base[i]) * interp_factor[i];
            
            // Taylor correction for residual
            residual[i] = x_norm[i] - lut_base_value(lut_addr[i]);
            taylor_corr[i] = 1 + residual[i] + residual[i]*residual[i]/2;
            
            stage2_exp_valid[i] = exp_interpolated[i] * taylor_corr[i];
          end else if (approx_method == 0) begin // LUT only
            stage2_exp_valid[i] = exp_base[i];
          end else begin // Taylor only
            // Taylor expansion: 1 + x + x^2/2 + x^3/6 + x^4/24
            stage2_exp_valid[i] = taylor_exp(x_norm[i], taylor_order);
          end
          
          // Overflow/Underflow detection
          if (stage2_exp_valid[i] > FP16_MAX) overflow_exp <= 1;
          if (stage2_exp_valid[i] < FP16_MIN && x_norm[i] > -8) underflow_exp <= 1;
        end
        
        // Error check
        if (overflow_exp || underflow_exp) begin
          fsm_state <= S_ERROR;
          error_code <= overflow_exp ? 0x01 : 0x02;
        end else begin
          fsm_state <= S_STAGE3_SUM;
          stage3_cnt <= 0;
        end
      end
    endcase
  end
end
```

**Approximation Accuracy**：

| Method | Error | Latency | Area |
|--------|-------|---------|------|
| LUT | < 0.05% | 1 cycle | Medium |
| Taylor | < 0.1% | 4 cycles | Small |
| Hybrid | < 0.02% | 2 cycles | Medium |

### 4.4 STAGE3_SUM State

**行为**：执行 Sum Accumulator 并行树结构，累加所有 exp 结果。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `stage2_exp_valid` | 512 | exp 结果向量 |
| `current_precision` | 2 | 精度模式 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `stage3_sum` | 32 | 累加和 (FP32 for precision) |
| `sum_valid` | 1 | 累加和有效标志 |
| `sum_zero` | 1 | 累加和为零错误 |

**内部操作**：

1. **Level 0**: 256 exp values → 128 additions
2. **Level 1-7**: Tree reduction to single sum value
3. **Total**: 8 levels, log2(256) additions
4. **Latency**: 8 cycles

**Sum Accumulator 实现**：

```verilog
// Sum Accumulator tree logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_STAGE3_SUM) begin
    stage3_cnt <= stage3_cnt + 1;
    
    // Precision handling
    if (current_precision == 0) begin // FP16
      // Use FP32 internal accumulator
      accumulator_width = 32;
    end else begin // FP8
      // Use FP16 internal accumulator
      accumulator_width = 16;
    end
    
    // Parallel tree reduction
    case (stage3_cnt)
      0: begin
        // Level 0: 256 -> 128
        for (int i = 0; i < 128; i++) begin
          level0_sum[i] = fp_add(stage2_exp_valid[2*i], 
                                 stage2_exp_valid[2*i+1], accumulator_width);
        end
      end
      1: begin
        // Level 1: 128 -> 64
        for (int i = 0; i < 64; i++) begin
          level1_sum[i] = fp_add(level0_sum[2*i], level0_sum[2*i+1], accumulator_width);
        end
      end
      // ... levels 2-6 similarly
      7: begin
        // Level 7: 2 -> 1 (final sum)
        stage3_sum <= fp_add(level6_sum[0], level6_sum[1], accumulator_width);
        sum_valid <= 1;
        
        // Zero sum check (critical error)
        if (stage3_sum == 0) begin
          sum_zero <= 1;
          fsm_state <= S_ERROR;
          error_code <= 0x03;
        end else begin
          fsm_state <= S_STAGE4_NORM;
          stage4_cnt <= 0;
        end
      end
    endcase
  end
end
```

**Precision Handling**：

| Precision Mode | Internal Accumulator | Output Width |
|----------------|----------------------|--------------|
| FP16 | FP32 (32-bit) | 32 bits |
| FP8_E4M3 | FP16 (16-bit) | 16 bits |
| FP8_E5M2 | FP16 (16-bit) | 16 bits |

### 4.5 STAGE4_NORM State

**行为**：执行 Normalizer 除法归一化，使用 Newton-Raphson 迭代。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `stage2_exp_valid` | 512 | exp 结果向量 |
| `stage3_sum` | 32 | 累加和 |
| `prob_ready` | 1 | 输出接收就绪（外部） |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `stage4_prob` | 512 | 归一化概率向量 (256 x FP16) |
| `norm_valid` | 1 | 归一化有效标志 |
| `prob_checksum` | 32 | 输出校验和 |
| `precision_loss` | 1 | 精度丢失警告 |

**内部操作**：

1. **Iteration 0**: LUT-based initial reciprocal approximation
   - `inv_sum_init = lut_reciprocal(stage3_sum)`
   
2. **Iteration 1**: Newton-Raphson refinement
   - `inv_sum_1 = inv_sum_init * (2 - stage3_sum * inv_sum_init)`
   
3. **Iteration 2**: Final refinement + normalization
   - `inv_sum_final = inv_sum_1 * (2 - stage3_sum * inv_sum_1)`
   - `prob_i = stage2_exp_valid[i] * inv_sum_final`

**Normalizer 实现**：

```verilog
// Normalizer logic (Newton-Raphson division)
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_STAGE4_NORM) begin
    if (prob_ready == 0) begin
      // Backpressure: stall in STAGE4
      fsm_state <= S_STAGE4_NORM;
    end else begin
      stage4_cnt <= stage4_cnt + 1;
      
      case (stage4_cnt)
        0: begin
          // Iteration 0: LUT-based initial approximation
          // 1/sum ≈ lut_reciprocal(sum)
          lut_inv_addr = reciprocal_lut_index(stage3_sum);
          inv_sum_init <= reciprocal_lut[lut_inv_addr];
        end
        
        1: begin
          // Iteration 1: Newton-Raphson refinement
          // x_new = x * (2 - sum * x)
          sum_times_init = fp_mul(stage3_sum, inv_sum_init);
          two_minus = fp_sub(2.0, sum_times_init);
          inv_sum_1 = fp_mul(inv_sum_init, two_minus);
        end
        
        2: begin
          // Iteration 2: Final refinement + normalization
          // Final reciprocal
          sum_times_1 = fp_mul(stage3_sum, inv_sum_1);
          two_minus_final = fp_sub(2.0, sum_times_1);
          inv_sum_final = fp_mul(inv_sum_1, two_minus_final);
          
          // Normalize all elements
          for (int i = 0; i < 256; i++) begin
            stage4_prob[i] = fp_mul(stage2_exp_valid[i], inv_sum_final);
            
            // Clamp to (0, 1) range
            if (stage4_prob[i] < 0) stage4_prob[i] = 0;
            if (stage4_prob[i] > 1) stage4_prob[i] = 1;
          end
          
          // Compute checksum
          prob_checksum <= fp_sum(stage4_prob);
          
          // Precision loss check
          expected_sum = 1.0;
          deviation = abs(prob_checksum - expected_sum);
          if (deviation > PRECISION_THRESHOLD) begin
            precision_loss <= 1;
          end
          
          norm_valid <= 1;
          fsm_state <= S_COMPLETE;
        end
      endcase
    end
  end
end
```

**Newton-Raphson Accuracy**：

| Iterations | Error | Latency |
|------------|-------|---------|
| 1 | ~5% | 1 cycle |
| 2 | ~1% | 2 cycles |
| 3 | ~0.1% | 3 cycles |

### 4.6 COMPLETE State

**行为**：输出概率向量，更新统计计数，检查是否有更多向量待处理。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `score_seq_id` | 16 | Sequence ID 标识 |
| `vector_queue_valid` | 1 | 更多向量待处理标志 |

**输出信号**：

| Signal | Width | Value | Description |
|--------|-------|-------|-------------|
| `prob_valid` | 1 | 1 | Probability 输出有效 |
| `prob_data` | 512 | stage4_prob | Probability 向量数据 |
| `prob_len` | 8 | current_len | Probability 向量长度 |
| `prob_seq_id` | 16 | score_seq_id | Sequence ID 标识 |
| `prob_checksum` | 32 | computed | 输出校验和 |
| `softmax_done` | 1 | 1 | SoftMax 计算完成 |
| `softmax_busy` | 1 | 0 | 空闲状态 |
| `softmax_latency` | 16 | cycle_count | 实际计算周期数 |

**完成逻辑**：

```verilog
// Complete state logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_COMPLETE) begin
    // Output valid signals
    prob_valid <= 1;
    prob_data <= stage4_prob;
    prob_len <= current_len;
    prob_seq_id <= current_seq_id;
    softmax_done <= 1;
    softmax_busy <= 0;
    
    // Update statistics
    softmax_latency <= cycle_counter;
    softmax_cycles <= softmax_cycles + cycle_counter;
    cycle_counter <= 0;
    
    // Check for more vectors
    if (vector_queue_valid && score_valid) begin
      more_vectors <= 1;
    end else begin
      more_vectors <= 0;
    end
    
    // Clear internal valid signals
    max_valid <= 0;
    exp_valid <= 0;
    sum_valid <= 0;
    norm_valid <= 0;
    
    // Transition
    if (more_vectors) begin
      fsm_state <= S_STAGE1_MAX;
      stage1_cnt <= 0;
      softmax_busy <= 1;
      softmax_done <= 0;
    end else begin
      fsm_state <= S_IDLE;
      score_ready <= 1;
    end
  end
end
```

### 4.7 ERROR State

**行为**：处理错误状态，设置错误标志，等待错误清除后返回 IDLE。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `error_clear` | 1 | 错误清除请求（软件） |

**输出信号**：

| Signal | Width | Value | Description |
|--------|-------|-------|-------------|
| `softmax_error` | 1 | 1 | 错误标志 |
| `softmax_done` | 1 | 0 | 未完成 |
| `softmax_busy` | 1 | 0 | 停止处理 |
| `error_code` | 8 | specific | 具体错误码 |
| `error_vector_idx` | 8 | position | 错误发生位置 |

**错误处理逻辑**：

```verilog
// Error state logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_ERROR) begin
    softmax_error <= 1;
    softmax_busy <= 0;
    softmax_done <= 0;
    
    // Record error details
    error_status_reg <= error_code;
    error_vector_idx_reg <= error_vector_idx;
    
    // Generate IRQ if enabled
    if (irq_en) begin
      irq_error <= 1;
    end
    
    // Wait for software to clear
    if (error_clear || softmax_abort) begin
      fsm_state <= S_IDLE;
      error_flag <= 0;
      error_code <= 0;
      softmax_error <= 0;
      score_ready <= 1;
    end
  end
end
```

## 5. Control Signals

### 5.1 FSM Control Inputs

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| `clk_sys` | 1 | System | 时钟信号 (250-500 MHz) |
| `rst_sys_n` | 1 | System | 异步复位，低有效 |
| `soft_reset` | 1 | SM_CTRL[3] | 软复位（Pipeline 复位） |
| `softmax_start` | 1 | SM_CTRL[1] | 计算启动 |
| `softmax_abort` | 1 | SM_CTRL[2] | 计算中止 |
| `approx_method` | 2 | SM_CONFIG[2:3] | 指数近似方法 |
| `precision_mode` | 2 | SM_CONFIG[0:1] | 精度模式 |
| `parallel_sum` | 1 | SM_CONFIG[4] | 并行累加使能 |
| `overflow_check` | 1 | SM_CONFIG[6] | 溢出检测使能 |

### 5.2 FSM Control Outputs

| Signal | Width | Destination | Description |
|--------|-------|-------------|-------------|
| `fsm_state` | 7 | Internal | 当前状态 (one-hot) |
| `fsm_status` | 4 | SM_STATUS[7:4] | 状态码 |
| `softmax_busy` | 1 | SM_STATUS[1] | 计算进行中 |
| `softmax_done` | 1 | SM_STATUS[2] | 计算完成 |
| `softmax_error` | 1 | SM_STATUS[3] | 错误标志 |
| `softmax_latency` | 16 | SM_LATENCY | 实际计算周期数 |

### 5.3 Pipeline Stage Interface Signals

| Signal | Width | Direction | Timing |
|--------|-------|-----------|--------|
| `stage1_max` | 16 | Internal | STAGE1_MAX output |
| `max_valid` | 1 | Internal | Stage 1 complete |
| `stage2_exp_valid` | 512 | Internal | STAGE2_EXP output |
| `exp_valid` | 1 | Internal | Stage 2 complete |
| `stage3_sum` | 32 | Internal | STAGE3_SUM output |
| `sum_valid` | 1 | Internal | Stage 3 complete |
| `stage4_prob` | 512 | Internal | STAGE4_NORM output |
| `norm_valid` | 1 | Internal | Stage 4 complete |

### 5.4 External Interface Signals

| Signal | Width | Direction | Timing |
|--------|-------|-----------|--------|
| `score_valid` | 1 | Input | IDLE state check |
| `score_ready` | 1 | Output | IDLE/COMPLETE toggle |
| `prob_valid` | 1 | Output | COMPLETE state |
| `prob_ready` | 1 | Input | STAGE4 backpressure |

## 6. Timing Constraints

### 6.1 State Timing

| State | Min Duration | Max Duration | Typical |
|-------|--------------|--------------|---------|
| IDLE | 0 cycles | Unlimited | - |
| STAGE1_MAX | 8 cycles | 8 cycles | 8 cycles |
| STAGE2_EXP | 2 cycles | 2 cycles | 2 cycles |
| STAGE3_SUM | 8 cycles | 8 cycles | 8 cycles |
| STAGE4_NORM | 3 cycles | Unlimited (stall) | 3 cycles |
| COMPLETE | 1 cycle | 1 cycle | 1 cycle |
| ERROR | 0 cycles | Unlimited | - |

### 6.2 Pipeline Latency

完整 SoftMax 计算 latency：

```
SoftMax_Latency = STAGE1_MAX + STAGE2_EXP + STAGE3_SUM + STAGE4_NORM + COMPLETE
                = 8 + 2 + 8 + 3 + 1 = 22 cycles (typical)
                
Throughput = 1 vector / 21 cycles (without COMPLETE overhead)
```

### 6.3 Timing at Different Clock Frequencies

| CLK_SYS | Latency (cycles) | Latency (time) | Throughput |
|---------|------------------|----------------|------------|
| 500 MHz | 21 cycles | 42 ns | 23.8M vectors/s |
| 250 MHz | 21 cycles | 84 ns | 11.9M vectors/s |

### 6.4 Critical Path

| Path | Delay Target | Implementation |
|------|---------------|----------------|
| Max Comparator | < 1 CLK_SYS | Parallel tree |
| Exp LUT Access | < 1 CLK_SYS | SRAM-based LUT |
| FP Adder | < 1 CLK_SYS | IEEE 754 compliant |
| FP Multiplier | < 1 CLK_SYS | IEEE 754 compliant |
| Newton-Raphson | < 1 CLK_SYS | Iterative multiplier |

## 7. Error Handling

### 7.1 Error Types

| Error Code | Description | Detection Condition | Recovery |
|------------|-------------|---------------------|----------|
| 0x00 | No error | - | - |
| 0x01 | Input Overflow | score_data > FP16 max | Saturate + flag |
| 0x02 | Exp Overflow | exp > FP16 max | Saturate + flag |
| 0x03 | Exp Underflow | exp < FP16 min | Saturate to 0 + flag |
| 0x04 | Sum Zero | sum_val = 0 | Error + bypass |
| 0x05 | Precision Loss | sum deviation > threshold | Warning flag |
| 0x06 | Timeout | computation > limit | Error + abort |
| 0x07 | Division Error | inv_sum invalid | Error + bypass |

### 7.2 Error Detection Mechanism

```verilog
// Error detection logic (always active)
always_ff @(posedge clk_sys) begin
  // Input overflow check
  if (overflow_check_en) begin
    for (int i = 0; i < 256; i++) begin
      if (score_data[i] > FP16_MAX) begin
        overflow_input <= 1;
        error_vector_idx <= i;
      end
    end
  end
  
  // Exp overflow/underflow check (Stage 2)
  if (fsm_state == S_STAGE2_EXP) begin
    for (int i = 0; i < 256; i++) begin
      if (stage2_exp_valid[i] > FP16_MAX) begin
        overflow_exp <= 1;
        error_vector_idx <= i;
      end
      if (stage2_exp_valid[i] < FP16_MIN && x_norm[i] > -8) begin
        underflow_exp <= 1;
        error_vector_idx <= i;
      end
    end
  end
  
  // Sum zero check (Stage 3)
  if (fsm_state == S_STAGE3_SUM && stage3_cnt == 7) begin
    if (stage3_sum == 0) begin
      sum_zero <= 1;
    end
  end
  
  // Precision loss check (Stage 4)
  if (fsm_state == S_STAGE4_NORM && stage4_cnt == 2) begin
    if (abs(prob_checksum - 1.0) > PRECISION_THRESHOLD) begin
      precision_loss <= 1;
    end
  end
end
```

### 7.3 Error Recovery Sequence

```
Error Recovery:
  1. fsm_state -> S_ERROR
  2. Set softmax_error = 1, update SM_ERROR_STATUS
  3. Record error_vector_idx (position)
  4. Generate irq_error if irq_en = 1
  5. Stall pipeline (all stages stop)
  6. Wait for software ack (SM_ERROR_STATUS write)
  7. error_clear -> fsm_state = S_IDLE
  8. Clear error flags
  9. Resume normal operation
```

### 7.4 Timeout Mechanism

```verilog
// Timeout counter
localparam TIMEOUT_SOFTMAX = 1000; // cycles

always_ff @(posedge clk_sys) begin
  if (fsm_state inside {S_STAGE1_MAX, S_STAGE2_EXP, S_STAGE3_SUM, S_STAGE4_NORM}) begin
    total_cnt <= total_cnt + 1;
    
    if (total_cnt >= TIMEOUT_SOFTMAX) begin
      timeout_err <= 1;
      error_code <= 0x06;
      fsm_state <= S_ERROR;
    end
  end else begin
    total_cnt <= 0;
    timeout_err <= 0;
  end
end
```

## 8. Implementation Notes

### 8.1 Synthesis Guidelines

1. **State Encoding**: 使用 one-hot encoding 提高速度，减少状态转换延迟

2. **Pipeline Registers**: 每个 Stage 输出使用 pipeline register 防止毛刺

3. **Clock Gating**: IDLE 状态可关闭 pipeline clock 减少功耗

4. **Numerical Stability**: Max subtraction 在 Stage 1 完成，确保 exp 不会溢出

### 8.2 LUT Table Configuration

| Parameter | Register | Default | Range |
|-----------|----------|---------|-------|
| lut_entries | SM_CONFIG[8:15] | 128 | 16-256 |
| lut_precision_bits | SM_APPROX_CTRL[0:7] | 10 | 8-12 |
| input_range_bits | SM_APPROX_CTRL[12:15] | 4 | 3-5 |
| taylor_order | SM_APPROX_CTRL[8:11] | 2 | 1-4 |

### 8.3 Verification Checklist

| Check | Description |
|-------|-------------|
| State Coverage | 所有 7 状态可达 |
| Transition Coverage | 所有转换条件测试 |
| Pipeline Timing | 21 cycles latency 正确 |
| Numerical Stability | Max subtraction 防止溢出 |
| Backpressure | prob_ready=0 stall 正确 |
| Error Recovery | 各类错误恢复正确 |
| Precision Modes | FP16/FP8 精度正确 |
| Approximation Accuracy | 指数近似误差 < 0.1% |
| Output Verification | Sum(prob) ≈ 1.0 |

### 8.4 Performance Counters

| Counter | Register | Width | Purpose |
|---------|----------|-------|---------|
| Vector Count | SM_STATS_COUNTERS[0:15] | 16 | 完成向量数 |
| Cycle Count | SM_STATS_COUNTERS[16:31] | 16 | 累计周期数 |
| Error Count | Internal | 8 | 错误计数 |
| Stall Count | Internal | 16 | Stall 周期数 |

### 8.5 Integration Requirements

| Requirement | Description |
|-------------|-------------|
| Reset Sequence | rst_sys_n -> IDLE, all signals cleared |
| Clock Domain | Single CLK_SYS, no CDC |
| Power Domain | PD_MAIN, DVFS support |
| Debug Access | FSM state via SM_STATUS register |
| Interrupt | irq_error on error condition |

### 8.6 Power Budget

| Stage | Power (mW) | Percentage |
|-------|------------|------------|
| Max Finder | 15 | 18% |
| Exp Approx | 25 | 29% |
| Sum Acc | 15 | 18% |
| Normalizer | 20 | 24% |
| Control + FSM | 10 | 12% |
| **Total** | **85** | 100% |

## 9. References

- **Parent MAS**: `/spec_mas/M12/MAS.md` - Section 3.1-3.6 Pipeline Architecture
- **REQ-SW-003**: SoftMax operator support requirement
- **Interface**: `/spec_mas/M12/MAS.md` Section 2.1-2.2 Interface Specification
- **Timing**: `/spec_mas/M12/MAS.md` Section 4.1-4.4 Timing Parameters