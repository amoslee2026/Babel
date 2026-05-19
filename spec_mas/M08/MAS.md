---
module: M08
type: MAS
status: complete
parent: null
module_type: interconnect
generated: "2026-05-17T15:45:00+08:00"
---

# M08: Multi-thread Scheduler

## 1. Overview

M08 Multi-thread Scheduler 是 TinyStories NPU 计算子系统的核心调度模块，位于 PD_MAIN 电源域，负责管理多线程执行上下文、调度线程至 Dataflow Controller (M01)、维护线程状态及优先级队列。该模块实现 Round-Robin/Priority 双模式调度、Thread Context 快速切换、Thread State Machine 状态追踪三大功能，满足 REQ-COMPUTE-006 规定的线程数 >= 2 和高效调度目标。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| Thread Management | 支持 2-8 个硬件线程上下文，独立寄存器组 | REQ-COMPUTE-006 |
| Dual Dispatch Mode | Round-Robin 和 Priority 调度模式可配置 | REQ-COMPUTE-006 |
| Fast Context Switch | <= 10 cycles 上下文切换延迟，最小化调度开销 | - |
| Thread State Tracking | 每线程 Ready/Running/Blocked/Completed 状态追踪 | - |
| Priority Queue | 8 级优先级支持，实时线程优先调度 | - |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_SYS | 250-500 MHz，DVFS 支持 |
| Power Domain | PD_MAIN | 0.7-0.9 V，可 Power Gate |
| Target Power | 30 mW | Scheduler logic + context storage @ OP0 |

## 2. Interface

### 2.1 Upstream Interfaces (Control Inputs)

M08 接收来自 ISA Decoder (M13) 和 System Bus (M04) 的控制指令。

#### 2.1.1 Thread Control Interface (from M13 ISA Decoder)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| thread_cmd_valid | Input | 1 | Thread command valid |
| thread_cmd_ready | Output | 1 | Thread command ready |
| thread_cmd_opcode | Input | 4 | Thread command opcode |
| thread_cmd_thread_id | Input | 3 | Target thread ID (0-7) |
| thread_cmd_priority | Input | 3 | Thread priority (0-7) |
| thread_cmd_addr | Input | 32 | Thread entry address |
| thread_cmd_data | Input | 64 | Thread initialization data |

**Thread Command Opcodes**

| Opcode | Name | Description |
|--------|------|-------------|
| 0x0 | THREAD_CREATE | Create new thread with specified priority and entry address |
| 0x1 | THREAD_START | Start execution of specified thread |
| 0x2 | THREAD_PAUSE | Pause running thread, save context |
| 0x3 | THREAD_RESUME | Resume paused thread from saved context |
| 0x4 | THREAD_KILL | Terminate thread, free context |
| 0x5 | THREAD_SET_PRIO | Change thread priority dynamically |
| 0x6 | THREAD_SYNC | Synchronization barrier command |
| 0x7 | THREAD_GET_STATE | Request thread state |
| 0x8-0xF | Reserved | Reserved for future extensions |

#### 2.1.2 Register Interface (from M04 System Bus)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| reg_req_valid | Input | 1 | Register request valid |
| reg_req_ready | Output | 1 | Register request ready |
| reg_req_addr | Input | 12 | Register address offset |
| reg_req_rw | Input | 1 | Read(0)/Write(1) flag |
| reg_req_data | Input | 32 | Write data |
| reg_rsp_valid | Output | 1 | Register response valid |
| reg_rsp_data | Output | 32 | Read data |
| reg_rsp_error | Output | 1 | Error flag |

### 2.2 Downstream Interfaces (Dispatch Outputs)

M08 向 Dataflow Controller (M01) 发出调度指令。

#### 2.2.1 Dispatch Interface (to M01 Dataflow Controller)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| dispatch_valid | Output | 1 | Dispatch command valid |
| dispatch_ready | Input | 1 | Dispatch command ready |
| dispatch_thread_id | Output | 3 | Dispatched thread ID |
| dispatch_entry_addr | Output | 32 | Thread entry address |
| dispatch_context_ptr | Output | 8 | Context storage pointer |
| dispatch_cmd | Output | 2 | Dispatch command type |
| dispatch_done | Input | 1 | Dispatch completion acknowledgment |
| dispatch_error | Input | 1 | Dispatch error flag |

**Dispatch Commands**

| Command | Code | Description |
|---------|------|-------------|
| DISPATCH_START | 0x0 | Start thread execution |
| DISPATCH_SWITCH | 0x1 | Context switch to new thread |
| DISPATCH_RESUME | 0x2 | Resume from saved context |
| DISPATCH_STOP | 0x3 | Stop current thread |

#### 2.2.2 Context Interface (to/from Context Storage)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| ctx_rd_valid | Output | 1 | Context read valid |
| ctx_rd_ready | Input | 1 | Context read ready |
| ctx_rd_ptr | Output | 8 | Context read pointer |
| ctx_rd_data | Input | 256 | Context data (PC, registers, flags) |
| ctx_wr_valid | Output | 1 | Context write valid |
| ctx_wr_ready | Input | 1 | Context write ready |
| ctx_wr_ptr | Output | 8 | Context write pointer |
| ctx_wr_data | Output | 256 | Context data to save |

### 2.3 Thread Status Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| thread_active_id | Output | 3 | Currently active thread ID |
| thread_active_state | Output | 2 | Current thread state |
| thread_pending_cnt | Output | 4 | Number of pending threads |
| thread_blocked_cnt | Output | 4 | Number of blocked threads |
| thread_irq | Output | 1 | Thread interrupt request |
| thread_irq_id | Output | 3 | Interrupt thread ID |
| thread_irq_type | Output | 4 | Interrupt type |

### 2.4 Clock & Reset

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk_sys | Input | 1 | System clock (250-500 MHz) |
| rst_sys_n | Input | 1 | System reset, async active low |
| rst_por_n | Input | 1 | Power-On Reset, async active low |
| clk_enable | Input | 1 | Clock enable (from M05 Power Manager) |
| power_gate_n | Input | 1 | Power gate disable (from M05) |

### 2.5 Register Map

Base Address: 0x800D_0000 (allocated from M04 System Bus address map)

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | SCHED_CTRL | RW | 32 | Scheduler control register |
| 0x0004 | SCHED_STATUS | R | 32 | Scheduler status register |
| 0x0008 | SCHED_MODE | RW | 32 | Scheduling mode configuration |
| 0x000C | SCHED_PRIO_BASE | RW | 32 | Base priority configuration |
| 0x0010 | THREAD_ENABLE | RW | 32 | Thread enable bitmask (8 threads) |
| 0x0014 | THREAD_STATE_0 | R | 32 | Thread 0-3 state vector |
| 0x0018 | THREAD_STATE_1 | R | 32 | Thread 4-7 state vector |
| 0x0020 | THREAD_PRIO_0 | RW | 32 | Thread 0-3 priority assignment |
| 0x0024 | THREAD_PRIO_1 | RW | 32 | Thread 4-7 priority assignment |
| 0x0030 | THREAD_PC_0 | RW | 32 | Thread 0-3 program counter base |
| 0x0034 | THREAD_PC_1 | RW | 32 | Thread 4-7 program counter base |
| 0x0040 | SCHED_QUANTUM | RW | 32 | Round-Robin quantum (cycles) |
| 0x0044 | SCHED_TIMEOUT | RW | 32 | Thread execution timeout (cycles) |
| 0x0050 | SCHED_IRQ_EN | RW | 32 | Thread interrupt enable |
| 0x0054 | SCHED_IRQ_STATUS | R | 32 | Thread interrupt status |
| 0x0058 | SCHED_IRQ_CLEAR | RW | 32 | Thread interrupt clear |
| 0x0060 | SCHED_PERF_CTX_SW | R | 32 | Context switch counter |
| 0x0064 | SCHED_PERF_DISPATCH | R | 32 | Dispatch counter |
| 0x0068 | SCHED_PERF_LATENCY | R | 32 | Average scheduling latency |

#### 2.5.1 Register Bit Definitions

**SCHED_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enable | Scheduler enable |
| [1] | pause | Pause all threads |
| [2] | reset_ctx | Reset all contexts |
| [3] | irq_en | Interrupt enable |
| [4:7] | max_threads | Maximum thread count (2-8) |
| [8:31] | reserved | Reserved |

**SCHED_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | Scheduler ready |
| [1] | busy | Scheduling in progress |
| [2] | ctx_switch | Context switch occurring |
| [3] | error | Error detected |
| [4:6] | active_thread | Currently active thread ID |
| [7:8] | active_state | Active thread state |
| [9:12] | ready_threads | Ready thread count |
| [13:16] | blocked_threads | Blocked thread count |
| [17:24] | pending_queue | Pending thread IDs bitmask |
| [25:31] | reserved | Reserved |

**SCHED_MODE (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:1] | mode | 0=Round-Robin, 1=Priority, 2=Hybrid, 3=Reserved |
| [2] | preemptive | Preemptive scheduling enable |
| [3] | affinity | Thread affinity enable |
| [4:7] | quantum | Round-Robin quantum (multiplier) |
| [8:15] | weight_0 | Thread 0 weight for weighted RR |
| [16:23] | weight_1 | Thread 1 weight for weighted RR |
| [24:31] | reserved | Reserved |

**THREAD_STATE_0/1 (0x0014/0x0018)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:1] | thread_0_state | Thread 0 state: 0=Empty, 1=Ready, 2=Running, 3=Blocked/Completed |
| [2:3] | thread_1_state | Thread 1 state |
| [4:5] | thread_2_state | Thread 2 state |
| [6:7] | thread_3_state | Thread 3 state |
| [8:31] | reserved | Reserved (THREAD_STATE_1: thread_4-7) |

## 3. Functional Description

### 3.1 Thread Management

Thread Manager 维护硬件线程上下文，支持 2-8 个线程并发执行。

#### 3.1.1 Thread States

| State | Code | Description | Transitions |
|-------|------|-------------|-------------|
| EMPTY | 0 | Thread context not initialized | -> READY (THREAD_CREATE) |
| READY | 1 | Thread ready for execution | -> RUNNING (dispatch), -> BLOCKED (sync) |
| RUNNING | 2 | Thread currently executing | -> READY (quantum expire), -> BLOCKED (wait), -> EMPTY (kill) |
| BLOCKED | 3 | Thread blocked (sync/wait) or Completed | -> READY (unblock), -> EMPTY (kill) |

#### 3.1.2 Thread Context Structure

每个线程上下文包含以下状态信息（256 bits）：

| Field | Width | Description |
|-------|-------|-------------|
| PC | 32 | Program counter |
| GPR[0:7] | 64 (8x8) | General purpose registers |
| FLAGS | 8 | Status flags (carry, zero, overflow) |
| PRIORITY | 3 | Thread priority |
| STATE | 2 | Thread state |
| QUANTUM_CNT | 16 | Quantum counter remaining |
| WAIT_ID | 4 | Wait/sync target ID |
| RESERVED | 131 | Reserved for future extensions |

#### 3.1.3 Thread Creation Process

```
Thread Creation Sequence:
  1. ISA Decoder issues THREAD_CREATE command
  2. Scheduler allocates thread ID (first empty slot)
  3. Initialize thread context:
     - PC = entry address
     - GPR[0] = initialization data
     - PRIORITY = specified priority
     - STATE = READY
     - QUANTUM_CNT = SCHED_QUANTUM
  4. Update THREAD_ENABLE bitmask
  5. Return thread_id to ISA Decoder
```

#### 3.1.4 Thread Lifecycle

```
    +-------+      THREAD_CREATE      +-------+
    | EMPTY | -----------------------> | READY |
    +-------+                          +---+---+
                                            |
                                 dispatch   |
                                            v
                                        +-------+
                                        | RUNNING|
                                        +---+---+
                                            |
            +-------------------------------+
            |            |                  |
    quantum |    THREAD_KILL      wait/sync  |
    expire  |          v                  v
            |     +-------+           +-------+
            +---> | EMPTY |           | BLOCKED|
                  +-------+           +---+---+
                                          |
                              unblock/resume
                                          v
                                      +-------+
                                      | READY |
                                      +-------+
```

### 3.2 Scheduling Algorithm

Scheduler 支持三种调度模式，满足不同应用场景需求。

#### 3.2.1 Round-Robin Scheduling

Round-Robin 模式公平分配执行时间给所有 Ready 线程。

**Algorithm**

```
Round-Robin Dispatch:
  1. Select next Ready thread from circular queue
  2. Dispatch thread to M01 for quantum duration
  3. After quantum expires:
     - Save current thread context
     - Select next Ready thread
     - Context switch to next thread
  4. Repeat until all threads completed
```

**Quantum Configuration**

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| SCHED_QUANTUM | 1000 cycles | 100-10000 | Time slice per thread |
| Preemptive | Disabled | - | Can be enabled for interrupt response |

**Pros and Cons**

| Aspect | Round-Robin | Use Case |
|--------|-------------|----------|
| Fairness | High - equal time slices | Multi-task parallel inference |
| Latency | Predictable - quantum bound | Deterministic execution |
| Throughput | Medium - context switch overhead | Balanced workload |

#### 3.2.2 Priority Scheduling

Priority 模式按优先级顺序调度线程，高优先级线程优先执行。

**Algorithm**

```
Priority Dispatch:
  1. Sort Ready threads by priority (highest first)
  2. Dispatch highest priority Ready thread
  3. Thread executes until:
     - Completed (THREAD_KILL)
     - Blocked (wait/sync)
     - Preempted by higher priority thread (if preemptive enabled)
  4. Select next highest priority Ready thread
```

**Priority Levels**

| Level | Priority | Description | Use Case |
|-------|----------|-------------|----------|
| Critical | 7 | Highest priority | Interrupt handlers, real-time tasks |
| High | 5-6 | High priority | Critical inference stages |
| Medium | 3-4 | Normal priority | Standard computation tasks |
| Low | 0-2 | Low priority | Background tasks, debugging |

**Preemptive Mode**

当 SCHED_MODE[2]=1 (preemptive) 时：
- 高优先级线程可以抢占正在执行的低优先级线程
- 抢占触发立即 context switch
- 被抢占线程状态保存，返回 READY 状态

#### 3.2.3 Hybrid Scheduling

Hybrid 模式结合 Round-Robin 和 Priority 的优点。

**Algorithm**

```
Hybrid Dispatch:
  1. Group threads by priority level
  2. Within each priority group, use Round-Robin
  3. Higher priority groups preempt lower priority groups
  4. All threads in a group complete before moving to lower group
```

**Configuration**

| Parameter | Description |
|-----------|-------------|
| Priority Groups | Threads with same priority form a group |
| Intra-group RR | Round-Robin within group |
| Inter-group Priority | Higher group preempt lower group |

### 3.3 Context Switch

Context Switch 实现线程上下文的保存和恢复，是调度的核心操作。

#### 3.3.1 Context Switch Sequence

```
Context Switch Sequence (Save Current, Load Next):
  1. Pause current thread execution (signal M01)
  2. Save current context to Context Storage:
     - ctx_wr_ptr = current_thread_id * context_size
     - ctx_wr_data = {PC, GPR, FLAGS, PRIORITY, STATE, QUANTUM_CNT}
     - Wait for ctx_wr_ready
  3. Update thread state: current -> READY/BLOCKED
  4. Select next thread to run
  5. Load next context from Context Storage:
     - ctx_rd_ptr = next_thread_id * context_size
     - Wait for ctx_rd_valid
     - ctx_rd_data = saved context
  6. Update thread state: next -> RUNNING
  7. Dispatch to M01:
     - dispatch_thread_id = next_thread_id
     - dispatch_entry_addr = loaded PC
     - dispatch_cmd = DISPATCH_SWITCH
  8. Wait for dispatch_done
```

#### 3.3.2 Context Switch Timing

| Phase | Cycles | Description |
|-------|--------|-------------|
| Pause current | 1 | Signal M01 to pause |
| Save context | 2-3 | Write to Context Storage |
| State update | 1 | Update thread state vector |
| Select next | 1-2 | Priority/RR selection |
| Load context | 2-3 | Read from Context Storage |
| Dispatch | 1-2 | Send to M01 |
| Total | 8-10 | Complete context switch |

#### 3.3.3 Context Storage Architecture

```
Context Storage Organization:
  +----------------------------------+
  | Thread 0 Context (256 bits)      | <- Offset 0x00
  +----------------------------------+
  | Thread 1 Context (256 bits)      | <- Offset 0x01
  +----------------------------------+
  | Thread 2 Context (256 bits)      | <- Offset 0x02
  +----------------------------------+
  | ...                              |
  +----------------------------------+
  | Thread 7 Context (256 bits)      | <- Offset 0x07
  +----------------------------------+
  
  Total: 8 contexts x 256 bits = 2048 bits (256 bytes)
```

### 3.4 Dispatch to Dataflow Controller

Dispatch 模块负责将调度决策发送到 M01 Dataflow Controller。

#### 3.4.1 Dispatch Protocol

```
Dispatch Handshake:
  Scheduler                M01 Dataflow Controller
      |                           |
      +-- dispatch_valid ---------+
      |                           |
      +-- dispatch_thread_id -----> (thread context ID)
      +-- dispatch_entry_addr ----> (start/resume address)
      +-- dispatch_context_ptr ---> (context storage pointer)
      +-- dispatch_cmd -----------> (START/SWITCH/RESUME/STOP)
      |                           |
      |<-- dispatch_ready --------+
      |                           |
      |    [M01 loads context]    |
      |                           |
      |<-- dispatch_done ---------+
      |                           |
      +-- dispatch_valid = 0 -----+
```

#### 3.4.2 Dispatch Commands

| Command | Description | Target State |
|---------|-------------|--------------|
| DISPATCH_START | Start new thread execution | Thread: READY -> RUNNING |
| DISPATCH_SWITCH | Context switch to different thread | Old: RUNNING -> READY, New: READY -> RUNNING |
| DISPATCH_RESUME | Resume blocked thread | Thread: BLOCKED -> RUNNING |
| DISPATCH_STOP | Stop thread execution | Thread: RUNNING -> READY/BLOCKED |

#### 3.4.3 Dispatch Error Handling

| Error | Code | Handling |
|-------|------|----------|
| Invalid thread ID | 0x01 | Return error to ISA Decoder, no dispatch |
| Context not ready | 0x02 | Wait for context storage ready, retry |
| M01 not ready | 0x03 | Queue dispatch, retry when ready |
| Thread blocked | 0x04 | Select alternate thread |

### 3.5 Thread Synchronization

Thread Sync 支持线程间同步操作，实现 barrier 和 wait 机制。

#### 3.5.1 Barrier Synchronization

```
Barrier Sync Sequence:
  1. Thread executes THREAD_SYNC command (barrier)
  2. Scheduler marks thread as BLOCKED (wait for barrier)
  3. When all threads reach barrier:
     - Release all waiting threads
     - Update state: BLOCKED -> READY
     - Resume normal scheduling
```

**Barrier Configuration**

| Parameter | Description |
|-----------|-------------|
| Barrier ID | 0-3 (4 barriers supported) |
| Wait Count | Number of threads waiting at barrier |
| Release Mode | All threads released simultaneously |

#### 3.5.2 Wait/Signal Mechanism

```
Wait/Signal Sequence:
  1. Thread A executes THREAD_SYNC (wait for thread B)
  2. Scheduler marks thread A as BLOCKED
  3. Thread B reaches completion or signal point
  4. Scheduler unblocks thread A
  5. Thread A state: BLOCKED -> READY
  6. Thread A resumes execution
```

### 3.6 Interrupt Handling

Thread Interrupt 支持紧急事件处理。

#### 3.6.1 Interrupt Types

| Type | Code | Description |
|------|------|-------------|
| 0x0 | THREAD_TIMEOUT | Thread execution timeout |
| 0x1 | THREAD_ERROR | Thread execution error |
| 0x2 | THREAD_EXCEPTION | Hardware exception |
| 0x3 | EXTERNAL_IRQ | External interrupt request |
| 0x4-0xF | Reserved | Reserved |

#### 3.6.2 Interrupt Response

```
Interrupt Handling Sequence:
  1. Interrupt detected (thread_irq = 1)
  2. If preemptive enabled:
     - Current thread preempted, state -> READY
     - Context saved
  3. Interrupt handler thread dispatched:
     - Priority = Critical (7)
     - Entry address = interrupt vector
  4. Handler thread executes
  5. Handler completes, return to preempted thread or next READY thread
```

## 4. Timing

### 4.1 Scheduling Latency

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_thread_create | 5-8 cycles | Thread creation latency |
| t_dispatch_decision | 1-2 cycles | Dispatch decision time |
| t_prio_select | 1-2 cycles | Priority selection time |
| t_rr_select | 1 cycle | Round-Robin selection time |
| t_state_update | 1 cycle | Thread state update time |

### 4.2 Context Switch Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_ctx_save | 2-3 cycles | Context save to storage |
| t_ctx_load | 2-3 cycles | Context load from storage |
| t_ctx_switch_total | 8-10 cycles | Complete context switch |
| t_dispatch_send | 1-2 cycles | Dispatch command to M01 |
| t_dispatch_ack | 2-4 cycles | M01 acknowledgment |

### 4.3 Quantum Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_quantum_min | 100 cycles | Minimum quantum |
| t_quantum_default | 1000 cycles | Default quantum |
| t_quantum_max | 10000 cycles | Maximum quantum |
| t_quantum_granularity | 100 cycles | Quantum adjustment granularity |

### 4.4 Interrupt Response Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_irq_detect | 1 cycle | Interrupt detection |
| t_irq_preempt | 3-5 cycles | Preemption latency |
| t_irq_handler_start | 5-8 cycles | Handler thread dispatch |
| t_irq_total | 10-15 cycles | Complete interrupt response |

### 4.5 Throughput

| Metric | Target | Condition |
|--------|--------|-----------|
| Max Threads | 8 | Configurable via SCHED_CTRL[4:7] |
| Dispatch Rate | >= 50 M dispatch/s | @ 500 MHz, 10 cycles/dispatch |
| Context Switch Rate | >= 50 M switch/s | @ 500 MHz, 10 cycles/switch |
| Thread Throughput | >= 4 thread/s | @ 500 MHz, 125M cycles/thread |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **Thread Count**: 支持 2-8 线程，满足 REQ-COMPUTE-006 要求的最小 2 线程，可扩展至 8 线程。

2. **Context Storage**: 256-bit per thread context，存储在专用 SRAM 区域，支持快速读写。

3. **Scheduling Safety**: 调度必须保证：
   - 无饥饿：Round-Robin 模式下所有线程最终获得执行
   - 无死锁：同步操作支持 timeout 超时退出
   - 响应性：Priority 模式高优先级线程快速响应

4. **Preemptive Support**: 抢占式调度支持实时响应，但增加 context switch 开销。

5. **Power Efficiency**: Idle 状态下 scheduler 进入低功耗模式，仅维护上下文。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol | Notes |
|-----------|---------------|----------|-------|
| Thread Control | M13 ISA Decoder | Custom | Thread command interface |
| Register | M04 System Bus | Register | Status/control registers |
| Dispatch | M01 Dataflow Controller | Custom | Thread dispatch |
| Context | Internal Storage | SRAM | Thread context storage |
| Power | M05 Power Manager | Control | Clock enable, power gate |

### 5.3 Verification Requirements

| Test Category | Description |
|---------------|-------------|
| Thread Lifecycle | 验证 CREATE/START/PAUSE/RESUME/KILL 状态转换 |
| Scheduling Modes | 验证 Round-Robin/Priority/Hybrid 调度行为 |
| Context Switch | 验证 context 保存/恢复正确性和延迟 |
| Dispatch | 验证与 M01 的 dispatch handshake |
| Synchronization | 验证 barrier 和 wait/signal 机制 |
| Interrupt | 验证中断响应和抢占行为 |
| Performance | 验证 scheduling latency 和 throughput |

### 5.4 Power Budget Allocation

| Domain | Budget | Allocation |
|--------|--------|------------|
| Scheduler Logic | 10 mW | FSM, selection logic |
| Context Storage | 8 mW | SRAM for thread contexts |
| Dispatch Interface | 5 mW | Interface to M01 |
| Register Interface | 5 mW | Bus register interface |
| Interrupt Handler | 2 mW | Interrupt logic |
| **Total** | **30 mW** | @ OP0, 500 MHz |

### 5.5 Clock Domain Considerations

| Domain | Frequency | Impact |
|--------|-----------|--------|
| CLK_SYS | 250-500 MHz | Scheduler operates in CLK_SYS |
| DVFS | 0.5x-1.0x | Quantum values scaled with DVFS |
| Power Gate | Disabled | Scheduler must remain active during compute |

### 5.6 Reset Strategy

| Reset | Source | Effect |
|-------|--------|--------|
| rst_por_n | Power-On | All contexts cleared, FSM to IDLE |
| rst_sys_n | External | Running threads paused, contexts retained |
| Soft Reset | SCHED_CTRL[0]=0 | Scheduler disabled, contexts retained |

### 5.7 Relationship with M01 Dataflow Controller

M08 Scheduler 与 M01 Dataflow Controller 形成调度-执行耦合：

| Aspect | M08 Scheduler | M01 Dataflow Controller |
|--------|---------------|-------------------------|
| Role | Thread management, scheduling | Spatial dataflow execution |
| Interface | Dispatch command | Receive dispatch, execute thread |
| Context | Save/load thread context | Use context for execution |
| Feedback | Completion/error signals | Report execution status |
| Coupling | Tight coupling | Must respond to dispatch |

### 5.8 Extension Points

| Extension | Description |
|-----------|-------------|
| Thread Count | 可扩展至 16 threads (增加 context storage) |
| Priority Levels | 可扩展至 16 levels (增加 priority bits) |
| Scheduling Algorithm | 可添加自定义调度算法 |
| Synchronization | 可扩展 barrier 数量和类型 |