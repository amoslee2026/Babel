---
module: M03
type: FSM
status: complete
parent: M03
fsm_type: LPDDR4X Command FSM
generated: "2026-05-17T16:00:00+08:00"
---

# M03 FSM: LPDDR4X Command FSM

## 1. Overview

LPDDR4X Command FSM 管理 DRAM Controller 的命令序列生成，实现 Activate/Read/Write/Precharge/Refresh 等操作的自动化流程控制。该 FSM 负责将高层访问请求转换为 LPDDR4X 协议命令序列，确保满足时序要求并优化访问延迟。

### 1.1 FSM Purpose

| Purpose | Description |
|---------|-------------|
| Command Sequencing | 自动生成 ACT -> READ/WRITE -> PRE 命令序列 |
| Row Buffer Management | 管理各 Bank 的 Row 状态，优化 row hit |
| Timing Compliance | 确保 LPDDR4X 时序参数满足 |
| Bandwidth Optimization | 最大化带宽利用率，减少访问延迟 |

### 1.2 FSM Architecture

```
FSM Structure:
  Main FSM: Command Sequencer (ACT/READ/WRITE/PRE/REF)
  Sub-FSM:  Row Buffer Tracker (per Bank)
  Sub-FSM:  Power Mode Controller (Active/SREF/PD)
```

## 2. State Definitions

### 2.1 Main FSM States (Command Sequencer)

| State ID | State Name | Description | Duration |
|----------|------------|-------------|----------|
| S0 | IDLE | 空闲状态，等待请求 | - |
| S1 | REQ_PENDING | 请求待处理，解析地址 | 1 cycle |
| S2 | ROW_CHECK | 检查目标 Row 是否已激活 | 1 cycle |
| S3 | ACTIVATE | 发送 ACT 命令，激活 Row | t_ACT (50 ns) |
| S4 | ACT_WAIT | 等待 Activate 完成 | t_RCD (18 ns) |
| S5 | READ_CMD | 发送 READ 命令 | 1 cycle |
| S6 | READ_WAIT | 等待数据返回 | t_RH (50-100 ns) |
| S7 | WRITE_CMD | 发送 WRITE 命令 | 1 cycle |
| S8 | WRITE_WAIT | 等待写入完成 | t_WR (50 ns) |
| S9 | PRECHARGE | 发送 PRE 命令，关闭 Bank | t_PRE (20 ns) |
| S10 | PRE_WAIT | 等待 Precharge 完成 | t_RP (18 ns) |
| S11 | REFRESH | 执行 Refresh 操作 | t_RFC (350 ns) |
| S12 | SELF_REFRESH | Self-Refresh 模式 | 直到退出 |
| S13 | POWER_DOWN | Power Down 模式 | 直到退出 |
| S14 | ERROR | 错误状态，等待恢复 | - |

### 2.2 Row Buffer Tracker States (Per Bank)

| State ID | State Name | Description |
|----------|------------|-------------|
| RB_CLOSED | Row Closed | Bank 未激活任何 Row |
| RB_OPEN | Row Open | Bank 已激活特定 Row |
| RB_ACTIVATING | Activating | Row 正在激活过程中 |
| RB_PRECHARGING | Precharging | Bank 正在关闭过程中 |

### 2.3 Power Mode FSM States

| State ID | State Name | Description | Power |
|----------|------------|-------------|-------|
| PM_ACTIVE | Active Mode | 正常运行模式 | 200 mW |
| PM_SELF_REFRESH | Self-Refresh | 自刷新模式 | 50 mW |
| PM_POWER_DOWN | Power Down | 功耗下降模式 | 5 mW |
| PM_DEEP_PD | Deep Power Down | 深度功耗模式 | 5 mW |

## 3. State Transition Diagram

### 3.1 Main FSM State Transition

```
State Transition Diagram (Main FSM):

                     +-------+
                     | IDLE  |
                     +-------+
                         |
                         | request_valid
                         v
                   +-----------+
                   | REQ_PEND  |
                   +-----------+
                         |
                         | addr_decoded
                         v
                   +-----------+
                   | ROW_CHECK |
                   +-----------+
                         |
          +--------------+--------------+
          |              |              |
          | row_miss     | row_hit      | refresh_req
          v              v              v
    +----------+    +----------+    +----------+
    | ACTIVATE |    | READ_CMD |    | REFRESH  |
    +----------+    +----------+    +----------+
          |              |              |
          | t_RCD        |              | t_RFC
          v              v              v
    +----------+    +----------+    +----------+
    | ACT_WAIT |    |READ/WRITE|    | REF_DONE |
    +----------+    |   WAIT   |    +----------+
          |              |              |
          | act_done     | data_done    |
          v              v              v
    +----------+    +----------+        |
    |READ/WRITE|    | PRECHARGE|        |
    |   CMD    |    +----------+        |
    +----------+          |             |
          |               | t_RP        |
          |               v             |
          |         +----------+        |
          |         | PRE_WAIT |        |
          |         +----------+        |
          |               |             |
          +---------------+-------------+
                         |
                         | all_done
                         v
                     +-------+
                     | IDLE  |
                     +-------+
```

### 3.2 State Transition Table

| Current State | Condition | Next State | Output Action |
|---------------|-----------|------------|---------------|
| IDLE | request_valid & !refresh_req | REQ_PENDING | Parse request |
| IDLE | refresh_req | REFRESH | Issue REF command |
| IDLE | self_refresh_req | SELF_REFRESH | Issue SREF command |
| IDLE | power_down_req | POWER_DOWN | Issue PDE command |
| REQ_PENDING | addr_decoded | ROW_CHECK | Compare row address |
| ROW_CHECK | row_hit & read_op | READ_CMD | Issue READ command |
| ROW_CHECK | row_hit & write_op | WRITE_CMD | Issue WRITE command |
| ROW_CHECK | row_miss & !bank_busy | ACTIVATE | Issue ACT command |
| ROW_CHECK | row_miss & bank_busy | REQ_PENDING | Wait for bank |
| ACTIVATE | act_issue_done | ACT_WAIT | Wait t_RCD |
| ACT_WAIT | t_RCD_elapsed | READ_CMD/WRITE_CMD | Issue data command |
| READ_CMD | read_issue_done | READ_WAIT | Wait for data |
| READ_WAIT | data_valid | PRECHARGE/DONE | Issue PRE or return |
| WRITE_CMD | write_issue_done | WRITE_WAIT | Wait for completion |
| WRITE_WAIT | write_done | PRECHARGE/DONE | Issue PRE or return |
| PRECHARGE | pre_issue_done | PRE_WAIT | Wait t_RP |
| PRE_WAIT | t_RP_elapsed | IDLE | Return to idle |
| REFRESH | t_RFC_elapsed | IDLE | Refresh complete |
| SELF_REFRESH | exit_req | ACTIVATE | Wake up sequence |
| POWER_DOWN | exit_req | ACTIVATE | Wake up sequence |
| ERROR | error_clear | IDLE | Reset FSM |

## 4. FSM Signals

### 4.1 FSM Input Signals

| Signal | Width | Description |
|--------|-------|-------------|
| fsm_req_valid_i | 1 | 外部请求有效 |
| fsm_req_rw_i | 1 | 读/写请求类型 (0=Read, 1=Write) |
| fsm_req_addr_i | 32 | 请求地址 |
| fsm_req_burst_i | 8 | Burst 长度请求 |
| fsm_req_priority_i | 4 | 请求优先级 |
| fsm_refresh_req_i | 1 | Refresh 请求 |
| fsm_sref_req_i | 1 | Self-Refresh 进入请求 |
| fsm_sref_exit_i | 1 | Self-Refresh 退出请求 |
| fsm_pd_req_i | 1 | Power Down 请求 |
| fsm_pd_exit_i | 1 | Power Down 退出请求 |
| fsm_row_addr_i | 16 | 当前请求 Row 地址 |
| fsm_bank_addr_i | 3 | 当前请求 Bank 地址 |
| fsm_col_addr_i | 10 | 当前请求 Column 地址 |
| fsm_rb_status_i | 8 | 各 Bank Row Buffer 状态 |
| fsm_act_done_i | 1 | Activate 命令完成确认 |
| fsm_data_valid_i | 1 | Read 数据有效 |
| fsm_write_done_i | 1 | Write 命令完成确认 |
| fsm_pre_done_i | 1 | Precharge 命令完成确认 |
| fsm_timer_done_i | 1 | Timer 超时信号 |
| fsm_error_i | 1 | 错误信号 |

### 4.2 FSM Output Signals

| Signal | Width | Description |
|--------|-------|-------------|
| fsm_act_cmd_o | 1 | ACT 命令输出 |
| fsm_read_cmd_o | 1 | READ 命令输出 |
| fsm_write_cmd_o | 1 | WRITE 命令输出 |
| fsm_pre_cmd_o | 1 | PRE 命令输出 |
| fsm_ref_cmd_o | 1 | REF 命令输出 |
| fsm_sref_cmd_o | 1 | SREF 命令输出 |
| fsm_pd_cmd_o | 1 | PDE 命令输出 |
| fsm_cmd_addr_o | 32 | 命令地址输出 |
| fsm_cmd_bank_o | 3 | 命令 Bank 选择 |
| fsm_cmd_row_o | 16 | 命令 Row 地址 |
| fsm_cmd_col_o | 10 | 命令 Column 地址 |
| fsm_cmd_burst_o | 8 | 命令 Burst 长度 |
| fsm_rb_update_o | 1 | Row Buffer 状态更新 |
| fsm_rb_row_o | 16 | 更新 Row 地址 |
| fsm_rb_bank_o | 3 | 更新 Bank 选择 |
| fsm_rb_action_o | 2 | Row Buffer 操作 (Open/Close/Activate) |
| fsm_timer_start_o | 1 | Timer 启动 |
| fsm_timer_value_o | 8 | Timer 值 (timing parameter) |
| fsm_busy_o | 1 | FSM 忙状态 |
| fsm_ready_o | 1 | FSM 就绪状态 |
| fsm_error_o | 1 | FSM 错误输出 |
| fsm_done_o | 1 | 操作完成信号 |

### 4.3 FSM Internal Signals

| Signal | Width | Description |
|--------|-------|-------------|
| fsm_current_state | 4 | 当前状态编码 |
| fsm_next_state | 4 | 下一状态编码 |
| fsm_row_hit | 1 | Row Hit 标志 |
| fsm_row_miss | 1 | Row Miss 标志 |
| fsm_target_row | 16 | 目标 Row 地址 |
| fsm_current_row | 16 | 当前激活 Row 地址 |
| fsm_target_bank | 3 | 目标 Bank |
| fsm_bank_busy | 8 | 各 Bank 忙标志 |
| fsm_pending_req | 1 | 待处理请求标志 |
| fsm_data_done | 1 | 数据传输完成 |

## 5. State Encoding

### 5.1 Main FSM State Encoding

| State | Encoding | Binary |
|-------|----------|--------|
| IDLE | 0x0 | 0000 |
| REQ_PENDING | 0x1 | 0001 |
| ROW_CHECK | 0x2 | 0010 |
| ACTIVATE | 0x3 | 0011 |
| ACT_WAIT | 0x4 | 0100 |
| READ_CMD | 0x5 | 0101 |
| READ_WAIT | 0x6 | 0110 |
| WRITE_CMD | 0x7 | 0111 |
| WRITE_WAIT | 0x8 | 1000 |
| PRECHARGE | 0x9 | 1001 |
| PRE_WAIT | 0xA | 1010 |
| REFRESH | 0xB | 1011 |
| SELF_REFRESH | 0xC | 1100 |
| POWER_DOWN | 0xD | 1101 |
| ERROR | 0xE | 1110 |

## 6. State Timing Parameters

### 6.1 Timing Parameters per State

| Parameter | Symbol | Value | Associated State |
|-----------|--------|-------|------------------|
| Activate to Read/Write | t_RCD | 18 ns | ACT_WAIT -> READ/WRITE_CMD |
| Read Latency | t_RL | 50 ns | READ_WAIT duration |
| Write Latency | t_WL | 50 ns | WRITE_WAIT duration |
| Precharge Time | t_RP | 18 ns | PRE_WAIT duration |
| Refresh Time | t_RFC | 350 ns | REFRESH duration |
| Activate Time | t_ACT | 50 ns | ACTIVATE duration |
| Row Hit Latency | t_RH | <= 100 ns | Total row hit path |
| Row Miss Latency | t_RM | <= 150 ns | Total row miss path |

### 6.2 Timer Implementation

```
Timer Module:
  - fsm_timer_value_o: Timing parameter selection
  - fsm_timer_start_o: Timer trigger
  - fsm_timer_done_i: Timer completion
  
  Timing Parameter Encoding:
    0x00: t_RCD (18 ns)
    0x01: t_RL (50 ns)
    0x02: t_WL (50 ns)
    0x03: t_RP (18 ns)
    0x04: t_RFC (350 ns)
    0x05: t_ACT (50 ns)
    0x06: t_PRE (20 ns)
```

## 7. Row Buffer Management

### 7.1 Row Buffer Tracker Structure

```
Row Buffer Tracker (per Bank):
  State Machine: RB_CLOSED -> RB_ACTIVATING -> RB_OPEN -> RB_PRECHARGING -> RB_CLOSED
  
  Storage:
    - current_row[8][16]: 各 Bank 当前激活 Row (16-bit per Bank)
    - bank_state[8]: 各 Bank Row Buffer 状态 (2-bit per Bank)
    
  Logic:
    - fsm_row_hit = (fsm_target_row == current_row[fsm_target_bank]) && (bank_state[fsm_target_bank] == RB_OPEN)
    - fsm_row_miss = !fsm_row_hit
```

### 7.2 Row Buffer State Transition

| Current RB State | Action | Next RB State |
|------------------|--------|---------------|
| RB_CLOSED | ACTIVATE command | RB_ACTIVATING |
| RB_ACTIVATING | t_RCD elapsed | RB_OPEN |
| RB_OPEN | PRECHARGE command | RB_PRECHARGING |
| RB_PRECHARGING | t_RP elapsed | RB_CLOSED |
| RB_OPEN | READ/WRITE (same row) | RB_OPEN (unchanged) |
| RB_OPEN | READ/WRITE (different row) | RB_PRECHARGING |

## 8. Power Mode FSM

### 8.1 Power Mode State Transition

| Current PM State | Condition | Next PM State | Entry Time |
|------------------|-----------|---------------|------------|
| PM_ACTIVE | sref_req | PM_SELF_REFRESH | < 1 us |
| PM_ACTIVE | pd_req | PM_POWER_DOWN | < 10 us |
| PM_SELF_REFRESH | exit_req | PM_ACTIVE | < 100 us |
| PM_POWER_DOWN | exit_req | PM_ACTIVE | < 10 us |

### 8.2 Power Mode FSM Signals

| Signal | Description |
|--------|-------------|
| pm_current_state | 当前功耗状态 |
| pm_sref_entry_o | Self-Refresh 进入命令 |
| pm_sref_exit_o | Self-Refresh 退出命令 |
| pm_pd_entry_o | Power Down 进入命令 |
| pm_pd_exit_o | Power Down 退出命令 |
| pm_active_o | Active 模式标志 |

## 9. FSM Design Details

### 9.1 Row Hit Optimization

```
Row Hit Path (Optimized):
  IDLE -> REQ_PENDING -> ROW_CHECK -> READ_CMD -> READ_WAIT -> DONE
  
  Total Latency: <= 100 ns
    - Request Parse: 1 cycle (CLK_SYS)
    - Row Check: 1 cycle
    - READ Command: 1 cycle + D2D TX
    - Data Wait: t_RH (50-100 ns)
    - Return: 1 cycle
```

### 9.2 Row Miss Path

```
Row Miss Path:
  IDLE -> REQ_PENDING -> ROW_CHECK -> ACTIVATE -> ACT_WAIT -> READ/WRITE_CMD -> READ/WRITE_WAIT -> PRECHARGE -> PRE_WAIT -> IDLE
  
  Total Latency: <= 150 ns
    - ACTIVATE: 50 ns
    - ACT_WAIT (t_RCD): 18 ns
    - READ/WRITE: 50 ns
    - PRECHARGE (optional): 20 ns
    - PRE_WAIT (t_RP): 18 ns
```

### 9.3 Access Sequencing Example

```
Read Access Example:
  1. fsm_req_valid_i = 1, fsm_req_rw_i = 0, fsm_req_addr_i = 0x0000_1000
  2. FSM -> REQ_PENDING: Decode address (Row=0x01, Bank=0, Col=0x00)
  3. FSM -> ROW_CHECK: Check Bank 0 Row Buffer status
     - Case A: Row 0x01 already open (row_hit) -> READ_CMD
     - Case B: Row 0x01 not open (row_miss) -> ACTIVATE
  4. FSM -> READ_CMD: Issue READ command to Bank 0, Row 0x01, Col 0x00
  5. FSM -> READ_WAIT: Wait for data valid
  6. fsm_data_valid_i = 1 -> fsm_done_o = 1
  7. FSM -> IDLE (with open page policy) or PRECHARGE (close page)
```

## 10. FSM Verification Requirements

| Check | Method | Coverage Target |
|-------|--------|-----------------|
| State Transition Coverage | Formal/Simulation | 100% transitions |
| Row Hit/Miss Path | Simulation | All combinations |
| Timing Compliance | STA + Simulation | 100% timing checks |
| Bank Conflict Handling | Simulation | All Bank states |
| Power Mode Transition | Simulation | All mode transitions |
| Error Recovery | Simulation | All error scenarios |
| Burst Operation | Simulation | All burst lengths |

## 11. FSM Implementation Notes

### 11.1 Design Considerations

| Consideration | Description |
|---------------|-------------|
| One-hot Encoding | 使用 one-hot state encoding 减少状态转换延迟 |
| Pipeline Stages | Command generation 可 pipeline 以提高吞吐 |
| Bank Parallelism | 支持 8 Bank 并行访问以提高带宽 |
| Request Queue | Pending request queue 支持 reorder |

### 11.2 Optimization Strategies

| Strategy | Benefit |
|----------|---------|
| Open Page Policy | 减少 row miss 概率，提高 row hit rate |
| Row Buffer Tracking | 快速判断 row hit/miss |
| Request Reordering | 最大化 row hit，减少 ACT/PRE overhead |
| Bank Interleaving | 利用 Bank 并行性提高带宽 |

## 12. Appendix: State Machine RTL Template

```verilog
// Main FSM State Encoding (One-hot)
localparam [14:0] 
  S_IDLE       = 15'b000000000000001,
  S_REQ_PENDING = 15'b000000000000010,
  S_ROW_CHECK  = 15'b000000000000100,
  S_ACTIVATE   = 15'b000000000001000,
  S_ACT_WAIT   = 15'b000000000010000,
  S_READ_CMD   = 15'b000000000100000,
  S_READ_WAIT  = 15'b000000001000000,
  S_WRITE_CMD  = 15'b000000010000000,
  S_WRITE_WAIT = 15'b000000100000000,
  S_PRECHARGE  = 15'b000001000000000,
  S_PRE_WAIT   = 15'b000010000000000,
  S_REFRESH    = 15'b000100000000000,
  S_SELF_REF   = 15'b001000000000000,
  S_POWER_DOWN = 15'b010000000000000,
  S_ERROR      = 15'b100000000000000;

// State Transition Logic (simplified)
always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
  if (!rst_sys_n_i) begin
    fsm_current_state <= S_IDLE;
  end else begin
    fsm_current_state <= fsm_next_state;
  end
end

// Next State Logic
always_comb begin
  fsm_next_state = fsm_current_state;
  
  case (fsm_current_state)
    S_IDLE: begin
      if (fsm_refresh_req_i)       fsm_next_state = S_REFRESH;
      else if (fsm_sref_req_i)     fsm_next_state = S_SELF_REF;
      else if (fsm_pd_req_i)       fsm_next_state = S_POWER_DOWN;
      else if (fsm_req_valid_i)    fsm_next_state = S_REQ_PENDING;
    end
    
    S_REQ_PENDING: fsm_next_state = S_ROW_CHECK;
    
    S_ROW_CHECK: begin
      if (fsm_row_hit && fsm_req_rw_i == 0) fsm_next_state = S_READ_CMD;
      else if (fsm_row_hit && fsm_req_rw_i == 1) fsm_next_state = S_WRITE_CMD;
      else if (fsm_row_miss) fsm_next_state = S_ACTIVATE;
    end
    
    S_ACTIVATE: fsm_next_state = S_ACT_WAIT;
    
    S_ACT_WAIT: begin
      if (fsm_timer_done_i) fsm_next_state = fsm_req_rw_i ? S_WRITE_CMD : S_READ_CMD;
    end
    
    S_READ_CMD: fsm_next_state = S_READ_WAIT;
    
    S_READ_WAIT: begin
      if (fsm_data_valid_i) fsm_next_state = S_PRECHARGE; // or IDLE with open page
    end
    
    S_WRITE_CMD: fsm_next_state = S_WRITE_WAIT;
    
    S_WRITE_WAIT: begin
      if (fsm_write_done_i) fsm_next_state = S_PRECHARGE; // or IDLE with open page
    end
    
    S_PRECHARGE: fsm_next_state = S_PRE_WAIT;
    
    S_PRE_WAIT: begin
      if (fsm_timer_done_i) fsm_next_state = S_IDLE;
    end
    
    S_REFRESH: begin
      if (fsm_timer_done_i) fsm_next_state = S_IDLE;
    end
    
    S_SELF_REF: begin
      if (fsm_sref_exit_i) fsm_next_state = S_ACTIVATE;
    end
    
    S_POWER_DOWN: begin
      if (fsm_pd_exit_i) fsm_next_state = S_ACTIVATE;
    end
    
    S_ERROR: begin
      if (fsm_error_clear) fsm_next_state = S_IDLE;
    end
    
    default: fsm_next_state = S_IDLE;
  endcase
end
```