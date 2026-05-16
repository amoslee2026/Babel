---
module: M07
type: DFT
status: complete
parent: TOP
module_type: io
generated: 2026-05-12T09:20:00Z
---

# M07 ResetManager — DFT 规范

## 1. 扫描链配置

ResetManager 归属 PD_AON 电源域，始终上电，独立扫描链。

| 参数           | 值                          |
|---------------|-----------------------------|
| 扫描链数量     | 1 条（AON_SCAN_CHAIN_0）    |
| 扫描触发器数量 | ~32（含 FSM、计数器、寄存器）|
| 扫描时钟       | scan_clk（外部提供，≤10 MHz）|
| 扫描复位       | scan_rst_n（低有效）         |
| 扫描使能       | scan_mode（高有效）          |
| 扫描输入       | scan_in                     |
| 扫描输出       | scan_out                    |

扫描链插入规则：
- 所有 D 触发器替换为 SDFF（扫描 D 触发器）
- 2-FF 同步器单元（SYNC2FF）**不插入**扫描链，保持功能单元完整性
- WDT 计数器触发器插入扫描链，但 WDT_LOCK 寄存器需特殊处理（见第 3 节）

---

## 2. 复位测试模式

### 2.1 scan_mode 对复位输出的影响

```
scan_mode = 1 时：
  rst_global_n = scan_rst_n
  rst_main_n   = scan_rst_n
  rst_sys_n    = scan_rst_n

scan_mode = 0 时：
  正常功能模式，复位输出由 FSM 控制
```

实现方式：在复位输出驱动处插入 2:1 MUX，sel=scan_mode。

### 2.2 测试复位序列

| 测试步骤 | 操作                              | 预期结果                    |
|---------|-----------------------------------|-----------------------------|
| T1      | scan_mode=1, scan_rst_n=0         | 三路复位输出全部拉低        |
| T2      | scan_mode=1, scan_rst_n=1         | 三路复位输出全部拉高        |
| T3      | 移入扫描向量，scan_rst_n=0        | 触发器加载测试图案          |
| T4      | scan_rst_n=1，捕获一个 scan_clk   | 捕获功能响应                |
| T5      | 移出扫描链，比对期望值            | 验证逻辑正确性              |

### 2.3 ATPG 约束

```
// 约束文件片段（Synopsys TetraMAX 格式）
constraint {
  // 扫描模式下固定 por_n=1（避免异步复位干扰）
  force_pi por_n 1;
  // WDT 请求固定为 0（避免测试中触发复位）
  force_pi wdt_rst_req 0;
  // APB 总线固定为非访问状态
  force_pi apb_psel 0;
}
```

---

## 3. JTAG 接口

ResetManager 通过 TAP（Test Access Port）支持边界扫描，符合 IEEE 1149.1。

| JTAG 信号 | 连接                        | 描述                        |
|----------|-----------------------------|-----------------------------|
| TCK      | 外部 JTAG 时钟              | 边界扫描时钟                |
| TMS      | TAP 控制器                  | 状态机控制                  |
| TDI      | 扫描链输入                  | 测试数据输入                |
| TDO      | 扫描链输出                  | 测试数据输出                |
| TRST_N   | TAP 异步复位                | 低有效，复位 TAP 控制器     |

### JTAG 复位控制寄存器（DR 寄存器，长度 4 bit）

| 位  | 名称          | 描述                                  |
|----|---------------|---------------------------------------|
| 0  | JTAG_RST_GLOB | 写 1 通过 JTAG 触发 rst_global_n      |
| 1  | JTAG_RST_MAIN | 写 1 通过 JTAG 触发 rst_main_n        |
| 2  | JTAG_RST_SYS  | 写 1 通过 JTAG 触发 rst_sys_n         |
| 3  | JTAG_BYPASS   | 写 1 旁路 ResetManager，直通 scan_rst_n|

JTAG 复位优先级低于 POR，高于软件复位。仅在 scan_mode=1 时 JTAG 复位控制有效。

### WDT_LOCK 处理

WDT_LOCK=1 时 WDT_PERIOD 寄存器写保护。DFT 模式下：
- scan_mode=1 时 WDT_LOCK 强制为 0，允许 ATPG 自由控制 WDT_PERIOD
- 通过 JTAG BYPASS 位可绕过 WDT 逻辑，防止测试中意外触发复位
