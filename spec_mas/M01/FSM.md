---
module: M01
type: FSM
status: complete
fsm_name: Operator Dispatch FSM
parent_mas: M01/MAS.md
---

# M01: Operator Dispatch FSM

## 1. Overview

Operator Dispatch FSM 是 M01 Dataflow Controller 的核心状态机，负责算子指令的获取、解析、分发和执行监控。该 FSM 驱动 Spatial Dataflow 流水线的算子调度，确保 M00 Systolic Array 和 M09-M12 Operator Units 的正确执行顺序。

**核心特性**：

| Feature | Description |
|---------|-------------|
| State Count | 6 states |
| Transition Cycle | 1-2 cycles per state |
| Concurrency | Supports multi-thread dispatch |
| Error Handling | Automatic recovery to IDLE |

**时钟域**：CLK_SYS (250-500 MHz)
**复位策略**：同步复位，初始状态 IDLE

## 2. State Definition

### 2.1 State List

| State ID | State Name | Description |
|----------|------------|-------------|
| 0 | IDLE | 等待调度器启动，空闲状态 |
| 1 | FETCH_OP | 从指令队列获取下一算子指令 |
| 2 | DECODE | 解析算子参数，确定目标执行单元 |
| 3 | DISPATCH | 发送指令到目标算子单元 (M09-M12 或 M00) |
| 4 | WAIT_DONE | 等待算子执行完成，监控完成标志 |
| 5 | COMPLETE | 更新状态寄存器，触发中断，准备下一算子 |

### 2.2 State Encoding

```verilog
// State encoding (one-hot for efficient synthesis)
localparam [5:0] S_IDLE      = 6'b000001;
localparam [5:0] S_FETCH_OP  = 6'b000010;
localparam [5:0] S_DECODE    = 6'b000100;
localparam [5:0] S_DISPATCH  = 6'b001000;
localparam [5:0] S_WAIT_DONE = 6'b010000;
localparam [5:0] S_COMPLETE  = 6'b100000;
```

## 3. State Transitions

### 3.1 Transition Diagram

```
                +-------+
                | IDLE  |
                +-------+
                    |
                    | start_en & op_queue_valid
                    v
                +-------+
                |FETCH_OP|
                +-------+
                    |
                    | op_fetch_done
                    v
                +-------+
                | DECODE |
                +-------+
                    |
                    | decode_done
                    v
                +-------+
                |DISPATCH|
                +-------+
                    |
                    | dispatch_ack (op_ready)
                    v
                +-------+
                |WAIT_DONE|
                +-------+
                    |
                    | op_done (算子完成)
                    v
                +-------+
                |COMPLETE|
                +-------+
                    |
                    | complete_done
                    v
                +-------+
                | IDLE  | (循环)
                +-------+

Error Handling:
  Any State --[err_detected]--> IDLE (带 error_flag)
```

### 3.2 Transition Table

| Current State | Condition | Next State | Transition Cycle |
|---------------|-----------|------------|------------------|
| IDLE | `start_en=1 & op_queue_valid=1` | FETCH_OP | 1 |
| IDLE | `start_en=0` | IDLE | - |
| IDLE | `op_queue_valid=0` | IDLE | - |
| FETCH_OP | `op_fetch_done=1` | DECODE | 1 |
| FETCH_OP | `op_queue_empty=1` | IDLE (queue empty) | 1 |
| DECODE | `decode_done=1` | DISPATCH | 1 |
| DISPATCH | `op_ready[target]=1` | WAIT_DONE | 1 |
| DISPATCH | `op_ready[target]=0` | DISPATCH (wait ack) | - |
| WAIT_DONE | `op_done[target]=1` | COMPLETE | 1 |
| WAIT_DONE | `op_err[target]!=0` | COMPLETE (error) | 1 |
| COMPLETE | `complete_done=1 & more_ops=1` | FETCH_OP | 1 |
| COMPLETE | `complete_done=1 & more_ops=0` | IDLE | 1 |
| Any State | `err_detected=1` | IDLE | 1 |

### 3.3 Multi-thread Transitions

线程切换发生在算子边界：

| Thread Scenario | Transition Behavior |
|-----------------|---------------------|
| T0 running | COMPLETE --[tid_switch]--> FETCH_OP (T1) |
| T1 running | COMPLETE --[tid_switch]--> FETCH_OP (T0) |
| Thread yield | WAIT_DONE --[yield_req]--> COMPLETE |

## 4. State Behaviors

### 4.1 IDLE State

**行为**：等待调度器启动信号，保持空闲状态。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `start_en` | 1 | 调度器启动使能 |
| `op_queue_valid` | 1 | 指令队列非空标志 |
| `soft_reset` | 1 | 软复位请求 |

**输出信号**：

| Signal | Width | Value | Description |
|--------|-------|-------|-------------|
| `fsm_status` | 4 | 0x0 | IDLE 状态码 |
| `op_valid` | 1 | 0 | 算子指令无效 |
| `syst_start` | 1 | 0 | Systolic 未启动 |
| `irq_op_done` | 1 | 0 | 中断未触发 |

**内部逻辑**：

```verilog
// IDLE state logic
always_ff @(posedge clk_sys) begin
  if (soft_reset) begin
    fsm_state <= S_IDLE;
    error_flag <= 0;
  end else if (fsm_state == S_IDLE) begin
    if (start_en && op_queue_valid) begin
      fsm_state <= S_FETCH_OP;
      current_tid <= sched_current_tid;
    end
  end
end
```

### 4.2 FETCH_OP State

**行为**：从指令队列读取下一算子指令，更新读指针。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `op_queue_base` | 32 | 指令队列基地址 |
| `op_queue_ptr[tid]` | 16 | 线程读指针 |
| `op_queue_depth` | 16 | 队列深度 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `mem_req_valid` | 1 | 内存请求有效 |
| `mem_req_addr` | 32 | 读地址 (op_queue_base + ptr) |
| `op_fetch_done` | 1 | 获取完成标志 |

**内部操作**：

1. 计算读取地址：`fetch_addr = op_queue_base + op_queue_ptr[current_tid] * 16`
2. 发起内存读请求
3. 接收指令数据 (128-bit)：`op_instr = mem_resp_data`
4. 更新读指针：`op_queue_ptr[current_tid] += 1`
5. 跳转到 DECODE

**指令格式**：

| Field | Bits | Description |
|-------|------|-------------|
| `op_code` | 8 | 算子操作码 |
| `op_unit_sel` | 4 | 目标单元选择 |
| `precision` | 2 | 精度配置 |
| `src_addr` | 32 | 源数据地址 |
| `dst_addr` | 32 | 目标地址 |
| `params` | 82 | 算子参数 |

### 4.3 DECODE State

**行为**：解析算子指令，确定目标执行单元和参数配置。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `op_instr` | 128 | 当前算子指令 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `decoded_op_code` | 8 | 解码后的操作码 |
| `decoded_unit_sel` | 4 | 解码后的单元选择 |
| `decoded_precision` | 2 | 解码后的精度 |
| `decoded_src_addr` | 32 | 解码后的源地址 |
| `decoded_dst_addr` | 32 | 解码后的目标地址 |
| `decoded_params` | 82 | 解码后的参数 |

**解码逻辑**：

```verilog
// Decode logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_DECODE) begin
    // Extract fields from instruction
    decoded_op_code   <= op_instr[7:0];
    decoded_unit_sel  <= op_instr[11:8];
    decoded_precision <= op_instr[13:12];
    decoded_src_addr  <= op_instr[45:14];
    decoded_dst_addr  <= op_instr[77:46];
    decoded_params    <= op_instr[127:78];
    
    // Validate unit selection
    if (decoded_unit_sel == 0) begin
      // Systolic Array operation
      target_is_systolic <= 1;
    end else begin
      // Operator Unit operation
      target_is_systolic <= 0;
    end
    
    fsm_state <= S_DISPATCH;
  end
end
```

**算子解码表**：

| op_code | Operator | Unit Sel | Description |
|---------|----------|----------|-------------|
| 0x01 | Attention | 0x1 (M09) | Q*K attention |
| 0x02 | FFN | 0x2 (M10) | Feed-forward network |
| 0x03 | RMSNorm | 0x3 (M11) | Layer normalization |
| 0x04 | RoPE | 0x3 (M11) | Position encoding |
| 0x05 | SoftMax | 0x4 (M12) | Score normalization |
| 0x10 | MatMul | 0x0 (M00) | General matrix multiply |

### 4.4 DISPATCH State

**行为**：发送解码后的指令到目标执行单元，等待目标单元确认。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `op_ready[4]` | 4 | 各算子单元就绪标志 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `op_valid` | 1 | 算子指令有效 |
| `op_code` | 8 | 操作码 |
| `op_unit_sel` | 4 | 目标单元 |
| `op_precision` | 2 | 精度配置 |
| `op_src_addr` | 32 | 源地址 |
| `op_dst_addr` | 32 | 目标地址 |
| `op_params` | 128 | 参数 (扩展格式) |
| `op_tid` | 1 | 线程 ID |

**分发逻辑**：

```verilog
// Dispatch logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_DISPATCH) begin
    // Check target unit ready
    if (target_is_systolic) begin
      if (syst_ready) begin
        // Dispatch to M00 Systolic Array
        syst_valid <= 1;
        syst_mode <= decoded_op_mode;
        syst_precision <= decoded_precision;
        syst_start <= 1;  // Pulse
        fsm_state <= S_WAIT_DONE;
      end
    end else begin
      if (op_ready[decoded_unit_sel]) begin
        // Dispatch to M09-M12 Operator Unit
        op_valid <= 1;
        op_unit_sel <= decoded_unit_sel;
        fsm_state <= S_WAIT_DONE;
      end
    end
  end
end
```

**分发时序**：

| Target | Dispatch Latency | Ack Latency |
|--------|------------------|-------------|
| M00 (Systolic) | 1 cycle | 1 cycle |
| M09 (Attention) | 1 cycle | 1 cycle |
| M10 (FFN) | 1 cycle | 1 cycle |
| M11 (Norm) | 1 cycle | 1 cycle |
| M12 (SoftMax) | 1 cycle | 1 cycle |

### 4.5 WAIT_DONE State

**行为**：等待目标算子单元执行完成，监控完成标志和错误状态。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `op_done[4]` | 4 | 各算子完成标志 |
| `op_err[8]` | 8 | 各算子错误码 |
| `syst_done` | 1 | Systolic 完成标志 |
| `syst_err` | 2 | Systolic 错误码 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `fsm_status` | 4 | 0x4 (WAIT_DONE) |
| `perf_cnt[tid]` | 32 | 性能计数器 (cycles) |

**等待逻辑**：

```verilog
// Wait done logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_WAIT_DONE) begin
    // Increment performance counter
    perf_cnt[current_tid] <= perf_cnt[current_tid] + 1;
    
    // Check completion
    if (target_is_systolic) begin
      if (syst_done) begin
        if (syst_err != 0) begin
          error_flag <= 1;
          error_code <= syst_err;
        end
        fsm_state <= S_COMPLETE;
      end
    end else begin
      if (op_done[decoded_unit_sel]) begin
        if (op_err[decoded_unit_sel*2 +: 2] != 0) begin
          error_flag <= 1;
          error_code <= op_err[decoded_unit_sel*2 +: 2];
        end
        fsm_state <= S_COMPLETE;
      end
    end
  end
end
```

**超时处理**：

| Condition | Timeout | Action |
|-----------|---------|--------|
| Attention | 10,000 cycles | Error flag, force COMPLETE |
| FFN | 15,000 cycles | Error flag, force COMPLETE |
| RMSNorm | 500 cycles | Error flag, force COMPLETE |
| SoftMax | 1,000 cycles | Error flag, force COMPLETE |

### 4.6 COMPLETE State

**行为**：更新状态寄存器，触发中断，检查是否有更多算子，准备下一调度周期。

**输入信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `op_queue_ptr[tid]` | 16 | 线程读指针 |
| `op_queue_depth` | 16 | 队列深度 |
| `sched_yield` | 1 | 线程让出请求 |

**输出信号**：

| Signal | Width | Description |
|--------|-------|-------------|
| `irq_op_done` | 1 | 完成中断 |
| `irq_tid` | 1 | 中断线程 ID |
| `perf_op_cnt[tid]` | 32 | 算子完成计数 |
| `sched_status` | 4 | 调度状态 |

**完成逻辑**：

```verilog
// Complete logic
always_ff @(posedge clk_sys) begin
  if (fsm_state == S_COMPLETE) begin
    // Update performance counters
    perf_op_cnt[current_tid] <= perf_op_cnt[current_tid] + 1;
    
    // Trigger interrupt if enabled
    if (irq_mask[0]) begin
      irq_op_done <= 1;
      irq_tid <= current_tid;
    end
    
    // Update STATUS register
    status_reg[1] <= 1;  // BUSY flag clear in next cycle
    status_reg[3:2] <= current_tid;
    
    // Check for more operators
    if (op_queue_ptr[current_tid] < op_queue_depth) begin
      more_ops <= 1;
    end else begin
      more_ops <= 0;
    end
    
    // Thread switch logic
    if (sched_yield || thread_switch_req) begin
      current_tid <= ~current_tid;  // Switch thread
    end
    
    // Clear valid signals
    op_valid <= 0;
    syst_start <= 0;
    
    // Transition
    if (more_ops && !error_flag) begin
      fsm_state <= S_FETCH_OP;
    end else begin
      fsm_state <= S_IDLE;
    end
  end
end
```

## 5. Control Signals

### 5.1 FSM Control Inputs

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| `clk_sys` | 1 | System | 时钟信号 |
| `rst_sys` | 1 | System | 同步复位 |
| `soft_reset` | 1 | CTRL[1] | 软复位 |
| `start_en` | 1 | CTRL[0] | 启动使能 |
| `thread_en[2]` | 2 | sched_thread_en | 线程使能 |

### 5.2 FSM Control Outputs

| Signal | Width | Destination | Description |
|--------|-------|--------------|-------------|
| `fsm_state` | 6 | Internal | 当前状态 |
| `fsm_status` | 4 | STATUS[7:4] | 状态码 |
| `current_tid` | 1 | STATUS[3:2] | 当前线程 |
| `error_flag` | 1 | STATUS[8] | 错误标志 |
| `error_code` | 8 | ERR_CODE | 错误码 |

### 5.3 Operator Interface Signals

| Signal | Width | Direction | Timing |
|--------|-------|-----------|--------|
| `op_valid` | 1 | Out | DISPATCH state only |
| `op_ready` | 4 | In | Always valid |
| `op_done` | 4 | In | WAIT_DONE monitoring |
| `op_err` | 8 | In | WAIT_DONE monitoring |

### 5.4 Systolic Interface Signals

| Signal | Width | Direction | Timing |
|--------|-------|-----------|--------|
| `syst_start` | 1 | Out | Pulse in DISPATCH |
| `syst_done` | 1 | In | WAIT_DONE monitoring |
| `syst_err` | 2 | In | WAIT_DONE monitoring |

## 6. Timing Constraints

### 6.1 State Timing

| State | Min Duration | Max Duration | Typical |
|-------|--------------|--------------|---------|
| IDLE | 0 cycles | Unlimited | - |
| FETCH_OP | 1 cycle | 3 cycles | 2 cycles |
| DECODE | 1 cycle | 1 cycle | 1 cycle |
| DISPATCH | 1 cycle | 10 cycles | 1 cycle |
| WAIT_DONE | 1 cycle | Timeout | varies |
| COMPLETE | 1 cycle | 2 cycles | 1 cycle |

### 6.2 Dispatch Latency

完整算子调度延迟（不含执行时间）：

```
Dispatch_Latency = FETCH_OP + DECODE + DISPATCH + COMPLETE
                 = 2 + 1 + 1 + 1 = 5 cycles (typical)
```

### 6.3 Context Switch Timing

线程切换发生在 COMPLETE → FETCH_OP 边界：

| Metric | Target | Implementation |
|--------|--------|----------------|
| Context Save | <= 2 cycles | Register save |
| Context Load | <= 2 cycles | Register load |
| Total Switch | <= 4 cycles | REQ-COMPUTE-006 |

### 6.4 Critical Path

| Path | Delay Target | Implementation |
|------|---------------|----------------|
| State Transition | < 1 CLK_SYS | One-hot encoding |
| Decode Logic | < 1 CLK_SYS | Combinational |
| Dispatch Arbitration | < 1 CLK_SYS | Priority encoder |

## 7. Error Handling

### 7.1 Error Types

| Error Code | Description | Recovery |
|------------|-------------|----------|
| 0x00 | No error | - |
| 0x01 | Queue empty | Return IDLE |
| 0x02 | Unit not ready | Retry dispatch |
| 0x03 | Execution timeout | Force COMPLETE |
| 0x04 | Precision mismatch | Return IDLE |
| 0x05 | Memory error | Return IDLE |
| 0x06 | Systolic error | Return IDLE |

### 7.2 Error Recovery FSM

```
Error Detection:
  - Any state detects error
  - Set error_flag, error_code
  
Recovery Sequence:
  1. Complete state transitions to IDLE with error
  2. Clear active signals (op_valid, syst_start)
  3. Trigger irq_err interrupt
  4. Wait for software ack (IRQ_STATUS write)
  5. Clear error_flag
  6. Resume normal operation
```

### 7.3 Timeout Mechanism

```verilog
// Timeout counter per operator type
localparam TIMEOUT_ATTENTION = 10000;
localparam TIMEOUT_FFN       = 15000;
localparam TIMEOUT_NORM      = 500;
localparam TIMEOUT_SOFTMAX   = 1000;

always_ff @(posedge clk_sys) begin
  if (fsm_state == S_WAIT_DONE) begin
    timeout_cnt <= timeout_cnt + 1;
    
    case (decoded_op_code)
      0x01: if (timeout_cnt >= TIMEOUT_ATTENTION) timeout_err <= 1;
      0x02: if (timeout_cnt >= TIMEOUT_FFN)       timeout_err <= 1;
      0x03: if (timeout_cnt >= TIMEOUT_NORM)      timeout_err <= 1;
      0x05: if (timeout_cnt >= TIMEOUT_SOFTMAX)   timeout_err <= 1;
      default: timeout_err <= 0;
    endcase
  end else begin
    timeout_cnt <= 0;
    timeout_err <= 0;
  end
end
```

## 8. Implementation Notes

### 8.1 Synthesis Guidelines

1. **State Encoding**: 使用 one-hot encoding 提高速度
2. **Output Gating**: 空闲状态关闭输出信号减少功耗
3. **Clock Gating**: WAIT_DONE 状态可使用 clock gating

### 8.2 Verification Checklist

| Check | Description |
|-------|-------------|
| State Coverage | 所有 6 状态可达 |
| Transition Coverage | 所有转换条件测试 |
| Error Recovery | 各类错误恢复正确 |
| Thread Switch | 双线程切换时序正确 |
| Timeout | 各算子超时处理正确 |

### 8.3 Performance Counters

| Counter | Register | Width | Purpose |
|---------|----------|-------|---------|
| Op Count T0 | PERF_CNT0 | 32 | 线程0完成算子数 |
| Op Count T1 | PERF_CNT1 | 32 | 线程1完成算子数 |
| Wait Cycles | Internal | 32 | 等待执行周期数 |
| Pipeline Util | PERF_UTIL | 16 | Q16格式利用率 |

### 8.4 Integration Requirements

| Requirement | Description |
|-------------|-------------|
| Reset Sequence | rst_sys -> IDLE, all signals cleared |
| Clock Domain | Single CLK_SYS, no CDC |
| Power Domain | PD_MAIN, DVFS support |
| Debug Access | FSM state via STATUS register |

## 9. References

- **Parent MAS**: `/spec_mas/M01/MAS.md` - Section 3.2 Operator Dispatch Logic
- **REQ-COMPUTE-006**: Multi-thread >= 2, context switch <= 4 cycles
- **REQ-COMPUTE-008**: Operator coverage (Attention/FFN/RMSNorm/RoPE/SoftMax)
- **Interface**: `/spec_mas/M01/MAS.md` Section 2.2 Operator Unit Dispatch Interface