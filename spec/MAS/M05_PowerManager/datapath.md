---
module: M05
type: datapath
status: complete
parent: MAS
generated: 2026-05-12T09:20:00Z
---

# M05 PowerManager — Datapath

## 模块框图

```mermaid
block-beta
    columns 3

    APB["APB Slave\n(寄存器接口)"] space FSM_BLOCK["FSM Controller\n(POWER_OFF/POR/IDLE\nACTIVE/SLEEP)"]

    space space space

    DVFS["DVFS Controller\n(LP/FS 切换)"] space SEQ["Power Sequencer\n(上电/下电时序)"]

    space space space

    CLK_GATE["Clock Gate\nController"] space ISO["Isolation\nController"]

    APB --> FSM_BLOCK
    FSM_BLOCK --> DVFS
    FSM_BLOCK --> SEQ
    DVFS --> CLK_GATE
    SEQ --> ISO
```

### 外部接口连接

```mermaid
graph LR
    subgraph PD_AON["PD_AON 域 (32KHz)"]
        PM["M05\nPowerManager"]
    end

    subgraph EXT["外部"]
        PMIC["PMIC"]
        INT["外部中断/定时器"]
    end

    subgraph PD_MAIN["PD_MAIN 域"]
        CORE["计算核心\n(M00-M04)"]
    end

    INT -->|wakeup_req| PM
    CORE -->|idle_req, dvfs_req| PM
    PM -->|pmic_en| PMIC
    PMIC -->|pmic_pg| PM
    PM -->|pd_main_en, clk_gate_en\nvdd_main_sel, freq_sel\niso_en| PD_MAIN
    PM -->|pwr_state, dvfs_ack| CORE
```

## 电源域控制逻辑

### PD_MAIN 控制信号生成

```
pd_main_en  = (state == IDLE) || (state == ACTIVE)
iso_en      = (state == POWER_OFF) || (state == SLEEP) || (state == POR && !pmic_pg)
clk_gate_en = (state == ACTIVE) && !dvfs_busy
```

### DVFS 电压/频率选择

```
vdd_main_sel = (dvfs_cur == LP) ? 2'b01 :   // 0.8V
               (dvfs_cur == FS) ? 2'b10 :   // 0.9V
               2'b00                         // off

freq_sel     = (dvfs_cur == LP) ? 2'b01 :   // 250MHz
               (dvfs_cur == FS) ? 2'b10 :   // 500MHz
               2'b00                         // off
```

## DVFS 切换时序

### 升频时序（LP → FS）

```
时间轴（CLK_AON 周期，32KHz ≈ 31.25μs/cycle）

t0: dvfs_req = FS，dvfs_busy 拉高
t1: vdd_main_sel → 0.9V（升压开始）
t1+V_SETTLE_CNT: 电压稳定，freq_sel → 500MHz
t1+V_SETTLE_CNT+F_SETTLE_CNT: 频率稳定
t_end: dvfs_ack = FS，dvfs_busy 拉低

典型总延迟 ≈ (16+8) × 31.25μs ≈ 750μs（可通过 DVFS_CFG 调整）
```

### 降频时序（FS → LP）

```
t0: dvfs_req = LP，dvfs_busy 拉高
t1: freq_sel → 250MHz（先降频）
t1+F_SETTLE_CNT: 频率稳定，vdd_main_sel → 0.8V（降压）
t1+F_SETTLE_CNT+V_SETTLE_CNT: 电压稳定
t_end: dvfs_ack = LP，dvfs_busy 拉低
```

## 关键路径

| 路径 | 起点 | 终点 | 约束 |
|------|------|------|------|
| 唤醒路径 | wakeup_req | clk_gate_en | 异步，需同步到 CLK_AON |
| DVFS 请求 | dvfs_req | dvfs_busy | 1 CLK_AON 周期内响应 |
| 电源状态输出 | FSM 寄存器 | pwr_state | 组合逻辑，无额外延迟 |
