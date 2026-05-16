---
module: M06
type: verification
status: complete
parent: TOP
module_type: io
generated: 2026-05-12T09:20:00Z
---

# M06_ClockManager Verification

## 功能覆盖点

| ID | 覆盖点 | 描述 | 优先级 |
|----|--------|------|--------|
| COV_01 | PLL 启动 | PLL_EN 从 0→1，PLL 正常启动 | P0 |
| COV_02 | PLL 锁定 | PLL 在 100μs 内锁定 | P0 |
| COV_03 | 时钟稳定 | 锁定后 10μs 时钟稳定 | P0 |
| COV_04 | 时钟门控 | clk_gate_en 控制时钟输出 | P1 |
| COV_05 | 配置读写 | APB 读写所有寄存器 | P1 |
| COV_06 | 复位恢复 | rst_n 复位后正常恢复 | P0 |
| COV_07 | 频率精度 | CLK_SYS 频率误差 <1% | P0 |
| COV_08 | 占空比 | 占空比 50±2% | P1 |
| COV_09 | 抖动 | 抖动 <50ps | P2 |
| COV_10 | 状态转移 | 覆盖所有 FSM 状态转移 | P0 |

## 断言列表

### 时钟域断言
```systemverilog
// A01: PLL 锁定前不输出时钟
property pll_lock_before_output;
  @(posedge clk_ref) !pll_lock |-> !clk_out_en;
endproperty
assert_pll_lock: assert property(pll_lock_before_output);

// A02: 时钟频率检查
property clk_freq_check;
  @(posedge clk_ref) $rose(clk_sys) |-> ##[15624:15626] $rose(clk_sys);
endproperty
assert_freq: assert property(clk_freq_check);

// A03: 门控响应时间
property gate_response;
  @(posedge clk_ref) $rose(clk_gate_en) |-> ##[0:5] clk_sys;
endproperty
assert_gate: assert property(gate_response);
```

### 配置断言
```systemverilog
// A04: 寄存器写保护
property reg_write_protect;
  @(posedge clk_ref) cfg_wr && (cfg_addr == 8'h08) |-> $stable(clk_status);
endproperty
assert_ro_reg: assert property(reg_write_protect);

// A05: PLL 配置范围
property pll_cfg_range;
  @(posedge clk_ref) cfg_wr && (cfg_addr == 8'h04) |-> 
    (cfg_wdata[15:0] >= 1000) && (cfg_wdata[15:0] <= 20000);
endproperty
assert_pll_range: assert property(pll_cfg_range);
```

### FSM 断言
```systemverilog
// A06: 状态转移合法性
property valid_state_transition;
  @(posedge clk_ref) (state == RESET) |-> ##1 (state inside {RESET, PLL_LOCK});
endproperty
assert_fsm: assert property(valid_state_transition);
```

## 仿真场景

### 场景 1: PLL 锁定测试
```
1. 复位系统 (rst_n=0, 10 cycles)
2. 释放复位 (rst_n=1)
3. 使能 PLL (PLL_EN=1)
4. 等待 100μs
5. 检查 pll_lock=1
6. 等待 10μs
7. 检查 clk_sys 输出
8. 测量频率 (应为 500MHz±1%)
```

### 场景 2: 时钟切换测试
```
1. 系统运行在 RUNNING 状态
2. 禁用时钟门控 (clk_gate_en=0)
3. 检查 clk_sys 停止输出
4. 使能时钟门控 (clk_gate_en=1)
5. 检查 clk_sys 恢复输出
6. 验证切换延迟 <10ns
```

### 场景 3: 配置寄存器测试
```
1. 写入 CLK_CTRL (0x00 = 0x03)
2. 读回验证 (应为 0x03)
3. 写入 PLL_CFG (0x04 = 0x103D09)
4. 读回验证 (应为 0x103D09)
5. 读取 CLK_STATUS (0x08)
6. 验证只读位不可写
```

### 场景 4: 复位测试
```
1. 系统运行在 RUNNING 状态
2. 施加复位 (rst_n=0)
3. 检查 FSM 返回 RESET 状态
4. 检查 clk_sys 停止输出
5. 释放复位 (rst_n=1)
6. 验证系统重新启动
```

## 覆盖率目标

| 类型 | 目标 | 当前 |
|------|------|------|
| 代码覆盖率 | 100% | - |
| 功能覆盖率 | 100% | - |
| 断言覆盖率 | 100% | - |
| 状态覆盖率 | 100% | - |
| 转移覆盖率 | 100% | - |

## 测试环境

- 仿真器：VCS / Verilator
- 语言：SystemVerilog + UVM
- 波形：VCD / FSDB
- 覆盖率：URG / Verdi
