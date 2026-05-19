---
module: M11
type: FSM
status: complete
parent: M11
fsm_type: Norm+RoPE Combined FSM
generated: "2026-05-17T17:00:00+08:00"
---

# M11 FSM: Norm+RoPE Combined FSM

## 1. Overview

Norm+RoPE Combined FSM 管理 M11 RMSNorm/RoPE Unit 的算子执行流程，实现 RMSNorm 和 RoPE 两种算子的独立执行或组合执行。该 FSM 控制数据从 SRAM 加载、计算流水线执行、结果写回 SRAM 的完整生命周期，支持三种算子模式：RMSNorm Only、RoPE Only、Combined (RMSNorm+RoPE)。

### 1.1 FSM Purpose

| Purpose | Description |
|---------|-------------|
| Operation Sequencing | 控制算子启动、计算、完成的完整流程 |
| Data Flow Management | 管理 SRAM 数据读取、中间结果传递、结果写回 |
| Precision Control | 支持 FP16/FP32 精度切换 |
| Combined Operation | 支持 RMSNorm+RoPE 组合执行，减少 SRAM 访问 |
| Error Handling | 检测和处理算子执行异常 |

### 1.2 FSM Architecture

```
FSM Structure:
  Main FSM: Operation Sequencer (IDLE->FETCH->COMPUTE->WRITE->DONE)
  Sub-FSM:  RMSNorm Compute FSM (Square->Sum->Div->Sqrt->Scale)
  Sub-FSM:  RoPE Compute FSM (AngleFetch->Rotate->Output)
  Sub-FSM:  SRAM Access FSM (Read->Write handshake)
```

### 1.3 Operation Types

| op_type | Operation | Description |
|---------|-----------|-------------|
| 0x0 | RMSNorm Only | 仅执行 RMSNorm 归一化 |
| 0x1 | RoPE Only | 仅执行 RoPE 位置编码 |
| 0x2 | Combined | RMSNorm + RoPE 组合执行 |

## 2. State Definitions

### 2.1 Main FSM States

| State ID | State Name | Description | Duration |
|----------|------------|-------------|----------|
| S0 | IDLE | 空闲状态，等待算子启动 | - |
| S1 | FETCH | 从 SRAM 读取输入数据和权重 | 2-4 cycles |
| S2 | COMPUTE_NORM | RMSNorm 计算 (op_type=0,2) | ~10 cycles |
| S3 | COMPUTE_ROPE | RoPE 计算 (op_type=1,2) | ~5-15 cycles |
| S4 | WRITE | 结果写回 SRAM | 2-4 cycles |
| S5 | DONE | 完成，等待 ACK 清除 | 1 cycle |
| S6 | ERROR | 错误状态，等待恢复 | - |

### 2.2 RMSNorm Sub-FSM States

| State ID | State Name | Description | Duration |
|----------|------------|-------------|----------|
| N0 | NORM_IDLE | RMSNorm 子状态空闲 | - |
| N1 | SQUARE | 64个并行平方计算 | 1 cycle |
| N2 | SUM_TREE | 7级树形加法器求和 | 7 cycles |
| N3 | DIVIDE | 除法计算 (ss/dim) | 2 cycles |
| N4 | SQRT | Newton-Raphson sqrt | 3 cycles (或 1 cycle LUT) |
| N5 | SCALE | 64个并行缩放计算 | 1 cycle |
| N6 | NORM_DONE | RMSNorm 完成 | - |

### 2.3 RoPE Sub-FSM States

| State ID | State Name | Description | Duration |
|----------|------------|-------------|----------|
| R0 | ROPE_IDLE | RoPE 子状态空闲 | - |
| R1 | ANGLE_FETCH | 查表获取 cos/sin (预计算表) | 1 cycle |
| R2 | ANGLE_CALC | 实时计算 cos/sin (无表) | 8 cycles |
| R3 | ROTATE | 32对并行旋转计算 | 2 cycles |
| R4 | ROPE_DONE | RoPE 完成 | - |

### 2.4 SRAM Access Sub-FSM States

| State ID | State Name | Description |
|----------|------------|-------------|
| A0 | SRAM_IDLE | SRAM 访问空闲 |
| A1 | SRAM_REQ | 发送 SRAM 请求 |
| A2 | SRAM_WAIT | 等待 SRAM 响应 |
| A3 | SRAM_DONE | SRAM 访问完成 |

## 3. State Transition Diagram

### 3.1 Main FSM State Transition

```
State Transition Diagram (Main FSM):

                        +-------+
                        | IDLE  |<-----------------------+
                        +-------+                        |
                            |                            |
                        op_start=1                       |
                            v                           |
                        +-------+                        |
                        | FETCH |                        |
                        +-------+                        |
                            |                            |
                        data_fetched                     |
                            v                           |
                +-----------+-----------+                |
                |                       |                |
            op_type=0,2             op_type=1            |
                v                       v                |
          +-------------+         +-------------+        |
          |COMPUTE_NORM |         |COMPUTE_ROPE |--------+
          +-------------+         +-------------+  (RoPE Only)
                |                       |
            norm_done                rope_done
                v                       v
          +-------------+         +-------------+
          |COMPUTE_ROPE |         |   WRITE     |  (Combined)
          +-------------+         +-------------+
                |                       |
            rope_done                write_done
                v                       v
          +-------------+         +-------+
          |   WRITE     |         | DONE  |
          +-------------+         +-------+
                |                       |
            write_done                ack=1
                v                       v
          +-------+                 +-------+
          | DONE  |---------------->| IDLE  |
          +-------+                 +-------+
                |
            ack=1
                v
          +-------+
          | IDLE  |
          +-------+
```

### 3.2 State Transition Table

| Current State | Condition | Next State | Output Action |
|---------------|-----------|------------|---------------|
| IDLE | op_start_i & op_type=0 | FETCH | Start RMSNorm |
| IDLE | op_start_i & op_type=1 | FETCH | Start RoPE |
| IDLE | op_start_i & op_type=2 | FETCH | Start Combined |
| FETCH | sram_rsp_valid_i & data_loaded & op_type=0 | COMPUTE_NORM | Begin RMSNorm |
| FETCH | sram_rsp_valid_i & data_loaded & op_type=1 | COMPUTE_ROPE | Begin RoPE |
| FETCH | sram_rsp_valid_i & data_loaded & op_type=2 | COMPUTE_NORM | Begin Combined |
| FETCH | sram_rsp_error_i | ERROR | Signal error |
| COMPUTE_NORM | norm_done & op_type=0 | WRITE | Norm result ready |
| COMPUTE_NORM | norm_done & op_type=2 | COMPUTE_ROPE | Continue to RoPE |
| COMPUTE_NORM | error_detected | ERROR | Signal error |
| COMPUTE_ROPE | rope_done & op_type=1 | WRITE | RoPE result ready |
| COMPUTE_ROPE | rope_done & op_type=2 | WRITE | Combined result ready |
| COMPUTE_ROPE | error_detected | ERROR | Signal error |
| WRITE | sram_rsp_valid_i & write_done | DONE | Result stored |
| WRITE | sram_rsp_error_i | ERROR | Write failed |
| DONE | ack_received | IDLE | Operation complete |
| ERROR | error_clear | IDLE | Reset FSM |

## 4. FSM Signals

### 4.1 FSM Input Signals

| Signal | Width | Description |
|--------|-------|-------------|
| fsm_op_start_i | 1 | 算子启动命令 |
| fsm_op_type_i | 2 | 算子类型 (0=RMSNorm, 1=RoPE, 2=Combined) |
| fsm_op_mode_i | 3 | 算子模式配置 |
| fsm_op_dim_i | 8 | 向量维度 (default: 64) |
| fsm_op_head_size_i | 8 | Head size (default: 8) |
| fsm_op_pos_i | 32 | 当前位置索引 (for RoPE) |
| fsm_op_precision_i | 2 | 精度配置 (0=FP16, 1=FP32) |
| fsm_data_addr_i | 32 | 输入数据 SRAM 地址 |
| fsm_weight_addr_i | 32 | 权重数据 SRAM 地址 |
| fsm_table_addr_i | 32 | RoPE 表 SRAM 地址 |
| fsm_out_addr_i | 32 | 输出数据 SRAM 地址 |
| fsm_sram_rsp_valid_i | 1 | SRAM 响应有效 |
| fsm_sram_rsp_error_i | 1 | SRAM 错误标志 |
| fsm_norm_done_i | 1 | RMSNorm 计算完成 |
| fsm_rope_done_i | 1 | RoPE 计算完成 |
| fsm_write_done_i | 1 | SRAM 写入完成 |
| fsm_ack_i | 1 | 外部 ACK 确认 |
| fsm_abort_i | 1 | 算子中止命令 |
| fsm_error_i | 1 | 错误信号输入 |

### 4.2 FSM Output Signals

| Signal | Width | Description |
|--------|-------|-------------|
| fsm_sram_req_valid_o | 1 | SRAM 访问请求有效 |
| fsm_sram_req_addr_o | 20 | SRAM 地址 |
| fsm_sram_req_rw_o | 1 | 读/写标识 (0=Read, 1=Write) |
| fsm_sram_req_wdata_o | 64 | 写数据 |
| fsm_sram_req_wstrb_o | 8 | 写字节使能 |
| fsm_norm_start_o | 1 | RMSNorm 计算启动 |
| fsm_rope_start_o | 1 | RoPE 计算启动 |
| fsm_norm_config_o | 16 | RMSNorm 配置参数 |
| fsm_rope_config_o | 16 | RoPE 配置参数 |
| fsm_op_done_o | 1 | 算子完成标志 |
| fsm_op_busy_o | 1 | 算子忙碌标志 |
| fsm_op_error_o | 1 | 算子错误标志 |
| fsm_op_status_o | 8 | 算子状态寄存器 |
| fsm_irq_o | 1 | 中断请求 |
| fsm_irq_type_o | 3 | 中断类型编码 |

### 4.3 FSM Internal Signals

| Signal | Width | Description |
|--------|-------|-------------|
| fsm_current_state | 3 | 当前状态编码 |
| fsm_next_state | 3 | 下一状态编码 |
| fsm_op_type | 2 | 当前算子类型 |
| fsm_data_loaded | 1 | 数据加载完成标志 |
| fsm_weight_loaded | 1 | 权重加载完成标志 |
| fsm_table_loaded | 1 | RoPE 表加载完成标志 |
| fsm_norm_result_valid | 1 | RMSNorm 结果有效 |
| fsm_rope_result_valid | 1 | RoPE 结果有效 |
| fsm_cycle_counter | 32 | 执行周期计数器 |
| fsm_progress | 8 | 执行进度 (%) |

## 5. State Encoding

### 5.1 Main FSM State Encoding

| State | Encoding | Binary | Description |
|-------|----------|--------|-------------|
| IDLE | 0x0 | 000 | 等待算子启动 |
| FETCH | 0x1 | 001 | 数据加载 |
| COMPUTE_NORM | 0x2 | 010 | RMSNorm 计算 |
| COMPUTE_ROPE | 0x3 | 011 | RoPE 计算 |
| WRITE | 0x4 | 100 | 结果写回 |
| DONE | 0x5 | 101 | 完成等待 ACK |
| ERROR | 0x6 | 110 | 错误状态 |

### 5.2 RMSNorm Sub-FSM State Encoding

| State | Encoding | Binary |
|-------|----------|--------|
| NORM_IDLE | 0x0 | 000 |
| SQUARE | 0x1 | 001 |
| SUM_TREE | 0x2 | 010 |
| DIVIDE | 0x3 | 011 |
| SQRT | 0x4 | 100 |
| SCALE | 0x5 | 101 |
| NORM_DONE | 0x6 | 110 |

### 5.3 RoPE Sub-FSM State Encoding

| State | Encoding | Binary |
|-------|----------|--------|
| ROPE_IDLE | 0x0 | 000 |
| ANGLE_FETCH | 0x1 | 001 |
| ANGLE_CALC | 0x2 | 010 |
| ROTATE | 0x3 | 011 |
| ROPE_DONE | 0x4 | 100 |

## 6. State Timing Parameters

### 6.1 Timing Parameters per State

| Parameter | Symbol | Value @ 500MHz | Associated State |
|-----------|--------|----------------|------------------|
| SRAM Fetch Latency | t_FETCH | 2-4 cycles | FETCH duration |
| RMSNorm Latency | t_NORM | ~10 cycles | COMPUTE_NORM duration |
| RoPE Latency (Table) | t_ROPE_TBL | ~5 cycles | COMPUTE_ROPE duration |
| RoPE Latency (Calc) | t_ROPE_CALC | ~15 cycles | COMPUTE_ROPE duration |
| SRAM Write Latency | t_WRITE | 2-4 cycles | WRITE duration |
| Combined Latency | t_COMBINED | ~15 cycles | Total combined flow |

### 6.2 Cycle Breakdown by Operation Type

| Operation Type | Phase | Cycles | Total |
|----------------|-------|--------|-------|
| RMSNorm Only | FETCH + NORM + WRITE | 3 + 10 + 3 | ~16 cycles |
| RoPE Only (Table) | FETCH + ROPE + WRITE | 3 + 5 + 3 | ~11 cycles |
| RoPE Only (Calc) | FETCH + ROPE + WRITE | 3 + 15 + 3 | ~21 cycles |
| Combined (Table) | FETCH + NORM + ROPE + WRITE | 3 + 10 + 5 + 3 | ~21 cycles |
| Combined (Calc) | FETCH + NORM + ROPE + WRITE | 3 + 10 + 15 + 3 | ~31 cycles |

### 6.3 Progress Tracking

| State | Progress (%) | Description |
|-------|--------------|-------------|
| IDLE | 0% | 等待启动 |
| FETCH | 10-20% | 数据加载 |
| COMPUTE_NORM | 30-50% | RMSNorm 计算 |
| COMPUTE_ROPE | 50-80% | RoPE 计算 |
| WRITE | 80-95% | 结果写回 |
| DONE | 100% | 完成确认 |

## 7. RMSNorm Sub-FSM Detail

### 7.1 RMSNorm Compute Pipeline

```
RMSNorm Compute Flow:
    |
    v
+--------+     +--------+     +--------+
| SQUARE | --> |SUM_TREE| --> | DIVIDE |
+--------+     +--------+     +--------+
    |              |              |
  1 cycle        7 cycles       2 cycles
    v              v              v
+--------+     +--------+     +--------+
|  SQRT  | --> | SCALE  | --> | DONE   |
+--------+     +--------+     +--------+
    |              |              |
  3 cycles       1 cycle         -
    v              v              v
  rms value    normalized vec   output valid
```

### 7.2 RMSNorm Sub-State Transition

| Current Sub-State | Condition | Next Sub-State |
|-------------------|-----------|----------------|
| NORM_IDLE | norm_start | SQUARE |
| SQUARE | square_done | SUM_TREE |
| SUM_TREE | sum_done | DIVIDE |
| DIVIDE | div_done | SQRT |
| SQRT | sqrt_done | SCALE |
| SCALE | scale_done | NORM_DONE |
| NORM_DONE | - | (return to Main FSM) |

### 7.3 RMSNorm Sub-FSM Signals

| Signal | Width | Description |
|--------|-------|-------------|
| norm_start_i | 1 | RMSNorm 启动 |
| norm_data_i | 64*16 | 输入向量 (64 FP16) |
| norm_weight_i | 64*16 | 权重向量 (64 FP16) |
| norm_epsilon_i | 32 | epsilon 参数 |
| norm_result_o | 64*16 | 归一化结果 |
| norm_done_o | 1 | RMSNorm 完成 |
| norm_error_o | 1 | RMSNorm 错误 |

## 8. RoPE Sub-FSM Detail

### 8.1 RoPE Compute Pipeline

```
RoPE Compute Flow (with Table):
    |
    v
+-------------+     +--------+
| ANGLE_FETCH | --> | ROTATE |
+-------------+     +--------+
    |                  |
  1 cycle            2 cycles
    v                  v
 cos/sin values    rotated vectors

RoPE Compute Flow (without Table):
    |
    v
+-------------+     +--------+
| ANGLE_CALC  | --> | ROTATE |
+-------------+     +--------+
    |                  |
  8 cycles           2 cycles
    v                  v
 cos/sin values    rotated vectors
```

### 8.2 RoPE Sub-State Transition

| Current Sub-State | Condition | Next Sub-State |
|-------------------|-----------|----------------|
| ROPE_IDLE | rope_start & table_en | ANGLE_FETCH |
| ROPE_IDLE | rope_start & !table_en | ANGLE_CALC |
| ANGLE_FETCH | angles_loaded | ROTATE |
| ANGLE_CALC | angles_ready | ROTATE |
| ROTATE | rotate_done | ROPE_DONE |
| ROPE_DONE | - | (return to Main FSM) |

### 8.3 RoPE Sub-FSM Signals

| Signal | Width | Description |
|--------|-------|-------------|
| rope_start_i | 1 | RoPE 启动 |
| rope_data_i | 64*16 | 输入向量 (64 FP16) |
| rope_pos_i | 32 | 位置索引 |
| rope_head_size_i | 8 | Head size |
| rope_base_i | 32 | RoPE base 参数 |
| rope_table_addr_i | 32 | 预计算表地址 |
| rope_table_en_i | 1 | 预计算表使能 |
| rope_result_o | 64*16 | 旋转结果 |
| rope_done_o | 1 | RoPE 完成 |
| rope_error_o | 1 | RoPE 错误 |

## 9. SRAM Access Sub-FSM Detail

### 9.1 SRAM Access Flow

```
SRAM Access Flow:
    |
    v
+----------+     +----------+     +----------+
| SRAM_REQ | --> | SRAM_WAIT | --> | SRAM_DONE |
+----------+     +----------+     +----------+
    |                |                |
  1 cycle          1-3 cycles       -
    v                v                v
 send request      wait response    complete
```

### 9.2 SRAM Access Sub-State Transition

| Current Sub-State | Condition | Next Sub-State |
|-------------------|-----------|----------------|
| SRAM_IDLE | sram_access_req | SRAM_REQ |
| SRAM_REQ | req_sent | SRAM_WAIT |
| SRAM_WAIT | sram_rsp_valid | SRAM_DONE |
| SRAM_WAIT | sram_rsp_error | (signal error to Main FSM) |
| SRAM_DONE | - | (return to Main FSM) |

### 9.3 SRAM Access Patterns

| Phase | Access Type | Address Source | Data Width |
|-------|-------------|----------------|------------|
| FETCH (Input) | Read | data_in_addr_i | 64-bit |
| FETCH (Weight) | Read | weight_addr_i | 64-bit |
| FETCH (Table) | Read | rope_table_addr_i + pos*offset | 64-bit |
| WRITE | Write | data_out_addr_o | 64-bit |

## 10. Combined Operation Flow

### 10.1 Combined Pipeline Sequence

```
Combined RMSNorm + RoPE:
    |
    v
Step 1: FETCH (2-4 cycles)
    |-- Read input vector x[64] from SRAM
    |-- Read weight vector w[64] from SRAM
    |-- Read rope table entry (if table enabled)
    |
    v
Step 2: COMPUTE_NORM (~10 cycles)
    |-- RMSNorm(x, w, epsilon) -> normalized[64]
    |-- Result stored in internal buffer (no SRAM write)
    |
    v
Step 3: COMPUTE_ROPE (~5 cycles with table)
    |-- RoPE(normalized, pos, cos/sin) -> rotated[64]
    |-- Direct input from norm result buffer
    |
    v
Step 4: WRITE (2-4 cycles)
    |-- Write rotated[64] to output SRAM address
    |
    v
Step 5: DONE
    |-- Signal op_done_o
    |-- Wait for ACK
```

### 10.2 SRAM Access Optimization

| Mode | SRAM Reads | SRAM Writes | Total Access | Savings |
|------|------------|-------------|--------------|---------|
| Separate (Norm then RoPE) | 4 (x, w, norm, table) | 2 (norm, rotated) | 6 | - |
| Combined | 3 (x, w, table) | 1 (rotated) | 4 | 33% |

Combined 模式优势：
- 中间归一化结果直接传递给 RoPE，无需 SRAM 写回
- 减少 33% SRAM 访问次数
- 降低功耗和延迟

## 11. Error Handling

### 11.1 Error Conditions

| Error Code | Condition | Description |
|------------|-----------|-------------|
| 0x1 | SRAM_READ_ERROR | SRAM 读取失败 |
| 0x2 | SRAM_WRITE_ERROR | SRAM 写入失败 |
| 0x3 | NORM_ERROR | RMSNorm 计算异常 (divide by zero) |
| 0x4 | ROPE_ERROR | RoPE 计算异常 |
| 0x5 | TIMEOUT_ERROR | 操作超时 |
| 0x6 | INVALID_PARAM | 参数无效 |

### 11.2 Error State Behavior

| Error State | Behavior | Recovery |
|-------------|----------|----------|
| ERROR | fsm_op_error_o = 1 | Wait for error_clear |
| ERROR | fsm_irq_o = 1 | Interrupt to M08 |
| ERROR | fsm_op_status_o = error_code | Status register update |
| ERROR | fsm_cycle_counter freeze | Preserve cycle count |

### 11.3 Interrupt Types

| IRQ Type | Code | Condition |
|----------|------|-----------|
| IRQ_DONE | 0x0 | 操作正常完成 |
| IRQ_ERROR | 0x1 | 错误中断 |
| IRQ_ABORT | 0x2 | 操作中止 |
| IRQ_TIMEOUT | 0x3 | 超时中断 |

## 12. FSM Verification Requirements

| Check | Method | Coverage Target |
|-------|--------|-----------------|
| State Transition Coverage | Formal/Simulation | 100% transitions |
| RMSNorm Compute Path | Simulation | All norm patterns |
| RoPE Compute Path | Simulation | All rope patterns |
| Combined Path | Simulation | All combined flows |
| Precision Switch | Simulation | FP16/FP32 modes |
| Table vs Calc | Simulation | Table/Calc paths |
| Error Handling | Simulation | All error scenarios |
| SRAM Access | Simulation | Read/Write patterns |
| Timeout Handling | Simulation | Timeout recovery |

## 13. FSM Implementation Notes

### 13.1 Design Considerations

| Consideration | Description |
|---------------|-------------|
| One-hot Encoding | Main FSM 使用 one-hot 编码，减少转换延迟 |
| Sub-FSM Parallel | RMSNorm 和 RoPE Sub-FSM 独立运行 |
| Pipeline Buffer | Combined 模式使用内部 buffer 传递中间结果 |
| Timeout Counter | 周期计数器支持超时检测 |

### 13.2 Optimization Strategies

| Strategy | Benefit |
|----------|---------|
| Combined Execution | 减少 SRAM 访问，降低延迟 |
| Pre-computed Table | RoPE 延速降低 3 倍 |
| Tree Adder | RMSNorm 求和快 9 倍 |
| Parallel Multiplier | 64 并行乘法，吞吐提升 |

## 14. Appendix: State Machine RTL Template

```verilog
// Main FSM State Encoding (One-hot)
localparam [6:0]
  S_IDLE        = 7'b0000001,
  S_FETCH       = 7'b0000010,
  S_COMPUTE_NORM = 7'b0000100,
  S_COMPUTE_ROPE = 7'b0001000,
  S_WRITE       = 7'b0010000,
  S_DONE        = 7'b0100000,
  S_ERROR       = 7'b1000000;

// FSM Internal Registers
reg [6:0]   fsm_current_state;
reg [6:0]   fsm_next_state;
reg [2:0]   fsm_op_type;
reg [31:0]  fsm_cycle_counter;
reg [7:0]   fsm_progress;
reg         fsm_data_loaded;
reg         fsm_weight_loaded;
reg         fsm_norm_result_valid;
reg         fsm_rope_result_valid;

// State Transition Logic
always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
  if (!rst_sys_n_i) begin
    fsm_current_state <= S_IDLE;
    fsm_cycle_counter <= 32'b0;
    fsm_progress <= 8'b0;
  end else begin
    fsm_current_state <= fsm_next_state;
    if (fsm_current_state != S_IDLE && fsm_current_state != S_ERROR)
      fsm_cycle_counter <= fsm_cycle_counter + 1;
  end
end

// Next State Logic
always_comb begin
  fsm_next_state = fsm_current_state;

  case (fsm_current_state)
    S_IDLE: begin
      if (fsm_op_start_i)
        fsm_next_state = S_FETCH;
    end

    S_FETCH: begin
      if (fsm_sram_rsp_error_i)
        fsm_next_state = S_ERROR;
      else if (fsm_data_loaded)
        case (fsm_op_type_i)
          2'b00: fsm_next_state = S_COMPUTE_NORM;  // RMSNorm Only
          2'b01: fsm_next_state = S_COMPUTE_ROPE;  // RoPE Only
          2'b10: fsm_next_state = S_COMPUTE_NORM;  // Combined
          default: fsm_next_state = S_ERROR;
        endcase
    end

    S_COMPUTE_NORM: begin
      if (fsm_error_i)
        fsm_next_state = S_ERROR;
      else if (fsm_norm_done_i)
        case (fsm_op_type)
          2'b00: fsm_next_state = S_WRITE;        // RMSNorm Only
          2'b10: fsm_next_state = S_COMPUTE_ROPE; // Combined -> RoPE
          default: fsm_next_state = S_ERROR;
        endcase
    end

    S_COMPUTE_ROPE: begin
      if (fsm_error_i)
        fsm_next_state = S_ERROR;
      else if (fsm_rope_done_i)
        fsm_next_state = S_WRITE;
    end

    S_WRITE: begin
      if (fsm_sram_rsp_error_i)
        fsm_next_state = S_ERROR;
      else if (fsm_write_done_i)
        fsm_next_state = S_DONE;
    end

    S_DONE: begin
      if (fsm_ack_i)
        fsm_next_state = S_IDLE;
    end

    S_ERROR: begin
      if (fsm_abort_i)
        fsm_next_state = S_IDLE;
    end

    default: fsm_next_state = S_IDLE;
  endcase
end

// Output Logic
always_comb begin
  fsm_op_done_o = fsm_current_state == S_DONE;
  fsm_op_busy_o = fsm_current_state inside {S_FETCH, S_COMPUTE_NORM,
                                             S_COMPUTE_ROPE, S_WRITE};
  fsm_op_error_o = fsm_current_state == S_ERROR;
  fsm_op_status_o = {4'b0, fsm_current_state[2:0], fsm_progress[7:4]};
end

// Progress Calculation
always_ff @(posedge clk_sys_i) begin
  case (fsm_current_state)
    S_IDLE:     fsm_progress <= 8'h00;
    S_FETCH:    fsm_progress <= 8'h10;
    S_COMPUTE_NORM: fsm_progress <= 8'h30 + (fsm_norm_progress_i >> 2);
    S_COMPUTE_ROPE: fsm_progress <= 8'h50 + (fsm_rope_progress_i >> 2);
    S_WRITE:    fsm_progress <= 8'h80;
    S_DONE:     fsm_progress <= 8'hFF;
    default:    fsm_progress <= fsm_progress;
  endcase
end
```