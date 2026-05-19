---
module: M08
type: FSM
status: complete
parent: M08
module_type: interconnect
generated: "2026-05-17T16:30:00+08:00"
---

# M08: Multi-thread Scheduler FSM

## 1. Overview

本文档定义 M08 Multi-thread Scheduler 的状态机设计，包含以下 FSM：

| FSM | Type | Description |
|-----|------|-------------|
| Scheduler Main FSM | Hierarchical | 主调度状态机，管理调度流程 |
| Thread Lifecycle FSM | Flat | 线程生命周期状态机，管理单线程状态 |
| Context Switch FSM | Flat | 上下文切换状态机，管理 context save/load |
| Dispatch FSM | Flat | 分发状态机，管理 M01 接口 |

## 2. Scheduler Main FSM

### 2.1 State Definition

```
Scheduler Main FSM States:

  +----------------+
  |     IDLE       |  -- 等待调度触发
  +-------+--------+
          |
          | scheduler_enable = 1
          | pending_threads > 0
          v
  +----------------+
  |    SELECT      |  -- 选择下一个线程
  +-------+--------+
          |
          | thread_selected
          v
  +----------------+
  |   DISPATCH     |  -- 分发线程到 M01
  +-------+--------+
          |
          | dispatch_done
          v
  +----------------+
  |    RUNNING     |  -- 线程执行中
  +-------+--------+
          |
          | quantum_expire / preempt / block / complete
          v
  +----------------+
  |   SWITCH       |  -- 上下文切换
  +-------+--------+
          |
          | switch_done AND pending_threads > 0
          v
  +----------------+
  |    SELECT      |  -- 循环回选择
  +-------+--------+
          |
          | switch_done AND pending_threads = 0
          v
  +----------------+
  |     IDLE       |  -- 无待调度线程
  +----------------+

          [Error Path from any state]
          |
          | error_detected
          v
  +----------------+
  |    ERROR       |  -- 错误处理
  +-------+--------+
          |
          | error_handled
          v
  +----------------+
  |     IDLE       |  -- 返回空闲
  +----------------+
```

### 2.2 State Transition Table

| Current State | Condition | Next State | Action |
|---------------|-----------|------------|--------|
| IDLE | scheduler_enable = 1 AND pending_threads > 0 | SELECT | Start scheduling cycle |
| IDLE | scheduler_enable = 0 | IDLE | Stay idle, clear busy flag |
| SELECT | thread_selected = 1 | DISPATCH | Load next_thread_id, prepare dispatch |
| SELECT | no_ready_threads | IDLE | Return to idle, no threads ready |
| DISPATCH | dispatch_done = 1 AND dispatch_error = 0 | RUNNING | Set active_thread_id, start timer |
| DISPATCH | dispatch_error = 1 | ERROR | Record error, set error flag |
| RUNNING | quantum_expire = 1 | SWITCH | Trigger context switch, save current |
| RUNNING | preempt_request = 1 | SWITCH | Preempt current thread |
| RUNNING | block_request = 1 | SWITCH | Block current thread |
| RUNNING | complete_request = 1 | SWITCH | Complete current thread |
| RUNNING | error_detected = 1 | ERROR | Handle execution error |
| SWITCH | switch_done = 1 AND pending_threads > 0 | SELECT | Select next thread |
| SWITCH | switch_done = 1 AND pending_threads = 0 | IDLE | No more threads, return idle |
| SWITCH | switch_error = 1 | ERROR | Handle switch error |
| ERROR | error_handled = 1 | IDLE | Return to idle after recovery |

### 2.3 State Encoding

| State | Code (4 bits) | Description |
|-------|---------------|-------------|
| IDLE | 0x0 | Scheduler idle, waiting for enable |
| SELECT | 0x1 | Selecting next thread to run |
| DISPATCH | 0x2 | Dispatching thread to M01 |
| RUNNING | 0x3 | Thread executing on M01 |
| SWITCH | 0x4 | Context switch in progress |
| ERROR | 0x5 | Error handling state |
| RESET | 0xF | Reset state (transient) |

### 2.4 State Outputs

| State | Output Signals |
|-------|----------------|
| IDLE | sched_status.busy = 0, sched_status.ready = 1 |
| SELECT | sched_status.busy = 1, thread_select_active = 1 |
| DISPATCH | dispatch_valid = 1, ctx_rd_valid = 1 |
| RUNNING | sched_status.ctx_switch = 0, quantum_counter_active = 1 |
| SWITCH | sched_status.ctx_switch = 1, ctx_wr_valid = 1 |
| ERROR | sched_status.error = 1, thread_irq = 1 |

## 3. Thread Lifecycle FSM

### 3.1 State Definition

每个线程独立维护一个 Thread Lifecycle FSM，追踪线程状态。

```
Thread Lifecycle FSM (per thread):

  +--------+
  | EMPTY  |  -- 线程上下文未初始化
  +---+----+
      |
      | THREAD_CREATE command
      v
  +--------+
  | READY  |  -- 线程就绪，等待调度
  +---+----+
      |
      | dispatch_selected
      v
  +--------+
  | RUNNING|  -- 线程执行中
  +---+----+
      |
      +------------------------+
      |            |           |
      | quantum    | preempt   | block/sync
      | expire     |           |
      v            v           v
  +--------+  +--------+  +--------+
  | READY  |  | READY  |  | BLOCKED|
  +--------+  +--------+  +---+----+
                                      |
                                      | unblock / resume
                                      v
                                  +--------+
                                  | READY  |
                                  +--------+

      [From RUNNING/READY/BLOCKED]
      |
      | THREAD_KILL command
      v
  +--------+
  | EMPTY  |  -- 线程终止
  +--------+
```

### 3.2 State Transition Table

| Current State | Trigger | Next State | Context Action |
|---------------|---------|------------|----------------|
| EMPTY | THREAD_CREATE | READY | Initialize context, set priority |
| READY | dispatch_select | RUNNING | Load context to M01 |
| READY | THREAD_KILL | EMPTY | Free context slot |
| RUNNING | quantum_expire | READY | Save context, update quantum_cnt |
| RUNNING | preempt_request | READY | Save context, set preempted flag |
| RUNNING | sync_barrier | BLOCKED | Save context, set barrier_wait |
| RUNNING | THREAD_KILL | EMPTY | Free context slot |
| BLOCKED | barrier_release | READY | Clear barrier_wait |
| BLOCKED | resume_signal | READY | Clear wait_id |
| BLOCKED | THREAD_KILL | EMPTY | Free context slot |

### 3.3 State Encoding (per thread)

| State | Code (2 bits) | Description |
|-------|---------------|-------------|
| EMPTY | 0x0 | Thread slot empty |
| READY | 0x1 | Thread ready for dispatch |
| RUNNING | 0x2 | Thread currently executing |
| BLOCKED | 0x3 | Thread blocked or completed |

### 3.4 Thread State Vector

```
Thread State Vector (8 threads):

  +-----+-----+-----+-----+-----+-----+-----+-----+
  | T0  | T1  | T2  | T3  | T4  | T5  | T6  | T7  |
  +-----+-----+-----+-----+-----+-----+-----+-----+
    2b    2b    2b    2b    2b    2b    2b    2b

  THREAD_STATE_0: T0-T3 packed (bits[0:7])
  THREAD_STATE_1: T4-T7 packed (bits[0:7])
```

## 4. Context Switch FSM

### 4.1 State Definition

Context Switch FSM 管理 context save/load 流程，确保 <= 10 cycles 延迟。

```
Context Switch FSM:

  +--------+
  | IDLE   |  -- 无 context 操作
  +---+----+
      |
      | switch_request
      v
  +--------+
  | PAUSE  |  -- 暂停当前线程 (1 cycle)
  +---+----+
      |
      | pause_done
      v
  +--------+
  | SAVE   |  -- 保存 context (2-3 cycles)
  +---+----+
      |
      | ctx_wr_done
      v
  +--------+
  | SELECT |  -- 选择下一线程 (1-2 cycles)
  +---+----+
      |
      | next_selected
      v
  +--------+
  | LOAD   |  -- 加载 context (2-3 cycles)
  +---+----+
      |
      | ctx_rd_done
      v
  +--------+
  | RESUME |  -- 恢复执行 (1-2 cycles)
  +---+----+
      |
      | dispatch_done
      v
  +--------+
  | IDLE   |  -- 切换完成
  +--------+

      [Error Path]
      |
      | ctx_error
      v
  +--------+
  | ERROR  |  -- Context 错误
  +--------+
```

### 4.2 State Transition Table

| Current State | Condition | Next State | Cycles | Action |
|---------------|-----------|------------|--------|--------|
| IDLE | switch_request = 1 | PAUSE | 0 | Start context switch |
| PAUSE | pause_ack = 1 | SAVE | 1 | Signal M01 to pause |
| SAVE | ctx_wr_ready = 1 AND ctx_wr_done = 1 | SELECT | 2-3 | Write context to storage |
| SELECT | next_thread_valid = 1 | LOAD | 1-2 | Determine next thread |
| SELECT | no_valid_thread = 1 | IDLE | 1 | No thread to run, return idle |
| LOAD | ctx_rd_valid = 1 AND ctx_rd_done = 1 | RESUME | 2-3 | Read context from storage |
| RESUME | dispatch_done = 1 | IDLE | 1-2 | Dispatch to M01, complete switch |
| ERROR | error_handled = 1 | IDLE | - | Return to idle after error |

### 4.3 Timing Breakdown

| Phase | Min Cycles | Max Cycles | Description |
|-------|------------|------------|-------------|
| PAUSE | 1 | 1 | Signal M01 pause |
| SAVE | 2 | 3 | Context write to SRAM |
| SELECT | 1 | 2 | Thread selection logic |
| LOAD | 2 | 3 | Context read from SRAM |
| RESUME | 1 | 2 | Dispatch handshake |
| **Total** | **7** | **10** | Complete switch |

### 4.4 State Encoding

| State | Code (3 bits) | Description |
|-------|---------------|-------------|
| IDLE | 0x0 | No context operation |
| PAUSE | 0x1 | Pausing current thread |
| SAVE | 0x2 | Saving context |
| SELECT | 0x3 | Selecting next thread |
| LOAD | 0x4 | Loading next context |
| RESUME | 0x5 | Resuming execution |
| ERROR | 0x6 | Context error state |

## 5. Dispatch FSM

### 5.1 State Definition

Dispatch FSM 管理与 M01 Dataflow Controller 的 dispatch handshake。

```
Dispatch FSM:

  +--------+
  | IDLE   |  -- 无 dispatch 操作
  +---+----+
      |
      | dispatch_request
      v
  +--------+
  | PREP   |  -- 准备 dispatch 参数
  +---+----+
      |
      | params_ready
      v
  +--------+
  | REQ    |  -- 发送 dispatch request
  +---+----+
      |
      | dispatch_valid AND dispatch_ready
      v
  +--------+
  | WAIT   |  -- 等待 M01 acknowledge
  +---+----+
      |
      | dispatch_done = 1 AND dispatch_error = 0
      v
  +--------+
  | DONE   |  -- Dispatch 完成
  +---+----+
      |
      | ack_sent
      v
  +--------+
  | IDLE   |  -- 返回空闲
  +--------+

      [Error Path]
      |
      | dispatch_error = 1 OR timeout
      v
  +--------+
  | ERROR  |  -- Dispatch 错误
  +---+----+
      |
      | error_logged
      v
  +--------+
  | ABORT  |  -- 取消 dispatch
  +--------+
      |
      | abort_done
      v
  +--------+
  | IDLE   |  -- 返回空闲
  +--------+
```

### 5.2 State Transition Table

| Current State | Condition | Next State | Action |
|---------------|-----------|------------|--------|
| IDLE | dispatch_request = 1 | PREP | Start dispatch |
| PREP | params_ready = 1 | REQ | Set dispatch_thread_id, dispatch_cmd |
| REQ | dispatch_ready = 1 | WAIT | Assert dispatch_valid |
| REQ | dispatch_ready = 0 AND timeout | ERROR | Timeout waiting for M01 |
| WAIT | dispatch_done = 1 AND dispatch_error = 0 | DONE | M01 accepted dispatch |
| WAIT | dispatch_error = 1 | ERROR | M01 reported error |
| WAIT | timeout_expired = 1 | ERROR | Dispatch timeout |
| DONE | ack_sent = 1 | IDLE | Clear dispatch_valid |
| ERROR | error_logged = 1 | ABORT | Log error, prepare abort |
| ABORT | abort_done = 1 | IDLE | Return to idle |

### 5.3 Dispatch Protocol Timing

```
Dispatch Handshake Timing:

  Cycle:   0    1    2    3    4    5
           |----|----|----|----|----|
  
  Scheduler:
  dispatch_valid     :  0   1   1   1   0   0
  dispatch_thread_id :  -   T0  T0  T0  -   -
  dispatch_cmd       :  -   START START START -   -
  
  M01:
  dispatch_ready     :  1   1   1   1   1   1
  dispatch_done      :  0   0   1   1   1   0
  dispatch_error     :  0   0   0   0   0   0
  
  FSM State:
                     : IDLE PREP REQ WAIT DONE IDLE
```

### 5.4 State Encoding

| State | Code (3 bits) | Description |
|-------|---------------|-------------|
| IDLE | 0x0 | No dispatch operation |
| PREP | 0x1 | Preparing dispatch parameters |
| REQ | 0x2 | Sending dispatch request |
| WAIT | 0x3 | Waiting for M01 acknowledge |
| DONE | 0x4 | Dispatch completed |
| ERROR | 0x5 | Dispatch error |
| ABORT | 0x6 | Aborting dispatch |

## 6. Scheduling Mode FSM Variants

### 6.1 Round-Robin Mode

```
Round-Robin Selection Logic:

  Thread Queue (Circular):
  +----+----+----+----+----+----+----+----+
  | T0 | T1 | T2 | T3 | T4 | T5 | T6 | T7 |
  +----+----+----+----+----+----+----+----+
    ^                                |
    |                                |
    +--------------------------------+
    
  Selection Algorithm:
    next_thread = (current_thread + 1) % max_threads
    while thread_state[next_thread] != READY:
      next_thread = (next_thread + 1) % max_threads
      if loop_count > max_threads:
        return NO_THREAD  -- No ready threads
```

### 6.2 Priority Mode

```
Priority Selection Logic:

  Priority Queue (8 levels):
  Level 7: [Critical threads]
  Level 6: [High priority threads]
  Level 5: [High priority threads]
  Level 4: [Medium priority threads]
  Level 3: [Medium priority threads]
  Level 2: [Low priority threads]
  Level 1: [Low priority threads]
  Level 0: [Low priority threads]
  
  Selection Algorithm:
    for level from 7 to 0:
      for thread in priority_queue[level]:
        if thread_state[thread] == READY:
          return thread
    return NO_THREAD  -- No ready threads
```

### 6.3 Hybrid Mode

```
Hybrid Selection Logic:

  Priority Groups:
  +------------------------+
  | Group 7-6: High        | -- Priority within group
  |   Round-Robin inside   |
  +------------------------+
  | Group 3-5: Medium      |
  |   Round-Robin inside   |
  +------------------------+
  | Group 0-2: Low         |
  |   Round-Robin inside   |
  +------------------------+
  
  Selection Algorithm:
    for group in [HIGH, MEDIUM, LOW]:
      threads = get_threads_in_group(group)
      ready_threads = filter(threads, state == READY)
      if ready_threads:
        return round_robin_select(ready_threads)
    return NO_THREAD
```

## 7. Interrupt FSM

### 7.1 Interrupt Handling FSM

```
Interrupt FSM:

  +--------+
  | IDLE   |  -- 无中断
  +---+----+
      |
      | irq_request
      v
  +--------+
  | DETECT |  -- 检测中断类型 (1 cycle)
  +---+----+
      |
      | irq_type_valid
      v
  +--------+
  | PREEMPT|  -- 抢占当前线程 (3-5 cycles)
  +---+----+
      |
      | preempt_done
      v
  +--------+
  | HANDLER|  -- 分发中断处理线程 (5-8 cycles)
  +---+----+
      |
      | handler_dispatched
      v
  +--------+
  | ACTIVE |  -- 中断处理线程执行
  +---+----+
      |
      | handler_complete
      v
  +--------+
  | RETURN |  -- 返回原线程或下一线程 (2-4 cycles)
  +---+----+
      |
      | return_done
      v
  +--------+
  | IDLE   |  -- 中断处理完成
  +--------+
```

### 7.2 Interrupt Response Timing

| Phase | Cycles | Description |
|-------|--------|-------------|
| DETECT | 1 | Identify interrupt type |
| PREEMPT | 3-5 | Save context, preempt thread |
| HANDLER | 5-8 | Dispatch handler thread (priority 7) |
| ACTIVE | Variable | Handler execution time |
| RETURN | 2-4 | Restore preempted thread |
| **Total** | **10-15** | Interrupt response (excluding handler execution) |

## 8. Error Handling FSM

### 8.1 Error Types and Handling

| Error Type | Code | FSM Response | Recovery Action |
|------------|------|--------------|-----------------|
| Invalid thread ID | 0x01 | ERROR state | Return error to ISA Decoder |
| Context not ready | 0x02 | ERROR state | Wait/retry context storage |
| M01 not ready | 0x03 | ERROR state | Queue dispatch, retry |
| Thread blocked | 0x04 | SELECT state | Select alternate thread |
| Context switch error | 0x05 | ERROR state | Abort switch, return IDLE |
| Quantum timeout | 0x06 | INTERRUPT FSM | Dispatch handler thread |

### 8.2 Error Recovery FSM

```
Error Recovery FSM:

  +--------+
  | DETECT |  -- 检测错误
  +---+----+
      |
      | error_classified
      v
  +--------+
  | LOG    |  -- 记录错误 (1 cycle)
  +---+----+
      |
      | error_logged
      v
  +--------+
  | HANDLE |  -- 处理错误 (1-3 cycles)
  +---+----+
      |
      | error_handled
      v
  +--------+
  | RECOVER|  -- 恢复操作 (1-5 cycles)
  +---+----+
      |
      | recovery_done
      v
  +--------+
  | IDLE   |  -- 返回正常操作
  +--------+
```

## 9. FSM Integration

### 9.1 FSM Hierarchy

```
Scheduler FSM Hierarchy:

  +------------------------+
  | Scheduler Main FSM     | -- Top-level control
  |   +------------------+ |
  |   | Thread Lifecycle | | -- Per-thread state (8 instances)
  |   | FSM [0..7]       | |
  |   +------------------+ |
  |                        |
  |   +------------------+ |
  |   | Context Switch   | | -- Switch control
  |   | FSM              | |
  |   +------------------+ |
  |                        |
  |   +------------------+ |
  |   | Dispatch FSM     | -- M01 interface
  |   +------------------+ |
  |                        |
  |   +------------------+ |
  |   | Interrupt FSM    | -- IRQ handling
  |   +------------------+ |
  +------------------------+
```

### 9.2 FSM Communication

```
FSM Interconnection:

  Scheduler Main FSM
    |
    +--> Thread Lifecycle FSM (8 instances)
    |      - thread_state update
    |      - thread selection query
    |
    +--> Context Switch FSM
    |      - switch_request trigger
    |      - switch_done feedback
    |
    +--> Dispatch FSM
    |      - dispatch_request trigger
    |      - dispatch_done feedback
    |
    +--> Interrupt FSM
           - irq_request trigger
           - irq_done feedback
```

### 9.3 Reset Behavior

| FSM | rst_por_n | rst_sys_n | Soft Reset |
|-----|-----------|-----------|------------|
| Scheduler Main | IDLE, clear all states | IDLE, retain contexts | IDLE, disable scheduling |
| Thread Lifecycle | All -> EMPTY | RUNNING -> READY, others retained | No change |
| Context Switch | IDLE | IDLE | IDLE |
| Dispatch | IDLE | IDLE | IDLE |
| Interrupt | IDLE | IDLE | IDLE |

## 10. Implementation Notes

### 10.1 Design Considerations

1. **FSM Separation**: 每个 FSM 独立实现，便于验证和维护。

2. **State Encoding**: 使用 binary encoding 减少状态位，节省资源。

3. **Timing Guarantee**: Context Switch FSM 保证 <= 10 cycles 延迟。

4. **Error Recovery**: 所有 FSM 都有 ERROR 状态，确保错误可恢复。

5. **Interrupt Priority**: Interrupt FSM 优先级最高，可中断其他 FSM。

### 10.2 Verification Requirements

| FSM | Test Cases |
|-----|------------|
| Scheduler Main | State transitions, scheduling modes, error paths |
| Thread Lifecycle | CREATE/START/PAUSE/RESUME/KILL transitions |
| Context Switch | Save/load correctness, timing verification |
| Dispatch | Handshake protocol, error handling |
| Interrupt | IRQ response, preempt behavior |
| Error Recovery | Error classification, recovery paths |

### 10.3 Coverage Requirements

| Metric | Target |
|--------|--------|
| FSM State Coverage | 100% (all states visited) |
| Transition Coverage | 100% (all transitions exercised) |
| Path Coverage | >= 90% (major execution paths) |
| Timing Coverage | 100% (timing constraints verified) |

### 10.4 RTL Implementation Guidelines

| Aspect | Recommendation |
|--------|----------------|
| FSM Type | Explicit FSM coding style (3-block: state, next_state, output) |
| State Register | Separate state and next_state registers |
| Default State | IDLE as default after reset |
| Mealy vs Moore | Prefer Moore FSM for predictable timing |
| Error Handling | Default next_state = ERROR for invalid transitions |