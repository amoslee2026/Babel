---
module: M07
type: verification
status: complete
parent: TOP
module_type: io
generated: 2026-05-12T09:20:00Z
---

# M07 ResetManager — 验证规范

## 1. 功能覆盖点表

| 覆盖点 ID | 描述                                | 覆盖类型   | 目标覆盖率 |
|----------|-------------------------------------|------------|------------|
| COV_001  | FSM 四个状态均被访问                | 状态覆盖   | 100%       |
| COV_002  | 所有状态转移路径被触发              | 转移覆盖   | 100%       |
| COV_003  | POR 触发复位（por_n 低→高）         | 功能覆盖   | 100%       |
| COV_004  | WDT 超时触发复位（WDT_EN=1）        | 功能覆盖   | 100%       |
| COV_005  | WDT 超时但 WDT_EN=0（不触发）       | 功能覆盖   | 100%       |
| COV_006  | 软件复位 SCOPE=00/01/11 三种配置    | 参数覆盖   | 100%       |
| COV_007  | 复位释放序列：global→main→sys 顺序  | 时序覆盖   | 100%       |
| COV_008  | RESET_SYNC 中途被 POR 中断          | 异常覆盖   | 100%       |
| COV_009  | RST_STATUS 三个标志位各自置位       | 寄存器覆盖 | 100%       |
| COV_010  | WDT_LOCK=1 后 WDT_PERIOD 不可写     | 保护覆盖   | 100%       |
| COV_011  | APB 读 RST_STATUS 在复位期间        | 总线覆盖   | 100%       |
| COV_012  | 消抖期间 por_n 再次拉低（重新计数） | 毛刺覆盖   | 100%       |

---

## 2. 断言列表

| 断言 ID  | 类型  | 描述                                                        |
|---------|-------|-------------------------------------------------------------|
| AST_001 | SVA   | rst_global_n 释放前 rst_main_n 必须保持低                   |
| AST_002 | SVA   | rst_main_n 释放前 rst_sys_n 必须保持低                      |
| AST_003 | SVA   | por_n 拉低后 1 CLK_AON 内 rst_global_n 必须拉低             |
| AST_004 | SVA   | SW_RST 写 1 后最多 2 CLK_AON 内 sw_rst_req 有效             |
| AST_005 | SVA   | WDT_KICK 写 1 后 WDT 计数器清零                             |
| AST_006 | SVA   | WDT_LOCK=1 时写 WDT_PERIOD 无效（值不变）                   |
| AST_007 | SVA   | RUNNING 状态下 RST_ACTIVE=0                                 |
| AST_008 | SVA   | 任意复位源有效时 RST_ACTIVE=1                               |
| AST_009 | Cover | 消抖计数器从 0 计到 15 的完整路径                           |
| AST_010 | SVA   | scan_mode=1 时复位输出由 scan_rst_n 直接驱动                |

---

## 3. 仿真场景

### 场景 S1：上电复位（POR）

```
步骤：
1. 初始 por_n=0，所有复位输出=0，FSM=POR_ASSERT
2. 拉高 por_n，等待 20 CLK_AON
3. 验证 debounce_done 在第 16 周期置位
4. 验证 rst_global_n 在 debounce_done 后 2 CLK_AON 内释放
5. 验证 rst_main_n 在 rst_global_n 后 8 CLK_AON 释放
6. 验证 rst_sys_n 在 rst_main_n 后 4 CLK_AON 释放
7. 验证 FSM 进入 RUNNING，RST_STATUS[POR_FLAG]=1
检查点：释放顺序、延迟周期数、标志位
```

### 场景 S2：软件复位（SW Reset）

```
步骤：
1. 系统处于 RUNNING 状态
2. APB 写 RST_CTRL[SCOPE]=2'b11，RST_CTRL[SW_RST]=1
3. 验证 sw_rst_req 有效，FSM 跳转 RUNNING→RESET_SYNC
4. 验证三路复位输出拉低
5. 验证复位释放序列完成后 FSM 回到 RUNNING
6. 验证 RST_STATUS[SW_FLAG]=1，POR_FLAG/WDT_FLAG=0
7. 重复 SCOPE=2'b00（仅 rst_sys_n）和 SCOPE=2'b01（rst_main_n+rst_sys_n）
检查点：SCOPE 控制精度、标志位互斥
```

### 场景 S3：看门狗超时复位（WDT Timeout）

```
步骤：
1. APB 写 WDT_CFG[WDT_PERIOD]=16'h0010（16 周期超时）
2. APB 写 RST_CTRL[WDT_EN]=1
3. 等待 17 CLK_AON，不喂狗
4. 验证 wdt_rst_req 有效，FSM 跳转 RUNNING→RESET_SYNC
5. 验证复位序列完成，RST_STATUS[WDT_FLAG]=1
6. 重复：WDT_EN=0 时超时不触发复位
7. 测试喂狗（WDT_KICK=1）重置计数器，不触发复位
检查点：超时精度（±1 CLK_AON）、WDT_EN 门控、喂狗有效性
```

### 场景 S4：复位序列中断

```
步骤：
1. 触发软件复位，FSM 进入 RESET_SYNC
2. 在 rst_seq_cnt=5 时拉低 por_n
3. 验证 FSM 立即跳转到 POR_ASSERT
4. 验证所有复位输出保持低
5. 拉高 por_n，验证重新执行完整 POR 序列
检查点：中断响应延迟 ≤1 CLK_AON
```
