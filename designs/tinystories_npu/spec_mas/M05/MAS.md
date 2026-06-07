---
module: M05
type: MAS
status: complete
parent: null
module_type: control
generated: "2026-05-17T14:55:00+08:00"
---

# M05: Power Manager

## 1. Overview

M05 Power Manager 是 TinyStories NPU 的功耗管理核心模块，位于 Always-On Power Domain (PD_AON)，负责整个芯片的功耗状态管理。该模块实现 DVFS（动态电压频率调整）、Power Mode FSM（功耗模式状态机）、Wakeup Controller（唤醒控制器）和 Power Estimator（功耗估算器）四大功能，确保系统在满足性能需求的同时达到 REQ-PWR-001 规定的 < 1.8W 功耗目标。

### 1.1 Key Features

| Feature | Description | REQ Reference |
|---------|-------------|---------------|
| DVFS Controller | 频率/电压动态切换，支持 3 个 Operating Points | REQ-PWR-003 |
| Power Mode FSM | Active/Sleep/Deep Sleep 三态管理 | REQ-PWR-002 |
| Wakeup Controller | 外部唤醒信号处理，支持快速唤醒 | REQ-PWR-002 |
| Power Estimator | 实时功耗估算，用于功耗预算管理 | - |

### 1.2 Clock & Power Domain

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock Domain | CLK_AON | 1 MHz，Always-On 时钟 |
| Power Domain | PD_AON | 0.6-0.9 V，永不掉电 |
| Target Power | 7 mW | 所有模式下恒定功耗 |

## 2. Interface

### 2.1 Signal List

#### 2.1.1 Clock & Reset

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk_aon | Input | 1 | Always-On 时钟，1 MHz |
| rst_aon_n | Input | 1 | Always-On 异步复位，低有效 |
| rst_por_n | Input | 1 | Power-On Reset，低有效 |

#### 2.1.2 System Bus Interface (TileLink/AXI)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| bus_cmd_valid | Input | 1 | 总线命令有效 |
| bus_cmd_ready | Output | 1 | 总线命令就绪 |
| bus_cmd_addr | Input | 16 | 命令地址（寄存器访问） |
| bus_cmd_rw | Input | 1 | 读/写命令标识 |
| bus_cmd_data | Input | 32 | 写数据 |
| bus_rsp_valid | Output | 1 | 响应有效 |
| bus_rsp_data | Output | 32 | 读响应数据 |
| bus_rsp_error | Output | 1 | 响应错误标志 |

#### 2.1.3 DVFS Control Interface (to M06 Clock Manager)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| dvfs_op_req | Output | 2 | DVFS Operating Point 请求 (0=OP0, 1=OP1, 2=OP2) |
| dvfs_op_ack | Input | 1 | DVFS OP 切换完成确认 |
| dvfs_vdd_req | Output | 3 | VDD_MAIN 电压请求编码 |
| dvfs_freq_req | Output | 32 | CLK_SYS 频率请求 (Hz) |
| dvfs_busy | Input | 1 | DVFS 切换进行中标志 |

#### 2.1.4 Voltage Regulator Interface (External)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| vdd_main_set | Output | 8 | VDD_MAIN 设定值 (0.7-0.9V, 50mV step) |
| vdd_main_ack | Input | 1 | 电压设定完成确认 |
| vdd_main_ready | Input | 1 | Voltage Regulator 就绪 |
| vdd_main_error | Input | 1 | Voltage Regulator 错误标志 |

#### 2.1.5 Power Gate Control (to PD_MAIN)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| pg_main_en | Output | 1 | PD_MAIN Power Gate 使能 |
| pg_main_status | Input | 1 | PD_MAIN Power Gate 状态反馈 |
| pg_main_switch | Output | 1 | Header/Footer Switch 控制 |
| pg_iso_en | Output | 1 | Isolation Cell 使能 |

#### 2.1.6 Power Mode Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| pmode_state | Output | 2 | 当前功耗模式 (0=Active, 1=Sleep, 2=Deep Sleep) |
| pmode_req | Input | 2 | 功耗模式请求 |
| pmode_ack | Output | 1 | 功耗模式切换完成 |
| pmode_error | Output | 1 | 功耗模式切换错误 |

#### 2.1.7 Wakeup Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| wakeup_ext | Input | 8 | 外部唤醒信号 (8 sources) |
| wakeup_en | Output | 8 | 唤醒源使能掩码 |
| wakeup_status | Output | 8 | 唤醒源状态 |
| wakeup_pending | Output | 1 | 唤醒请求待处理 |
| wakeup_clear | Input | 1 | 清除唤醒状态 |

#### 2.1.8 Power Estimator Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| pwr_estimate | Output | 16 | 当前功耗估算值 (mW) |
| pwr_budget | Input | 16 | 功耗预算设定 (mW) |
| pwr_alert | Output | 1 | 功耗超限告警 |
| pwr_counters | Output | 32 | 功耗计数器采样值 |

#### 2.1.9 Activity Monitoring

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| activity_main | Input | 1 | PD_MAIN 活动状态 |
| activity_io | Input | 1 | PD_IO 活动状态 |
| activity_dram | Input | 1 | DRAM 活动状态 |
| idle_timeout | Input | 16 | 空闲超时阈值 (ms) |
| idle_detected | Output | 1 | 空闲状态检测标志 |

#### 2.1.10 Status & Interrupt

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| pm_status | Output | 8 | Power Manager 状态寄存器 |
| pm_irq | Output | 1 | Power Manager 中断请求 |
| pm_irq_type | Output | 3 | 中断类型编码 |

### 2.2 Register Map

| Offset | Name | R/W | Width | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | PM_CTRL | RW | 32 | Power Manager 控制寄存器 |
| 0x0004 | PM_STATUS | R | 32 | Power Manager 状态寄存器 |
| 0x0008 | PM_MODE | RW | 32 | 功耗模式设定/状态寄存器 |
| 0x000C | DVFS_CTRL | RW | 32 | DVFS 控制寄存器 |
| 0x0010 | DVFS_STATUS | R | 32 | DVFS 状态寄存器 |
| 0x0014 | DVFS_OP0 | RW | 32 | Operating Point 0 配置 |
| 0x0018 | DVFS_OP1 | RW | 32 | Operating Point 1 配置 |
| 0x001C | DVFS_OP2 | RW | 32 | Operating Point 2 配置 |
| 0x0020 | VDD_CTRL | RW | 32 | 电压控制寄存器 |
| 0x0024 | VDD_STATUS | R | 32 | 电压状态寄存器 |
| 0x0028 | PG_CTRL | RW | 32 | Power Gate 控制寄存器 |
| 0x002C | PG_STATUS | R | 32 | Power Gate 状态寄存器 |
| 0x0030 | WAKEUP_EN | RW | 32 | 唤醒源使能寄存器 |
| 0x0034 | WAKEUP_STATUS | R | 32 | 唤醒状态寄存器 |
| 0x0038 | WAKEUP_CLEAR | RW | 32 | 唤醒清除寄存器 |
| 0x003C | PWR_ESTIMATE | R | 32 | 功耗估算值寄存器 |
| 0x0040 | PWR_BUDGET | RW | 32 | 功耗预算寄存器 |
| 0x0044 | PWR_COUNTERS | R | 32 | 功耗计数器寄存器 |
| 0x0048 | IDLE_CTRL | RW | 32 | 空闲检测控制寄存器 |
| 0x004C | IDLE_STATUS | R | 32 | 空闲检测状态寄存器 |
| 0x0050 | IRQ_ENABLE | RW | 32 | 中断使能寄存器 |
| 0x0054 | IRQ_STATUS | R | 32 | 中断状态寄存器 |
| 0x0058 | IRQ_CLEAR | RW | 32 | 中断清除寄存器 |

#### 2.2.1 Register Bit Definitions

**PM_CTRL (0x0000)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enable | Power Manager 使能 |
| [1] | dvfs_en | DVFS 功能使能 |
| [2] | pg_en | Power Gate 功能使能 |
| [3] | wakeup_en | Wakeup 功能使能 |
| [4] | pwr_est_en | Power Estimator 功能使能 |
| [5] | idle_det_en | 空闲检测使能 |
| [6] | auto_pmode_en | 自动功耗模式切换使能 |
| [7] | irq_en | 中断使能 |
| [8:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**PM_STATUS (0x0004)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | ready | Power Manager 就绪 |
| [1] | busy | 操作进行中 |
| [2] | error | 错误标志 |
| [3] | dvfs_busy | DVFS 切换进行中 |
| [4] | pg_active | Power Gate 激活 |
| [5] | wakeup_pending | 唤醒待处理 |
| [6] | pwr_alert | 功耗超限 |
| [7] | idle_detected | 空闲检测 |
| [8:15] | current_op | 当前 Operating Point |
| [16:23] | current_pmode | 当前功耗模式 |
| [24:31] | reserved | 保留 |

**PM_MODE (0x0008)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:1] | mode_req | 功耗模式请求 (0=Active, 1=Sleep, 2=Deep Sleep) |
| [2:3] | mode_current | 当前功耗模式 |
| [4] | mode_ack | 模式切换完成 |
| [5] | mode_error | 模式切换错误 |
| [6:7] | transition_time | 切换时间 (ms) |
| [8:15] | wakeup_latency | 唤醒延迟配置 (ms) |
| [16:31] | reserved | 保留 |

**DVFS_CTRL (0x000C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:1] | op_target | 目标 Operating Point |
| [2] | op_switch_req | OP 切换请求 |
| [3] | op_switch_force | 强制切换（忽略 busy） |
| [4:7] | transition_rate | 切换速率控制 |
| [8:15] | reserved | 保留 |
| [16:31] | reserved | 保留 |

**DVFS_OP0/OP1/OP2 (0x0014/0x0018/0x001C)**

| Bit | Name | Description |
|-----|------|-------------|
| [0:15] | frequency | 频率设定 (MHz * 1000) |
| [16:23] | voltage | 电压设定 (V * 100) |
| [24:31] | power_limit | 功耗限制 (mW) |

**WAKEUP_EN (0x0030)**

| Bit | Name | Description |
|-----|------|-------------|
| [0] | wakeup_src0_en | Wakeup Source 0 使能 (JTAG) |
| [1] | wakeup_src1_en | Wakeup Source 1 使能 (ISA IF) |
| [2] | wakeup_src2_en | Wakeup Source 2 使能 (Timer) |
| [3] | wakeup_src3_en | Wakeup Source 3 使能 (GPIO) |
| [4] | wakeup_src4_en | Wakeup Source 4 使能 (DRAM) |
| [5] | wakeup_src5_en | Wakeup Source 5 使能 (Activity) |
| [6] | wakeup_src6_en | Wakeup Source 6 使能 (Software) |
| [7] | wakeup_src7_en | Wakeup Source 7 使能 (Error) |
| [8:31] | reserved | 保留 |

## 3. Functional Description

### 3.1 Power Mode FSM

Power Mode FSM 管理 TinyStories NPU 的三种功耗状态，实现功耗与唤醒延迟的平衡。

#### 3.1.1 State Diagram

```
      +-------+
      | RESET |
      +---+---+
          |
          v
      +-------+<--------------------+
      | ACTIVE|                     |
      +---+---+                     |
          |                         |
    (idle_timeout / pmode_req=1)    |
          v                         |
      +-------+                     |
      | SLEEP |                     |
      +---+---+                     |
          |                         |
 (wakeup / pmode_req=0)             |
          +-------------------------+
          |
          | (pmode_req=2 / long_idle)
          v
      +-------+
      |DEEP   |
      |SLEEP  |
      +---+---+
          |
          | (wakeup / pmode_req=0)
          v
      +-------+
      | ACTIVE|
      +-------+
```

#### 3.1.2 State Definitions

| State | Code | Description | Power Domains | DVFS OP | Wakeup Time |
|-------|------|-------------|---------------|---------|-------------|
| ACTIVE | 0x0 | 正常运行，全功能可用 | All (PD_MAIN, PD_AON, PD_IO) | OP0/OP1 | - |
| SLEEP | 0x1 | 低功耗待机，快速唤醒 | PD_AON, PD_IO | OP1 | < 1 ms |
| DEEP_SLEEP | 0x2 | 最低功耗，较长唤醒延迟 | PD_AON only | OP2 | < 10 ms |

#### 3.1.3 State Transitions

| From | To | Trigger | Actions | Duration |
|------|----|---------|---------|----------|
| RESET | ACTIVE | rst_por_n release | 初始化所有状态，设置 OP0 | < 100 us |
| ACTIVE | SLEEP | idle_timeout / pmode_req=1 | DVFS OP1, Clock Gate PD_MAIN | < 100 us |
| ACTIVE | DEEP_SLEEP | pmode_req=2 / long_idle | DVFS OP2, Power Gate PD_MAIN, Clock Gate PD_IO | < 1 ms |
| SLEEP | ACTIVE | wakeup / pmode_req=0 | DVFS OP0/OP1, Enable PD_MAIN clocks | < 1 ms |
| SLEEP | DEEP_SLEEP | pmode_req=2 | DVFS OP2, Power Gate PD_MAIN, Clock Gate PD_IO | < 1 ms |
| DEEP_SLEEP | ACTIVE | wakeup / pmode_req=0 | Power Gate release, DVFS OP0, Enable all clocks | < 10 ms |
| DEEP_SLEEP | SLEEP | pmode_req=1 | DVFS OP1, Release PD_IO clocks | < 5 ms |

### 3.2 DVFS Control

DVFS Controller 实现动态电压频率调整，支持三个 Operating Points。

#### 3.2.1 Operating Points Definition

| OP | VDD_MAIN | CLK_SYS | Power | Use Case | REQ |
|----|----------|----------|-------|----------|-----|
| OP0 | 0.9 V | 500 MHz | 1.79 W | Active inference，最高性能 | REQ-PERF-001 |
| OP1 | 0.7 V | 250 MHz | 0.61 W | Light load，平衡功耗性能 | - |
| OP2 | 0.6 V (AON) | 1 MHz (AON) | 0.09 W | Deep sleep，最低功耗 | REQ-PWR-002 |

#### 3.2.2 DVFS Switching Sequence

```
OP Switch Request (op_switch_req=1)
    |
    v
Check dvfs_busy
    |
    +-- busy --> wait / error if force
    |
    v
Set dvfs_op_req, dvfs_vdd_req, dvfs_freq_req
    |
    v
Wait for vdd_main_ack (timeout: 100 us)
    |
    v
Wait for dvfs_op_ack from M06 (timeout: 1 ms)
    |
    v
Update DVFS_STATUS
    |
    v
Generate IRQ (if enabled)
```

#### 3.2.3 Voltage Transition

| Parameter | Value | Description |
|-----------|-------|-------------|
| Voltage Range | 0.7 - 0.9 V | VDD_MAIN 可调范围 |
| Voltage Step | 50 mV | 最小调整步长 |
| Transition Time | < 100 us | 单步电压切换时间 |
| Transition Rate | 可配置 | dvfs_ctrl[4:7] 控制 |

#### 3.2.4 DVFS Arbitration

| Scenario | Policy |
|----------|--------|
| 多模块同时请求 DVFS | 最高性能优先（OP0 > OP1 > OP2） |
| DVFS 切换中新请求 | 等待当前切换完成或强制中断 |
| Power Mode 切换触发 DVFS | Power Mode 优先级高于独立 DVFS 请求 |

### 3.3 Wakeup Controller

Wakeup Controller 处理 8 个唤醒源，实现快速唤醒响应。

#### 3.3.1 Wakeup Sources

| Source ID | Name | Description | Priority |
|-----------|------|-------------|----------|
| 0 | JTAG | IEEE 1149.1 调试唤醒 | High |
| 1 | ISA_IF | NPU 指令接口唤醒请求 | High |
| 2 | Timer | 定时器唤醒（可配置） | Medium |
| 3 | GPIO | 外部 GPIO 信号唤醒 | Medium |
| 4 | DRAM | DRAM 活动唤醒 | Low |
| 5 | Activity | 模块活动检测唤醒 | Low |
| 6 | Software | 软件 DDR 写入唤醒 | Medium |
| 7 | Error | 错误状态唤醒 | High |

#### 3.3.2 Wakeup Sequence

```
Wakeup Signal Detected (wakeup_ext[i]=1)
    |
    v
Check wakeup_en[i]
    |
    +-- disabled --> ignore
    |
    v
Set wakeup_status[i]=1, wakeup_pending=1
    |
    v
Generate IRQ (if enabled)
    |
    v
PMODE FSM: DEEP_SLEEP/SLEEP --> ACTIVE
    |
    v
Wait for pmode_ack
    |
    v
Clear wakeup_status (wakeup_clear=1)
```

#### 3.3.3 Wakeup Latency

| From Mode | To Mode | Latency | Description |
|-----------|---------|---------|-------------|
| SLEEP | ACTIVE | < 1 ms | Clock enable + PLL stabilize |
| DEEP_SLEEP | ACTIVE | < 10 ms | Power gate release + Voltage ramp + PLL stabilize |

### 3.4 Power Estimator

Power Estimator 实时估算系统功耗，用于功耗预算管理。

#### 3.4.1 Estimation Model

```
Total Power = PD_MAIN_Power + PD_AON_Power + PD_IO_Power + DRAM_Power

PD_MAIN_Power = Activity_Factor * Max_Power * DVFS_Factor
  where:
    - Activity_Factor = activity_main (0-100%)
    - Max_Power = 1.7 W @ OP0
    - DVFS_Factor = (VDD/VDD_max)^2 * (CLK/CLK_max)

PD_AON_Power = 7 mW (constant)

PD_IO_Power = Activity_IO * Max_Power_IO
  where:
    - Max_Power_IO = 15 mW @ Active

DRAM_Power = Activity_DRAM * Max_Power_DRAM
  where:
    - Max_Power_DRAM = 80 mW @ OP0
```

#### 3.4.2 Power Budget Management

| Feature | Description |
|---------|-------------|
| Budget Setting | pwr_budget 寄存器设定目标功耗 (mW) |
| Alert Threshold | pwr_estimate > pwr_budget 时触发 pwr_alert |
| Auto Throttle | pwr_alert 触发自动 DVFS 降低功耗 |
| Counter Sampling | pwr_counters 提供详细计数器数据 |

### 3.5 Power Gate Control

Power Gate Controller 管理 PD_MAIN 的电源门控。

#### 3.5.1 Power Gate Sequence

```
Power Gate Request (pmode=DEEP_SLEEP)
    |
    v
Set pg_iso_en=1 (Isolation Cell active)
    |
    v
Wait 10 cycles for output stabilization
    |
    v
Set pg_main_switch=0 (Header/Footer OFF)
    |
    v
Wait for pg_main_status=0
    |
    v
Set pg_main_en=1 (Power Gate active)
    |
    v
Update PG_STATUS

Power Gate Release (wakeup / pmode=ACTIVE)
    |
    v
Set pg_main_en=0 (Power Gate inactive)
    |
    v
Set pg_main_switch=1 (Header/Footer ON)
    |
    v
Wait for pg_main_status=1 (Voltage stable)
    |
    v
Wait 100 us for power stabilization
    |
    v
Set pg_iso_en=0 (Isolation Cell inactive)
    |
    v
Update PG_STATUS
```

### 3.6 Idle Detection

Idle Detection 模块监控系统活动，触发自动功耗模式切换。

#### 3.6.1 Idle Detection Logic

```
Activity Monitoring:
  - activity_main, activity_io, activity_dram

Idle Counter:
  - Increment when all activity signals = 0
  - Reset when any activity signal = 1

Idle Detection:
  - idle_counter > idle_timeout --> idle_detected = 1

Auto Power Mode Switch:
  - auto_pmode_en=1 AND idle_detected=1 --> pmode_req = SLEEP
  - configurable transition delay
```

## 4. Timing

### 4.1 DVFS Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_vdd_switch | < 100 us | 单步电压切换时间 |
| t_pll_lock | < 1 ms | PLL 锁定时间 |
| t_dvfs_total | < 1.5 ms | DVFS 完整切换时间 (OP0->OP2) |
| t_op_stable | < 10 us | OP 稳定确认时间 |

### 4.2 Power Gate Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_pg_enter | < 1 ms | Power Gate 进入时间 |
| t_pg_exit | < 10 ms | Power Gate 退出时间 |
| t_iso_setup | 10 cycles | Isolation Cell 建立时间 |
| t_iso_hold | 100 us | Power 稳定后 Iso 保持时间 |

### 4.3 Wakeup Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_wakeup_sleep | < 1 ms | Sleep 模式唤醒时间 |
| t_wakeup_deep | < 10 ms | Deep Sleep 模式唤醒时间 |
| t_wakeup_irq | < 10 us | Wakeup IRQ 响应时间 |
| t_wakeup_clear | < 1 us | Wakeup 状态清除时间 |

### 4.4 Register Access Timing

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_reg_read | 1 cycle | 寄存器读访问时间 |
| t_reg_write | 1 cycle | 寄存器写访问时间 |
| t_reg_update | 2 cycles | 状态寄存器更新延迟 |

## 5. Implementation Notes

### 5.1 Design Considerations

1. **Always-On Design**: M05 位于 PD_AON，所有逻辑必须使用低漏电工艺，确保 7 mW 恒定功耗。

2. **DVFS 安全性**: DVFS 切换必须保证：
   - 电压先降低，频率后降低（降压）
   - 频率先升高，电压后升高（升频）
   - 切换过程中暂停所有 PD_MAIN 活动

3. **Power Gate 集成**: Header/Footer Switch 和 Isolation Cell 由 M05 控制，需与物理设计协同。

4. **Wakeup 极性**: 所有 wakeup 信号为高有效，支持 edge 和 level 检测模式。

5. **功耗估算精度**: Power Estimator 使用简化模型，实际功耗需实测校准。

### 5.2 Integration Requirements

| Interface | Target Module | Protocol |
|-----------|---------------|----------|
| DVFS Control | M06 Clock Manager | Custom handshake |
| Voltage Regulator | External PMIC | Custom handshake |
| Power Gate | PD_MAIN Switches | Direct control |
| System Bus | M04 System Bus | TileLink/AXI |

### 5.3 Verification Requirements

| Test Category | Description |
|---------------|-------------|
| DVFS Switch | 验证所有 OP 切换路径和时序 |
| Power Mode FSM | 验证所有状态转换和唤醒 |
| Power Gate | 验证 Power Gate 进入/退出序列 |
| Wakeup | 验证所有唤醒源响应 |
| Power Estimator | 验证估算精度和告警 |

### 5.4 Power Budget Allocation

| Domain | Budget | Allocation |
|--------|--------|------------|
| M05 Logic | 5 mW | FSM + Registers + Estimator |
| M05 IO | 2 mW | Bus Interface + Control Signals |
| **Total** | **7 mW** | REQ-PWR-001 合规 |

### 5.5 Clock Domain Crossing

| Crossing | From | To | Method |
|----------|------|----|----|
| DVFS Request | CLK_AON (1 MHz) | CLK_SYS (500 MHz) | Handshake synchronizer |
| Activity Monitor | CLK_SYS (500 MHz) | CLK_AON (1 MHz) | Pulse synchronizer |
| Wakeup Signal | CLK_IO (50 MHz) | CLK_AON (1 MHz) | Level synchronizer |

### 5.6 Reset Strategy

| Reset | Source | Effect |
|-------|--------|--------|
| rst_por_n | Power-On | 全部寄存器复位，FSM 进入 RESET |
| rst_aon_n | External | 仅状态寄存器复位，配置保留 |
| Soft Reset | Register | PM_CTRL[0]=0 禁用，保持配置 |