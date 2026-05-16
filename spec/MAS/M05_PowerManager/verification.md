---
module: M05
type: verification
status: complete
parent: MAS
generated: 2026-05-12T09:20:00Z
---

# M05 PowerManager — Verification

## 功能覆盖点

### 电源状态覆盖

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_STATE_ALL | 所有 FSM 状态均被访问 | 100% |
| COV_TRANS_ALL | 所有合法状态转移均被触发 | 100% |
| COV_POR_SUCCESS | POR 正常完成（pmic_pg 有效） | 100% |
| COV_POR_TIMEOUT | POR 超时回退 POWER_OFF | 100% |
| COV_SLEEP_WAKE | SLEEP → POR 唤醒路径 | 100% |

### DVFS 覆盖

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_DVFS_LP2FS | LP → FS 升频切换 | 100% |
| COV_DVFS_FS2LP | FS → LP 降频切换 | 100% |
| COV_DVFS_BUSY | dvfs_busy 在切换期间保持高电平 | 100% |
| COV_DVFS_ACK | dvfs_ack 与 dvfs_req 最终一致 | 100% |
| COV_DVFS_SETTLE | V_SETTLE_CNT 和 F_SETTLE_CNT 边界值 | 100% |

### 电源门控覆盖

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_ISO_ACTIVE | iso_en 在 POWER_OFF/SLEEP 时有效 | 100% |
| COV_CLK_GATE | clk_gate_en 在非 ACTIVE 时关闭 | 100% |
| COV_PD_MAIN_EN | pd_main_en 仅在 IDLE/ACTIVE 有效 | 100% |

### 空闲检测覆盖

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_IDLE_TIMEOUT | 空闲超时触发 ACTIVE → IDLE | 100% |
| COV_IDLE_CANCEL | 空闲期间收到 dvfs_req 取消空闲 | 100% |

## 断言（SVA）

```systemverilog
// 断言1：iso_en 在 PD_MAIN 上电前必须有效
property iso_before_power;
    @(posedge clk_aon)
    $rose(pd_main_en) |-> !iso_en;
endproperty
assert property (iso_before_power);

// 断言2：DVFS 切换期间 clk_gate_en 必须为低
property clk_off_during_dvfs;
    @(posedge clk_aon)
    dvfs_busy |-> !clk_gate_en;
endproperty
assert property (clk_off_during_dvfs);

// 断言3：dvfs_ack 最终必须与 dvfs_req 一致
property dvfs_ack_match;
    @(posedge clk_aon)
    $fell(dvfs_busy) |-> (dvfs_ack == $past(dvfs_req, 1));
endproperty
assert property (dvfs_ack_match);

// 断言4：pwr_state 不得出现非法编码（IDLE/SLEEP 区分由内部状态保证）
property valid_pwr_state;
    @(posedge clk_aon)
    pwr_state inside {2'b00, 2'b01, 2'b10, 2'b11};
endproperty
assert property (valid_pwr_state);

// 断言5：SLEEP 状态下 pd_main_en 必须为低
property sleep_pd_off;
    @(posedge clk_aon)
    (pwr_state == 2'b10 && sleep_active) |-> !pd_main_en;
endproperty
assert property (sleep_pd_off);
```

## 仿真场景

| 场景编号 | 场景名 | 步骤摘要 | 检查点 |
|----------|--------|----------|--------|
| SIM_01 | 正常上电 | 复位释放 → POR → IDLE | pmic_pg 响应，iso_en 时序正确 |
| SIM_02 | FS 工作 | IDLE → ACTIVE(FS) → 计算 → IDLE | dvfs_ack=FS，功耗 ≤ 2W |
| SIM_03 | LP 工作 | ACTIVE(FS) → ACTIVE(LP) | 先降频后降压，dvfs_busy 时序 |
| SIM_04 | 深度睡眠 | ACTIVE → SLEEP → 唤醒 → POR | pd_main_en 断电，唤醒延迟 ≤ 200μs |
| SIM_05 | POR 超时 | pmic_pg 不响应 | 超时后回到 POWER_OFF |
| SIM_06 | 连续 DVFS | LP↔FS 切换 10 次 | 每次 dvfs_ack 正确，无毛刺 |
| SIM_07 | 复位恢复 | ACTIVE 中拉低 rst_aon_n | 立即回到 POWER_OFF，信号安全 |
| SIM_08 | 寄存器访问 | APB 读写 PWR_CTRL/DVFS_CFG | 读回值与写入值一致 |

## 功耗验证

| 场景 | 预期功耗 | 测量方法 |
|------|----------|----------|
| SLEEP 状态 | ≤ 0.1W | 仿真电流积分 |
| ACTIVE LP | ≤ 0.5W | 仿真电流积分 |
| ACTIVE FS 峰值 | ≤ 2W | 仿真电流积分 |
