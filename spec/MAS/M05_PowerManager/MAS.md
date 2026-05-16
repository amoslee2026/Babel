---
module: M05
type: MAS
status: complete
parent: TOP
module_type: io
generated: 2026-05-12T09:20:00Z
---

# M05 PowerManager — MAS

## 模块概述

PowerManager 负责 TinyStories NPU 的全芯片电源管理，运行于 PD_AON 电源域（始终上电），时钟源为 CLK_AON 32KHz。管理 PD_MAIN（计算核心）和 PD_AON（常开域）两个电源域，支持 DVFS 动态电压频率调节，空闲功耗 ≤ 0.1W，峰值 TDP ≤ 2W，工艺节点三星 SF4 4nm。

## 接口信号表

### 时钟与复位

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| clk_aon | input | 1 | 32KHz 常开时钟 |
| rst_aon_n | input | 1 | AON 域异步复位，低有效 |

### 电源控制输出

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| pd_main_en | output | 1 | PD_MAIN 电源域使能，高有效 |
| clk_gate_en | output | 1 | 全局时钟门控使能，高有效 |
| vdd_main_sel | output | 2 | 主域电压档位选择（00=off, 01=0.8V, 10=0.9V） |
| freq_sel | output | 2 | 频率档位选择（00=off, 01=250MHz, 10=500MHz） |

### DVFS 接口

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| dvfs_req[1:0] | input | 2 | DVFS 请求（00=idle, 01=LP, 10=FS） |
| dvfs_ack[1:0] | output | 2 | DVFS 应答，与 req 对应 |
| dvfs_busy | output | 1 | DVFS 切换进行中 |

### 电源状态

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| pwr_state[1:0] | output | 2 | 当前电源状态（见 FSM.md） |
| idle_req | input | 1 | 系统空闲请求（来自 M01） |
| wakeup_req | input | 1 | 唤醒请求（来自外部中断/定时器） |

### PMU 外部接口

| 信号 | 方向 | 宽度 | 描述 |
|------|------|------|------|
| pmic_en | output | 1 | PMIC 使能信号 |
| pmic_pg | input | 1 | PMIC Power Good 指示 |
| iso_en | output | 1 | 电源域隔离使能，高有效 |

## DVFS 工作点表

| 工作点 | dvfs_req | 频率 | 电压 | 典型功耗 | 场景 |
|--------|----------|------|------|----------|------|
| OFF | 2'b00 | — | — | 0W | 断电 |
| LP（低功耗） | 2'b01 | 250MHz | 0.8V | ≤0.5W | 轻载/后台 |
| FS（全速） | 2'b10 | 500MHz | 0.9V | ≤2W | 推理计算 |

切换延迟：LP→FS ≤ 10μs，FS→LP ≤ 5μs（含电压稳定时间）。

## 电源序列

### 上电序列（POWER_OFF → ACTIVE）

1. `pmic_en` 拉高，等待 `pmic_pg` 有效（≤ 1ms）
2. 释放 `iso_en`（拉低）
3. 拉高 `pd_main_en`
4. 等待 PD_MAIN 稳定（≥ 10 CLK_AON 周期）
5. 拉高 `clk_gate_en`，分发工作时钟
6. 置 `pwr_state = ACTIVE`

### 下电序列（ACTIVE → POWER_OFF）

1. 拉低 `clk_gate_en`，停止工作时钟
2. 拉高 `iso_en`，隔离 PD_MAIN 输出
3. 拉低 `pd_main_en`
4. 拉低 `pmic_en`
5. 置 `pwr_state = POWER_OFF`

### 睡眠序列（ACTIVE → SLEEP）

1. 拉低 `clk_gate_en`
2. 拉高 `iso_en`
3. 保持 `pd_main_en` 低（PD_MAIN 断电，AON 保持）
4. 置 `pwr_state = SLEEP`

## 寄存器映射

基地址：由 TOP 地址映射分配（APB 接口，32-bit 对齐）。

### PWR_CTRL（offset 0x00）

| 位域 | 名称 | 访问 | 复位值 | 描述 |
|------|------|------|--------|------|
| [1:0] | PWR_REQ | RW | 2'b00 | 软件电源请求（同 dvfs_req 编码） |
| [2] | SLEEP_EN | RW | 1'b0 | 允许进入 SLEEP 状态 |
| [3] | WAKEUP_SRC_SEL | RW | 1'b0 | 唤醒源选择（0=外部中断, 1=定时器） |
| [31:4] | — | RO | — | 保留 |

### DVFS_CFG（offset 0x04）

| 位域 | 名称 | 访问 | 复位值 | 描述 |
|------|------|------|--------|------|
| [7:0] | V_SETTLE_CNT | RW | 8'h10 | 电压稳定等待计数（CLK_AON 周期） |
| [15:8] | F_SETTLE_CNT | RW | 8'h08 | 频率切换等待计数（CLK_AON 周期） |
| [17:16] | DVFS_MODE | RW | 2'b00 | 00=手动, 01=自动（硬件 DVFS） |
| [31:18] | — | RO | — | 保留 |

### PWR_STATUS（offset 0x08）

| 位域 | 名称 | 访问 | 复位值 | 描述 |
|------|------|------|--------|------|
| [1:0] | CUR_STATE | RO | 2'b00 | 当前 FSM 状态 |
| [3:2] | CUR_DVFS | RO | 2'b00 | 当前 DVFS 工作点 |
| [4] | DVFS_BUSY | RO | 1'b0 | DVFS 切换进行中 |
| [5] | PMIC_PG | RO | 1'b0 | PMIC Power Good 状态 |
| [31:6] | — | RO | — | 保留 |
